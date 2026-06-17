import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../services/cart_service.dart';
import '../../models/cart_item_model.dart';

class CartTab extends StatefulWidget {
  const CartTab({super.key});

  @override
  State<CartTab> createState() => _CartTabState();
}

class _CartTabState extends State<CartTab> {
  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final double scale = (sw.clamp(0.0, 430.0) / 375).clamp(0.85, 1.1);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: ValueListenableBuilder<List<CartItem>>(
          valueListenable: CartService.cartItemsNotifier,
          builder: (context, cartItems, child) {
            if (cartItems.isEmpty) {
              return _buildEmptyCart(scale);
            }
            return Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(20 * scale, 16 * scale, 20 * scale, 12 * scale),
                  child: Row(
                    children: [
                      Text(
                        'Your Cart',
                        style: GoogleFonts.poppins(
                          fontSize: 24 * scale,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D1A0E),
                        ),
                      ),
                      SizedBox(width: 8 * scale),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 3 * scale),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${cartItems.length} items',
                          style: GoogleFonts.poppins(
                            fontSize: 11 * scale,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Items list
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                    physics: const BouncingScrollPhysics(),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) => _buildCartItem(cartItems[index], scale),
                  ),
                ),

                // Checkout bar
                _buildCheckoutBar(scale),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyCart(double scale) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🛍️', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16 * scale),
          Text(
            'Your cart is empty',
            style: GoogleFonts.poppins(
              fontSize: 20 * scale,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D1A0E),
            ),
          ),
          SizedBox(height: 6 * scale),
          Text(
            'Add some delicious pizzas!',
            style: GoogleFonts.poppins(
              fontSize: 13 * scale,
              color: const Color(0xFF2D1A0E).withAlpha(115),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item, double scale) {
    final pizza = item.pizza;
    return Container(
      margin: EdgeInsets.only(bottom: 12 * scale),
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8D5C0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D1A0E).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image
          Container(
            width: 64 * scale,
            height: 64 * scale,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0DC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: pizza.imageUrl.startsWith('http')
                  ? Image.network(pizza.imageUrl, height: 50 * scale, fit: BoxFit.contain)
                  : Image.asset('assets/images/pizza.png', height: 50 * scale, fit: BoxFit.contain),
            ),
          ),
          SizedBox(width: 12 * scale),

          // Name + price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pizza.name,
                  style: GoogleFonts.poppins(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D1A0E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 3 * scale),
                Text(
                  '₹${pizza.discountedPrice.toInt()}',
                  style: GoogleFonts.poppins(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          // Qty controls
          Row(
            children: [
              _qtyButton(
                icon: Icons.remove_rounded,
                scale: scale,
                onTap: () => CartService.updateQuantity(pizza.id, -1),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10 * scale),
                child: Text(
                  '${item.quantity}',
                  style: GoogleFonts.poppins(
                    fontSize: 15 * scale,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D1A0E),
                  ),
                ),
              ),
              _qtyButton(
                icon: Icons.add_rounded,
                scale: scale,
                filled: true,
                onTap: () => CartService.updateQuantity(pizza.id, 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyButton({
    required IconData icon,
    required double scale,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28 * scale,
        height: 28 * scale,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : const Color(0xFFFFF0DC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16 * scale,
          color: filled ? Colors.white : AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildCheckoutBar(double scale) {
    return Container(
      padding: EdgeInsets.fromLTRB(20 * scale, 14 * scale, 20 * scale, 20 * scale), // Reduced bottom padding
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D1A0E).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52 * scale,
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(context, '/checkout');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Proceed to Checkout',
                style: GoogleFonts.poppins(
                  fontSize: 15 * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8 * scale),
              Text(
                '₹${CartService.subtotal.toInt()}',
                style: GoogleFonts.poppins(
                  fontSize: 15 * scale,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
