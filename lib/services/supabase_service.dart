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

  static Future<List<Map<String, dynamic>>> searchPizzas(String query) async {
    await checkConnectivity();
    final data = await client
        .from('pizzas')
        .select()
        .ilike('name', '%$query%')
        .limit(5);
    return List<Map<String, dynamic>>.from(data);
  }

  // Order Methods
  static Future<Map<String, dynamic>> placeOrder({
    required String address,
    required String mobile,
    required String paymentMode,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    String? couponId,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    String? paymentStatus,
  }) async {
    await checkConnectivity();
    final user = client.auth.currentUser;
    if (user == null) throw 'User not logged in';

    // Generate Custom Order ID: BB20250810 + Random String
    final now = DateTime.now();
    final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    final randomStr = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    final customOrderId = "BB$dateStr$randomStr";

    // Generate 6-digit random PIN
    final deliveryPin = (100000 + (DateTime.now().microsecondsSinceEpoch % 900000)).toString();

    // 1. Insert order
    await client.from('orders').insert({
      'id': customOrderId,
      'user_id': user.id,
      'address': address,
      'mobile': mobile,
      'payment_mode': paymentMode,
      'payment_status': paymentStatus ?? (paymentMode == 'COD' ? 'pending' : 'completed'),
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'total_amount': totalAmount,
      'status': 'pending',
      'coupon_id': couponId,
      'delivery_pin': deliveryPin,
    });

    // 2. Insert order items
    final orderItems = items.map((item) => {
      'order_id': customOrderId,
      'pizza_id': item['pizza_id'],
      'quantity': item['quantity'],
      'price': item['price'],
    }).toList();

    await client.from('order_items').insert(orderItems);

    // 3. Track coupon usage
    if (couponId != null) {
      await client.from('user_coupons').insert({
        'user_id': user.id,
        'coupon_id': couponId,
      });
    }

    return {
      'id': customOrderId,
      'delivery_pin': deliveryPin,
      'total': totalAmount,
    };
  }

  static Future<List<Map<String, dynamic>>> getUserOrders() async {
    await checkConnectivity();
    final user = client.auth.currentUser;
    if (user == null) return [];

    final data = await client
        .from('orders')
        .select('*, order_items(*, pizzas(*))')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(data);
  }

  // Coupon Methods
  static Future<Map<String, dynamic>?> validateCoupon(String code) async {
    await checkConnectivity();
    final user = client.auth.currentUser;
    if (user == null) throw 'User not logged in';

    // 1. Fetch coupon
    final coupon = await client
        .from('coupons')
        .select()
        .eq('code', code.toUpperCase())
        .eq('is_active', true)
        .maybeSingle();

    if (coupon == null) return null;

    // 2. Check expiry
    if (coupon['expiry_date'] != null) {
      final expiry = DateTime.parse(coupon['expiry_date']);
      if (DateTime.now().isAfter(expiry)) return null;
    }

    // 3. Check if user already used it
    final usage = await client
        .from('user_coupons')
        .select()
        .eq('user_id', user.id)
        .eq('coupon_id', coupon['id'])
        .maybeSingle();

    if (usage != null) throw 'You have already used this coupon';

    return coupon;
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
          'is_admin': false,
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

  static Future<void> updateFcmToken(String token) async {
    final user = client.auth.currentUser;
    if (user != null) {
      try {
        await client.from('profiles').update({'fcm_token': token}).eq('id', user.id);
      } catch (e) {
        debugPrint('Error in updateFcmToken: $e');
      }
    }
  }
}
