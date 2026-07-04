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
    
    // Add-on pricing based on size
    double addonsTotal = 0;
    final isSmall = selectedSize?.toLowerCase() == 'small';
    
    for (var addon in selectedAddons) {
      if (addon == 'Extra Cheese') {
        addonsTotal += isSmall ? 20 : 30;
      } else if (addon == 'Paneer') {
        addonsTotal += isSmall ? 30 : 50;
      } else if (addon == 'Veggie') {
        addonsTotal += isSmall ? 20 : 30;
      }
    }
    
    return base + addonsTotal;
  }

  double get totalPrice => unitPrice * quantity;
}
