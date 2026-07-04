import 'pizza_model.dart';

class CartItem {
  final Pizza pizza;
  final String? selectedSize;
  int quantity;

  CartItem({
    required this.pizza,
    this.selectedSize,
    this.quantity = 1,
  });

  double get unitPrice {
    if (selectedSize != null) {
      return pizza.getPriceForSize(selectedSize!);
    }
    return pizza.discountedPrice;
  }

  double get totalPrice => unitPrice * quantity;
}
