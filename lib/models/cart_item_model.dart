import 'pizza_model.dart';

class CartItem {
  final Pizza pizza;
  int quantity;

  CartItem({
    required this.pizza,
    this.quantity = 1,
  });

  double get totalPrice => pizza.discountedPrice * quantity;
}
