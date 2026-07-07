import 'pizza_model.dart';

class CartItem {
  final Pizza pizza;
  final String? selectedSize;
  final List<String> selectedAddons;
  int quantity;

  CartItem({
    required this.pizza,
    this.selectedSize,
    this.selectedAddons = const [],
    this.quantity = 1,
  });

  double get unitPrice {
    double base = pizza.discountedPrice;
    if (selectedSize != null) {
      base = pizza.getPriceForSize(selectedSize!);
    }
    
    double addonsTotal = 0;
    final size = selectedSize?.toLowerCase() ?? 'small';
    final isBobu = pizza.category.toLowerCase().contains('bobu');

    for (var addon in selectedAddons) {
      final a = addon.toLowerCase();
      
      if (isBobu) {
        // BOBU Pizza Category Pricing
        if (a.contains('cheese')) {
          if (size == 'small') addonsTotal += 39;
          else if (size == 'medium') addonsTotal += 69;
          else addonsTotal += 99;
        } else if (a.contains('veg topping')) {
          if (size == 'small') addonsTotal += 19;
          else if (size == 'medium') addonsTotal += 29;
          else addonsTotal += 39;
        } else if (a.contains('paneer') || a.contains('olive')) {
          if (size == 'small') addonsTotal += 29;
          else if (size == 'medium') addonsTotal += 49;
          else addonsTotal += 69;
        } else if (a.contains('jalapeno') || a.contains('paprika')) {
          if (size == 'small') addonsTotal += 29;
          else if (size == 'medium') addonsTotal += 49;
          else addonsTotal += 69;
        }
      } else {
        // Default / Pizza Mania Category Pricing
        if (a.contains('cheese')) {
          addonsTotal += (size == 'small') ? 20 : 30;
        } else if (a.contains('paneer')) {
          addonsTotal += (size == 'small') ? 30 : 50;
        } else if (a.contains('veggie') || a.contains('veg topping')) {
          addonsTotal += (size == 'small') ? 20 : 30;
        }
      }
    }
    
    return base + addonsTotal;
  }

  double get totalPrice => unitPrice * quantity;
}
