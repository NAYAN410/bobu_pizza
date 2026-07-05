import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class LocationService {
  static Future<String> getCurrentAddress() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return 'Location services disabled';

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return 'Permission denied';
    }
    
    if (permission == LocationPermission.deniedForever) return 'Permission denied forever';

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
      );

      // --- LAYER 1: OpenStreetMap (Detailed) ---
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1'
        );

        final response = await http.get(url, headers: {
          'User-Agent': 'BobuPizzaApp/1.0',
          'Accept-Language': 'en'
        }).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final address = data['address'] as Map<String, dynamic>;

          String house = address['house_number'] ?? address['building'] ?? '';
          String road = address['road'] ?? '';
          String suburb = address['suburb'] ?? address['neighbourhood'] ?? '';
          String village = address['village'] ?? address['city_district'] ?? '';
          String town = address['town'] ?? address['city'] ?? address['county'] ?? '';

          List<String> parts = [];
          if (house.isNotEmpty) parts.add(house);
          if (road.isNotEmpty) parts.add(road);
          if (suburb.isNotEmpty) parts.add(suburb);
          if (village.isNotEmpty && village != suburb) parts.add(village);
          if (town.isNotEmpty && town != village) parts.add(town);

          if (parts.isNotEmpty) return parts.join(', ');
          
          // Fallback to display_name if parts are empty but data exists
          if (data['display_name'] != null) {
            List<String> displayParts = data['display_name'].toString().split(',');
            return displayParts.take(3).join(',').trim();
          }
        }
      } catch (e) {
        debugPrint('OSM Failed, falling back to Native: $e');
      }

      // --- LAYER 2: Native Geocoding (Fallback) ---
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark p = placemarks[0];
        String subLocality = p.subLocality ?? '';
        String locality = p.locality ?? '';
        String name = p.name ?? '';

        List<String> parts = [];
        if (name.isNotEmpty && name != subLocality && name != locality) parts.add(name);
        if (subLocality.isNotEmpty) parts.add(subLocality);
        if (locality.isNotEmpty) parts.add(locality);

        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (e) {
      debugPrint('Critical Location Error: $e');
    }

    return 'Location not found';
  }
}
