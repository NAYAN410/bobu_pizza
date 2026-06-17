import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../services/cart_service.dart';
import '../services/supabase_service.dart';
import '../models/cart_item_model.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addressController = TextEditingController();
  final _mobileController = TextEditingController();
  final _couponController = TextEditingController();
  String _paymentMode = 'COD';
  bool _isPlacingOrder = false;

  @override
  void dispose() {
    _addressController.dispose();
    _mobileController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (_addressController.text.isEmpty || _mobileController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter address and mobile number'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isPlacingOrder = true);
    
    try {
      final cartItems = CartService.items;
      final List<Map<String, dynamic>> orderItems = cartItems.map((item) => {
        'pizza_id': item.pizza.id,
        'quantity': item.quantity,
        'price': item.pizza.discountedPrice,
      }).toList();

      await SupabaseService.placeOrder(
        address: _addressController.text.trim(),
        mobile: _mobileController.text.trim(),
        paymentMode: _paymentMode,
        totalAmount: CartService.subtotal,
        items: orderItems,
      );

      if (mounted) {
        await CartService.clearCart(); // Clear local and remote cart
        setState(() => _isPlacingOrder = false);
        
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to place order: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
            const SizedBox(height: 16),
            Text('Order Placed!', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Your delicious pizza is on its way.', textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // close dialog
                  Navigator.of(context).pushReplacementNamed('/home'); // back to home
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back to Home', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final double scale = (sw.clamp(0.0, 430.0) / 375).clamp(0.85, 1.1);
    final cartItems = CartService.items;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Checkout',
          style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Order Items Summary
            _buildSectionTitle('Order Summary', scale),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8D5C0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cartItems.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[100]),
                itemBuilder: (context, index) {
                  final item = cartItems[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 50 * scale,
                      height: 50 * scale,
                      decoration: BoxDecoration(color: const Color(0xFFFFF0DC), borderRadius: BorderRadius.circular(10)),
                      child: Image.network(item.pizza.imageUrl, errorBuilder: (_, __, ___) => Image.asset('assets/images/pizza.png')),
                    ),
                    title: Text(item.pizza.name, style: GoogleFonts.poppins(fontSize: 14 * scale, fontWeight: FontWeight.w600)),
                    subtitle: Text('Qty: ${item.quantity}', style: GoogleFonts.poppins(fontSize: 12 * scale, color: Colors.grey)),
                    trailing: Text('₹${item.totalPrice.toInt()}', style: GoogleFonts.poppins(fontSize: 14 * scale, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  );
                },
              ),
            ),
            
            SizedBox(height: 24 * scale),

            // 2. Delivery Address
            _buildSectionTitle('Delivery Address', scale),
            _buildTextField(
              controller: _addressController,
              hintText: 'Flat No, Building Name, Area...',
              maxLines: 3,
              scale: scale,
            ),
            
            SizedBox(height: 16 * scale),

            // 3. Mobile Number
            _buildSectionTitle('Mobile Number', scale),
            _buildTextField(
              controller: _mobileController,
              hintText: '+91 00000 00000',
              keyboardType: TextInputType.phone,
              scale: scale,
            ),
            
            SizedBox(height: 24 * scale),

            // 4. Coupon Code
            _buildSectionTitle('Coupon Code', scale),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _couponController,
                    hintText: 'Enter Coupon',
                    scale: scale,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Apply', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            
            SizedBox(height: 24 * scale),

            // 5. Payment Mode
            _buildSectionTitle('Payment Mode', scale),
            _buildPaymentOption('COD', 'Cash on Delivery', Icons.money_rounded, scale),
            const SizedBox(height: 12),
            _buildPaymentOption('Online', 'Pay Online', Icons.payment_rounded, scale),
            
            SizedBox(height: 32 * scale),

            // 6. Total Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withAlpha(50)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Grand Total', style: GoogleFonts.poppins(color: Colors.grey)),
                      Text('₹${CartService.subtotal.toInt()}', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                  SizedBox(
                    height: 54,
                    width: 150 * scale,
                    child: ElevatedButton(
                      onPressed: _isPlacingOrder ? null : _placeOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isPlacingOrder 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Place Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 40 * scale),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, double scale) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 16 * scale, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    required double scale,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14 * scale),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8D5C0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8D5C0)),
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String value, String label, IconData icon, double scale) {
    bool isSelected = _paymentMode == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMode = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(20) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFE8D5C0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : Colors.grey),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.poppins(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
