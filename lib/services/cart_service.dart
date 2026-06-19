import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cart_item_model.dart';
import '../models/pizza_model.dart';
import 'supabase_service.dart';

class CartService {
  static final client = Supabase.instance.client;
  static final ValueNotifier<List<CartItem>> cartItemsNotifier = ValueNotifier<List<CartItem>>([]);

  static List<CartItem> get items => cartItemsNotifier.value;

  // Sync with Supabase on Login/App Start
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
        return CartItem(
          pizza: Pizza.fromJson(item['pizzas']),
          quantity: item['quantity'],
        );
      }).toList();

      cartItemsNotifier.value = loadedItems;
    } catch (e) {
      debugPrint('Error fetching cart: $e');
    }
  }

  static Future<void> addToCart(Pizza pizza, {int quantity = 1}) async {
    final user = client.auth.currentUser;
    if (user == null) return;

    final currentItems = List<CartItem>.from(cartItemsNotifier.value);
    final existingIndex = currentItems.indexWhere((item) => item.pizza.id == pizza.id);

    try {
      await SupabaseService.checkConnectivity();
      if (existingIndex != -1) {
        currentItems[existingIndex].quantity += quantity;
        await client
            .from('cart_items')
            .update({'quantity': currentItems[existingIndex].quantity})
            .eq('user_id', user.id)
            .eq('pizza_id', pizza.id);
      } else {
        currentItems.add(CartItem(pizza: pizza, quantity: quantity));
        await client.from('cart_items').insert({
          'user_id': user.id,
          'pizza_id': pizza.id,
          'quantity': quantity,
        });
      }
      cartItemsNotifier.value = currentItems;
    } catch (e) {
      debugPrint('Error adding to cart: $e');
    }
  }

  static Future<void> updateQuantity(int pizzaId, int delta) async {
    final user = client.auth.currentUser;
    if (user == null) return;

    final currentItems = List<CartItem>.from(cartItemsNotifier.value);
    final index = currentItems.indexWhere((item) => item.pizza.id == pizzaId);

    if (index != -1) {
      final newQty = currentItems[index].quantity + delta;
      
      try {
        await SupabaseService.checkConnectivity();
        if (newQty <= 0) {
          currentItems.removeAt(index);
          await client.from('cart_items').delete().eq('user_id', user.id).eq('pizza_id', pizzaId);
        } else {
          currentItems[index].quantity = newQty;
          await client.from('cart_items').update({'quantity': newQty}).eq('user_id', user.id).eq('pizza_id', pizzaId);
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
