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

    final List<dynamic> items = orderData['items'] ?? [];

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
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 50),
                          Center(
                            child: Lottie.network(
                              'https://lottie.host/95006b53-4870-4d43-9844-3d0d828a2a0d/r44Z6FwH89.json',
                              width: 180 * scale,
                              height: 180 * scale,
                              repeat: false,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 180 * scale,
                                  height: 180 * scale,
                                  margin: const EdgeInsets.only(bottom: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withAlpha(20),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.green,
                                    size: 100 * scale,
                                  ),
                                );
                              },
                            ),
                          ),
                          Text(
                            'Order Placed!',
                            style: GoogleFonts.poppins(
                              fontSize: 26 * scale,
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
                          const SizedBox(height: 32),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
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
                                    fontSize: 11 * scale,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  orderData['delivery_pin'] ?? '000000',
                                  style: GoogleFonts.poppins(
                                    fontSize: 42 * scale,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 8,
                                    color: isDark ? Colors.white : const Color(0xFF2D1A0E),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Show this PIN to delivery partner',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10 * scale,
                                    color: isDark ? Colors.white38 : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (items.isNotEmpty) ...[
                            _buildSectionHeader('Order Details', isDark, scale),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withAlpha(8) : Colors.white.withAlpha(150),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8D5C0).withAlpha(100)),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: items.length,
                                separatorBuilder: (context, index) => Divider(height: 24, color: isDark ? Colors.white10 : Colors.grey[200]),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return Row(
                                    children: [
                                      Container(
                                        width: 45 * scale,
                                        height: 45 * scale,
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white.withAlpha(10) : const Color(0xFFFFF0DC),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: item['image_url'] != null 
                                            ? Image.network(item['image_url'], fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.local_pizza, size: 20))
                                            : const Icon(Icons.local_pizza, size: 20),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['name'] ?? '',
                                              style: GoogleFonts.poppins(fontSize: 13 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                                            ),
                                            Text(
                                              'Qty: ${item['quantity']} ${item['size'] != null ? '• ${item['size']}' : ''}',
                                              style: GoogleFonts.poppins(fontSize: 11 * scale, color: Colors.grey),
                                            ),
                                            if (item['addons'] != null && (item['addons'] as List).isNotEmpty)
                                              Text(
                                                '+ ${(item['addons'] as List).join(", ")}',
                                                style: GoogleFonts.poppins(fontSize: 10 * scale, color: AppColors.primary.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '₹${(item['price'] * item['quantity']).toInt()}',
                                        style: GoogleFonts.poppins(fontSize: 13 * scale, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          _buildSectionHeader('Payment Summary', isDark, scale),
                          const SizedBox(height: 12),
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
                                _buildInfoRow('Order ID', orderData['id'] ?? '', isDark, scale),
                                const SizedBox(height: 12),
                                _buildInfoRow('Payment Method', orderData['payment_mode'] ?? 'COD', isDark, scale),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(height: 1),
                                ),
                                _buildInfoRow('Total Amount', '₹${(orderData['total'] ?? 0).toInt()}', isDark, scale, isBold: true, isPrimary: true),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 24 * scale,
                left: 24 * scale,
                right: 24 * scale,
                child: SizedBox(
                  width: double.infinity,
                  height: 56 * scale,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
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
              ),
              Positioned(
                top: 10,
                left: 16,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(26) : Colors.black.withAlpha(26),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded, 
                      color: isDark ? Colors.white : Colors.black, 
                      size: 20 * scale
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark, double scale) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14 * scale,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white70 : const Color(0xFF2D1A0E).withAlpha(200),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, double scale, {bool isBold = false, bool isPrimary = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, 
          style: GoogleFonts.poppins(
            fontSize: 13 * scale, 
            color: isDark ? Colors.white38 : Colors.grey[600]
          )
        ),
        Text(
          value, 
          style: GoogleFonts.poppins(
            fontSize: isPrimary ? 18 * scale : 14 * scale, 
            fontWeight: isBold || isPrimary ? FontWeight.bold : FontWeight.w500,
            color: isPrimary ? AppColors.primary : (isDark ? Colors.white : const Color(0xFF2D1A0E)),
          )
        ),
      ],
    );
  }
}
