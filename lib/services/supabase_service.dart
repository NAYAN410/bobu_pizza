import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../main.dart';

class SupabaseService {
  static final client = Supabase.instance.client;

  static Future<void> checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw const SocketException('No Internet');
      }
    } catch (_) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/error', (route) => false);
      throw 'Network error';
    }
  }

  // Auth Methods
  static Future<User?> getCurrentUser() async {
    try {
      final response = await client.auth.getUser();
      return response.user;
    } catch (e) {
      if (e is SocketException || e.toString().contains('SocketException')) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/error', (route) => false);
      }
      return null;
    }
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    await checkConnectivity();
    return client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<AuthResponse> signUp(String email, String password, String fullName) async {
    await checkConnectivity();
    return client.auth.signUp(
      email: email, 
      password: password, 
      data: {'full_name': fullName},
    );
  }

  static Future<void> signOut() {
    return client.auth.signOut();
  }

  // Database Methods
  static Future<List<Map<String, dynamic>>> getPizzas({String? category, int from = 0, int to = 3}) async {
    await checkConnectivity();
    var query = client.from('pizzas').select();
    
    if (category != null && category.toLowerCase() != 'all') {
      query = query.eq('category', category);
    }
    
    final data = await query.order('id', ascending: true).range(from, to);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<Map<String, dynamic>>> getPopularPizzas() async {
    await checkConnectivity();
    final data = await client.from('pizzas').select().eq('is_popular', true).order('id', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    await checkConnectivity();
    final data = await client.from('categories').select().order('id', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<Map<String, dynamic>>> getBanners() async {
    await checkConnectivity();
    final data = await client.from('banners').select().order('id', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  // Order Methods
  static Future<void> placeOrder({
    required String address,
    required String mobile,
    required String paymentMode,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    await checkConnectivity();
    final user = client.auth.currentUser;
    if (user == null) throw 'User not logged in';

    // 1. Insert order
    final orderResponse = await client.from('orders').insert({
      'user_id': user.id,
      'address': address,
      'mobile': mobile,
      'payment_mode': paymentMode,
      'total_amount': totalAmount,
      'status': 'pending',
    }).select().single();

    final orderId = orderResponse['id'];

    // 2. Insert order items
    final orderItems = items.map((item) => {
      'order_id': orderId,
      'pizza_id': item['pizza_id'],
      'quantity': item['quantity'],
      'price': item['price'],
    }).toList();

    await client.from('order_items').insert(orderItems);
  }

  // Address Methods
  static Future<List<Map<String, dynamic>>> getAddresses() async {
    await checkConnectivity();
    final user = client.auth.currentUser;
    if (user == null) return [];
    
    final data = await client
        .from('addresses')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> addAddress(Map<String, dynamic> addressData) async {
    await checkConnectivity();
    final user = client.auth.currentUser;
    if (user == null) throw 'User not logged in';
    
    await client.from('addresses').insert({
      ...addressData,
      'user_id': user.id,
    });
  }

  static Future<void> deleteAddress(String addressId) async {
    await checkConnectivity();
    await client.from('addresses').delete().eq('id', addressId);
  }

  // Profile Methods
  static Future<Map<String, dynamic>?> getProfile() async {
    await checkConnectivity();
    final user = client.auth.currentUser;
    if (user == null) return null;

    try {
      final data = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      
      if (data == null) {
        // Fallback: Create profile if trigger didn't run
        final newProfile = {
          'id': user.id,
          'full_name': user.userMetadata?['full_name'] ?? user.email?.split('@').first ?? 'Guest',
          'phone': '',
          'updated_at': DateTime.now().toIso8601String(),
        };
        await client.from('profiles').insert(newProfile);
        return newProfile;
      }
      return data;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      // If error is due to missing record, try one last time to create it
      return null;
    }
  }

  static Future<void> updateProfile(Map<String, dynamic> profileData) async {
    await checkConnectivity();
    final user = client.auth.currentUser;
    if (user == null) throw 'User not logged in';

    await client.from('profiles').upsert({
      'id': user.id,
      ...profileData,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
