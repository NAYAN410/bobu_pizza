import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../core/constants.dart';

class OrderSuccessScreen extends StatelessWidget {
  final Map<String, dynamic> orderData;

  const OrderSuccessScreen({super.key, required this.orderData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sw = MediaQuery.of(context).size.width;
    final scale = (sw.clamp(0.0, 430.0) / 375).clamp(0.85, 1.1);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark ? AppColors.bgGradientDark : AppColors.bgGradient,
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 30 * scale),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Success Animation
                Center(
                  child: Lottie.network(
                    'https://assets10.lottiefiles.com/packages/lf20_kz9pjcjt.json',
                    width: 200 * scale,
                    height: 200 * scale,
                    repeat: false,
                    errorBuilder: (context, error, stackTrace) => 
                      Icon(Icons.check_circle, color: isDark ? Colors.greenAccent : Colors.green, size: 100),
                  ),
                ),
                
                Text(
                  'Order Placed!',
                  style: GoogleFonts.poppins(
                    fontSize: 28 * scale,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF2D1A0E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your delicious pizza is on its way.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14 * scale,
                    color: isDark ? Colors.white60 : Colors.grey[700],
                  ),
                ),

                const SizedBox(height: 40),

                // PIN Container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withAlpha(13) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8D5C0)),
                    boxShadow: isDark ? [] : [
                      BoxShadow(
                        color: const Color(0xFF2D1A0E).withAlpha(15), 
                        blurRadius: 20, 
                        offset: const Offset(0, 10)
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'DELIVERY PIN',
                        style: GoogleFonts.poppins(
                          fontSize: 12 * scale,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        orderData['delivery_pin'],
                        style: GoogleFonts.poppins(
                          fontSize: 48 * scale,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                          color: isDark ? Colors.white : const Color(0xFF2D1A0E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Show this PIN to delivery partner',
                        style: GoogleFonts.poppins(
                          fontSize: 11 * scale,
                          color: isDark ? Colors.white38 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Order Summary Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withAlpha(8) : const Color(0xFFFFF0DC).withAlpha(76),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow('Order ID', orderData['id'], isDark),
                      const SizedBox(height: 10),
                      _buildInfoRow('Total Amount', '₹${orderData['total'].toInt()}', isDark, isBold: true),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Done Button
                SizedBox(
                  width: double.infinity,
                  height: 56 * scale,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 6,
                      shadowColor: AppColors.primary.withAlpha(76),
                    ),
                    child: Text(
                      'Back to Home',
                      style: GoogleFonts.poppins(fontSize: 16 * scale, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, 
          style: GoogleFonts.poppins(
            fontSize: 13, 
            color: isDark ? Colors.white38 : Colors.grey[600]
          )
        ),
        Text(
          value, 
          style: GoogleFonts.poppins(
            fontSize: 14, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF2D1A0E),
          )
        ),
      ],
    );
  }
}
