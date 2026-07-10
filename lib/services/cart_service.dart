import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cart_item_model.dart';
import '../models/pizza_model.dart';
import 'supabase_service.dart';

class CartService {
  static final client = Supabase.instance.client;
  static final ValueNotifier<List<CartItem>> cartItemsNotifier = ValueNotifier<List<CartItem>>([]);

  static List<CartItem> get items => cartItemsNotifier.value;

  static Future<void> fetchCartFromDb() async {
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      await SupabaseService.checkConnectivity();
      final data = await client
          .from('cart_items')
          .select('*, pizzas(*)')
          .eq('user_id', user.id);

      final List<CartItem> loadedItems = (data as List).map((item) {
        List<String> addons = [];
        if (item['selected_addons'] != null) {
          addons = List<String>.from(item['selected_addons']);
        }

        return CartItem(
          id: item['id'].toString(), // Row ID fetch kar rahe hain
          pizza: Pizza.fromJson(item['pizzas']),
          quantity: item['quantity'],
          selectedSize: item['selected_size'],
          selectedAddons: addons,
        );
      }).toList();

      cartItemsNotifier.value = loadedItems;
    } catch (e) {
      debugPrint('Error fetching cart: $e');
    }
  }

  static Future<void> addToCart(Pizza pizza, {int quantity = 1, String? size, List<String> addons = const []}) async {
    final user = client.auth.currentUser;
    if (user == null) return;

    final currentItems = List<CartItem>.from(cartItemsNotifier.value);
    
    final existingIndex = currentItems.indexWhere((item) {
      bool samePizza = item.pizza.id == pizza.id;
      bool sameSize = item.selectedSize == size;
      bool sameAddons = setEquals(item.selectedAddons.toSet(), addons.toSet());
      return samePizza && sameSize && sameAddons;
    });

    try {
      await SupabaseService.checkConnectivity();
      if (existingIndex != -1) {
        final item = currentItems[existingIndex];
        final newQty = item.quantity + quantity;
        
        await client
            .from('cart_items')
            .update({'quantity': newQty})
            .eq('id', item.id!); // ID se update
            
        currentItems[existingIndex].quantity = newQty;
      } else {
        // Naya item insert karke uska ID le rahe hain
        final response = await client.from('cart_items').insert({
          'user_id': user.id,
          'pizza_id': pizza.id,
          'quantity': quantity,
          'selected_size': size,
          'selected_addons': addons,
        }).select().single();

        currentItems.add(CartItem(
          id: response['id'].toString(),
          pizza: pizza, 
          quantity: quantity, 
          selectedSize: size, 
          selectedAddons: addons
        ));
      }
      cartItemsNotifier.value = currentItems;
    } catch (e) {
      debugPrint('Error adding to cart: $e');
    }
  }

  static Future<void> updateQuantity(int pizzaId, int delta, {String? size, List<String> addons = const []}) async {
    final user = client.auth.currentUser;
    if (user == null) return;

    final currentItems = List<CartItem>.from(cartItemsNotifier.value);
    final index = currentItems.indexWhere((item) {
      bool samePizza = item.pizza.id == pizzaId;
      bool sameSize = item.selectedSize == size;
      bool sameAddons = setEquals(item.selectedAddons.toSet(), addons.toSet());
      return samePizza && sameSize && sameAddons;
    });

    if (index != -1) {
      final item = currentItems[index];
      final newQty = item.quantity + delta;
      
      try {
        await SupabaseService.checkConnectivity();
        if (newQty <= 0) {
          // Exact ID se delete kar rahe hain, koi error nahi aayega
          await client.from('cart_items').delete().eq('id', item.id!);
          currentItems.removeAt(index);
        } else {
          await client.from('cart_items')
              .update({'quantity': newQty})
              .eq('id', item.id!); // ID se update
          currentItems[index].quantity = newQty;
        }
        cartItemsNotifier.value = currentItems;
      } catch (e) {
        debugPrint('Error updating quantity: $e');
      }
    }
  }

  static double get subtotal {
    return cartItemsNotifier.value.fold(0, (sum, item) => sum + item.totalPrice);
  }

  static void clearLocalCart() {
    cartItemsNotifier.value = [];
  }

  static Future<void> clearCart() async {
    final user = client.auth.currentUser;
    if (user != null) {
      try {
        await SupabaseService.checkConnectivity();
        await client.from('cart_items').delete().eq('user_id', user.id);
      } catch (e) {
        debugPrint('Error clearing cart: $e');
      }
    }
    cartItemsNotifier.value = [];
  }
}
