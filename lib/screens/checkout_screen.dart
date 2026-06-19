import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../services/cart_service.dart';
import '../services/supabase_service.dart';
import '../models/address_model.dart';

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

      await SupabaseService.placeOrder(
        address: _selectedAddress!.fullAddress,
        mobile: _selectedAddress!.phoneNumber,
        paymentMode: _paymentMode,
        totalAmount: CartService.subtotal,
        items: orderItems,
      );

      if (mounted) {
        await CartService.clearCart(); 
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
                  Navigator.of(context).pop(); 
                  Navigator.of(context).pushReplacementNamed('/home'); 
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

            _buildSectionTitle('Delivery Address', scale),
            _buildAddressSection(scale),
            
            SizedBox(height: 24 * scale),

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

            _buildSectionTitle('Payment Mode', scale),
            _buildPaymentOption('COD', 'Cash on Delivery', Icons.money_rounded, scale),
            const SizedBox(height: 12),
            _buildPaymentOption('Online', 'Pay Online', Icons.payment_rounded, scale),
            
            SizedBox(height: 32 * scale),

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

  Widget _buildAddressSection(double scale) {
    if (_isLoadingAddresses) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_addresses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE8D5C0)),
        ),
        child: Column(
          children: [
            Text(
              'No saved addresses found',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.pushNamed(context, '/addresses');
                _fetchAddresses();
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Address', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8D5C0)),
      ),
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _addresses.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[100]),
            itemBuilder: (context, index) {
              final address = _addresses[index];
              final isSelected = _selectedAddress?.id == address.id;
              return ListTile(
                onTap: () => setState(() => _selectedAddress = address),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? AppColors.primary : Colors.grey,
                ),
                title: Text(address.title, style: GoogleFonts.poppins(fontSize: 14 * scale, fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(address.fullAddress, style: GoogleFonts.poppins(fontSize: 12 * scale, color: Colors.grey[600])),
                    Text('Ph: ${address.phoneNumber}', style: GoogleFonts.poppins(fontSize: 11 * scale, fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            },
          ),
          Divider(height: 1, color: Colors.grey[100]),
          TextButton.icon(
            onPressed: () async {
              await Navigator.pushNamed(context, '/addresses');
              _fetchAddresses();
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add New Address'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
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
