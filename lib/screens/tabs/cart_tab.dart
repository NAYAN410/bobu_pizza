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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: CartService.cartItemsNotifier,
      builder: (context, cartItems, child) {
        if (cartItems.isEmpty) {
          return _buildEmptyCart(scale, isDark);
        }
        return Stack(
          children: [
            Column(
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
                          color: isDark ? Colors.white : const Color(0xFF2D1A0E),
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
                    padding: EdgeInsets.fromLTRB(16 * scale, 0, 16 * scale, 220 * scale),
                    physics: const BouncingScrollPhysics(),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) => _buildCartItem(cartItems[index], scale, isDark),
                  ),
                ),
              ],
            ),

            // Floating Checkout bar
            Positioned(
              bottom: 110 * scale, // Positioned above the floating nav bar
              left: 20 * scale,
              right: 20 * scale,
              child: _buildCheckoutBar(scale, isDark),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyCart(double scale, bool isDark) {
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
              color: isDark ? Colors.white : const Color(0xFF2D1A0E),
            ),
          ),
          SizedBox(height: 6 * scale),
          Text(
            'Add some delicious pizzas!',
            style: GoogleFonts.poppins(
              fontSize: 13 * scale,
              color: isDark ? Colors.white.withAlpha(97) : const Color(0xFF2D1A0E).withAlpha(115),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item, double scale, bool isDark) {
    final pizza = item.pizza;
    return Container(
      margin: EdgeInsets.only(bottom: 12 * scale),
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8D5C0), width: 1),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: const Color(0xFF2D1A0E).withAlpha(13),
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
              color: isDark ? Colors.white.withAlpha(5) : const Color(0xFFFFF0DC),
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
                    color: isDark ? Colors.white : const Color(0xFF2D1A0E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 3 * scale),
                Text(
                  '₹${item.unitPrice.toInt()}',
                  style: GoogleFonts.poppins(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                if (item.selectedSize != null || item.selectedAddons.isNotEmpty)
                  Text(
                    pizza.category == 'BOBU Deals'
                        ? 'Includes: ${item.selectedAddons.join(" & ")}'
                        : '${item.selectedSize ?? ""}${item.selectedAddons.isNotEmpty ? " • +${item.selectedAddons.join(", ")}" : ""}',
                    style: GoogleFonts.poppins(
                      fontSize: 10 * scale,
                      color: isDark ? Colors.white38 : Colors.grey,
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
                isDark: isDark,
                onTap: () => CartService.updateQuantity(pizza.id, -1, size: item.selectedSize, addons: item.selectedAddons),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10 * scale),
                child: Text(
                  '${item.quantity}',
                  style: GoogleFonts.poppins(
                    fontSize: 15 * scale,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF2D1A0E),
                  ),
                ),
              ),
              _qtyButton(
                icon: Icons.add_rounded,
                scale: scale,
                isDark: isDark,
                filled: true,
                onTap: () => CartService.updateQuantity(pizza.id, 1, size: item.selectedSize, addons: item.selectedAddons),
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
    required bool isDark,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28 * scale,
        height: 28 * scale,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : (isDark ? Colors.white10 : const Color(0xFFFFF0DC)),
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

  Widget _buildCheckoutBar(double scale, bool isDark) {
    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(100) : const Color(0xFF2D1A0E).withAlpha(20),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(20) : const Color(0xFFE8D5C0),
          width: 1,
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54 * scale,
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(context, '/checkout');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: AppColors.primary.withAlpha(100),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
              SizedBox(width: 10 * scale),
              Container(
                width: 1,
                height: 20,
                color: Colors.white.withAlpha(100),
              ),
              SizedBox(width: 10 * scale),
              Text(
                '₹${CartService.subtotal.toInt()}',
                style: GoogleFonts.poppins(
                  fontSize: 16 * scale,
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
