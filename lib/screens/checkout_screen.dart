import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../services/cart_service.dart';
import '../services/supabase_service.dart';
import '../models/address_model.dart';
import '../services/notification_service.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _couponController = TextEditingController();
  String _paymentMode = 'COD';
  bool _isPlacingOrder = false;
  List<AddressModel> _addresses = [];
  AddressModel? _selectedAddress;
  bool _isLoadingAddresses = true;

  // Coupon variables
  Map<String, dynamic>? _appliedCoupon;
  double _discountAmount = 0.0;
  bool _isValidatingCoupon = false;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _fetchAddresses() async {
    setState(() => _isLoadingAddresses = true);
    try {
      final data = await SupabaseService.getAddresses();
      if (mounted) {
        setState(() {
          _addresses = data.map((json) => AddressModel.fromJson(json)).toList();
          if (_addresses.isNotEmpty) {
            _selectedAddress = _addresses.first;
          }
          _isLoadingAddresses = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAddresses = false);
      }
    }
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isValidatingCoupon = true);
    try {
      final coupon = await SupabaseService.validateCoupon(code);
      if (coupon == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid or expired coupon code'), backgroundColor: Colors.red),
          );
        }
        setState(() {
          _appliedCoupon = null;
          _discountAmount = 0.0;
          _isValidatingCoupon = false;
        });
        return;
      }

      // Check min purchase
      final minPurchase = (coupon['min_purchase'] ?? 0).toDouble();
      if (CartService.subtotal < minPurchase) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Min purchase for this coupon is ₹$minPurchase'), backgroundColor: Colors.orange),
          );
        }
        setState(() {
          _appliedCoupon = null;
          _discountAmount = 0.0;
          _isValidatingCoupon = false;
        });
        return;
      }

      // Calculate discount
      double discount = 0.0;
      final value = (coupon['discount_value'] ?? 0).toDouble();
      if (coupon['discount_type'] == 'percentage') {
        discount = CartService.subtotal * (value / 100);
        final maxDiscount = coupon['max_discount']?.toDouble();
        if (maxDiscount != null && discount > maxDiscount) {
          discount = maxDiscount;
        }
      } else {
        discount = value;
      }

      setState(() {
        _appliedCoupon = coupon;
        _discountAmount = discount;
        _isValidatingCoupon = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Coupon applied! You saved ₹${discount.toInt()}'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
        setState(() {
          _appliedCoupon = null;
          _discountAmount = 0.0;
          _isValidatingCoupon = false;
        });
      }
    }
  }

  Future<void> _placeOrder() async {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery address'), backgroundColor: Colors.orange),
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

      final totalAfterDiscount = CartService.subtotal - _discountAmount;

      final result = await SupabaseService.placeOrder(
        address: _selectedAddress!.fullAddress,
        mobile: _selectedAddress!.phoneNumber,
        paymentMode: _paymentMode,
        totalAmount: totalAfterDiscount,
        items: orderItems,
        couponId: _appliedCoupon?['id'],
      );

      if (mounted) {
        await CartService.clearCart(); 
        setState(() => _isPlacingOrder = false);
        
        // Show local notification
        NotificationService.showNotification(
          title: 'Order Placed! 🍕',
          body: 'Your order #${result['id']} has been placed successfully.',
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => OrderSuccessScreen(orderData: result))
        );
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
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
            const SizedBox(height: 16),
            Text('Order Placed!', 
              style: GoogleFonts.poppins(
                fontSize: 20, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
              )),
            const SizedBox(height: 8),
            Text('Your delicious pizza is on its way.', 
              textAlign: TextAlign.center, 
              style: GoogleFonts.poppins(color: Colors.grey)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); 
                  Navigator.of(context).pushReplacementNamed('/home'); 
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.bold)),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final finalTotal = CartService.subtotal - _discountAmount;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Checkout',
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : Colors.black, 
            fontWeight: FontWeight.bold
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Order Summary', scale, isDark),
            Container(
              decoration: BoxDecoration(
                color: isDark ? theme.cardColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8D5C0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cartItems.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[100]),
                itemBuilder: (context, index) {
                  final item = cartItems[index];
                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 50 * scale,
                        height: 50 * scale,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFFFF0DC), 
                          borderRadius: BorderRadius.circular(10)
                        ),
                        child: Image.network(item.pizza.imageUrl, errorBuilder: (_, __, ___) => Image.asset('assets/images/pizza.png')),
                      ),
                      title: Text(item.pizza.name, 
                        style: GoogleFonts.poppins(
                          fontSize: 14 * scale, 
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        )),
                      subtitle: Text('Qty: ${item.quantity}', 
                        style: GoogleFonts.poppins(fontSize: 12 * scale, color: Colors.grey)),
                      trailing: Text('₹${item.totalPrice.toInt()}', 
                        style: GoogleFonts.poppins(
                          fontSize: 14 * scale, 
                          fontWeight: FontWeight.bold, 
                          color: AppColors.primary
                        )),
                    ),
                  );
                },
              ),
            ),
            
            SizedBox(height: 24 * scale),

            _buildSectionTitle('Delivery Address', scale, isDark),
            _buildAddressSection(scale, isDark, theme),
            
            SizedBox(height: 24 * scale),

            _buildSectionTitle('Coupon Code', scale, isDark),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _couponController,
                    hintText: 'Enter Coupon',
                    scale: scale,
                    isDark: isDark,
                    enabled: _appliedCoupon == null,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isValidatingCoupon || _isPlacingOrder ? null : (_appliedCoupon == null ? _applyCoupon : () => setState(() {
                    _appliedCoupon = null;
                    _discountAmount = 0.0;
                    _couponController.clear();
                  })),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _appliedCoupon == null ? (isDark ? Colors.white : Colors.black) : Colors.red,
                    foregroundColor: _appliedCoupon == null ? (isDark ? Colors.black : Colors.white) : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isValidatingCoupon 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_appliedCoupon == null ? 'Apply' : 'Remove', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            
            SizedBox(height: 24 * scale),

            _buildSectionTitle('Payment Mode', scale, isDark),
            _buildPaymentOption('COD', 'Cash on Delivery', Icons.money_rounded, scale, isDark, theme),
            const SizedBox(height: 12),
            _buildPaymentOption('Online', 'Pay Online', Icons.payment_rounded, scale, isDark, theme),
            
            SizedBox(height: 32 * scale),

            // Billing Details
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? theme.cardColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white10 : AppColors.primary.withAlpha(50)),
              ),
              child: Column(
                children: [
                  _buildPriceRow('Subtotal', CartService.subtotal, isDark),
                  if (_discountAmount > 0) ...[
                    const SizedBox(height: 8),
                    _buildPriceRow('Coupon Discount', -_discountAmount, isDark, isDiscount: true),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Grand Total', style: GoogleFonts.poppins(color: Colors.grey)),
                          Text('₹${finalTotal.toInt()}', 
                            style: GoogleFonts.poppins(
                              fontSize: 24, 
                              fontWeight: FontWeight.bold, 
                              color: AppColors.primary
                            )),
                        ],
                      ),
                      SizedBox(
                        height: 54,
                        width: 150 * scale,
                        child: ElevatedButton(
                          onPressed: _isPlacingOrder ? null : _placeOrder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _isPlacingOrder 
                            ? const SizedBox(
                                height: 24, 
                                width: 24, 
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              )
                            : const Text('Place Order', 
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
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

  Widget _buildPriceRow(String label, double amount, bool isDark, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.grey[700], fontSize: 14)),
        Text(
          '${isDiscount ? "-" : ""}₹${amount.abs().toInt()}', 
          style: GoogleFonts.poppins(
            color: isDiscount ? Colors.green : (isDark ? Colors.white : Colors.black),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          )
        ),
      ],
    );
  }

  Widget _buildAddressSection(double scale, bool isDark, ThemeData theme) {
    if (_isLoadingAddresses) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_addresses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? theme.cardColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8D5C0)),
        ),
        child: Column(
          children: [
            Text(
              'No saved addresses found',
              style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.pushNamed(context, '/addresses');
                _fetchAddresses();
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8D5C0)),
      ),
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _addresses.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[100]),
            itemBuilder: (context, index) {
              final address = _addresses[index];
              final isSelected = _selectedAddress?.id == address.id;
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  onTap: () => setState(() => _selectedAddress = address),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? AppColors.primary : (isDark ? Colors.white24 : Colors.grey),
                  ),
                  title: Text(address.title, 
                    style: GoogleFonts.poppins(
                      fontSize: 14 * scale, 
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    )),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(address.fullAddress, 
                        style: GoogleFonts.poppins(
                          fontSize: 12 * scale, 
                          color: isDark ? Colors.white60 : Colors.grey[600]
                        )),
                      Text('Ph: ${address.phoneNumber}', 
                        style: GoogleFonts.poppins(
                          fontSize: 11 * scale, 
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : Colors.grey[800]
                        )),
                    ],
                  ),
                ),
              );
            },
          ),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[100]),
          TextButton.icon(
            onPressed: () async {
              await Navigator.pushNamed(context, '/addresses');
              _fetchAddresses();
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add New Address', style: TextStyle(fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, double scale, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16 * scale, 
          fontWeight: FontWeight.bold, 
          color: isDark ? Colors.white : Colors.black87
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    required double scale,
    required bool isDark,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(color: isDark ? Colors.white24 : Colors.grey[400], fontSize: 14 * scale),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE8D5C0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE8D5C0)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE8D5C0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String value, String label, IconData icon, double scale, bool isDark, ThemeData theme) {
    bool isSelected = _paymentMode == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMode = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
            ? AppColors.primary.withOpacity(0.1) 
            : (isDark ? theme.cardColor : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? Colors.white10 : const Color(0xFFE8D5C0))
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : (isDark ? Colors.white38 : Colors.grey)),
            const SizedBox(width: 12),
            Text(label, 
              style: GoogleFonts.poppins(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              )),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
