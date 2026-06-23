import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final double scale = (sw.clamp(0.0, 430.0) / 375).clamp(0.85, 1.1);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Map<String, String>> sections = [
      {
        'title': '1. Information We Collect',
        'content': 'We collect information you provide directly to us, such as when you create an account, place an order, or contact customer support. This may include your name, email, phone number, and delivery address.'
      },
      {
        'title': '2. How We Use Your Information',
        'content': 'We use your information to process and deliver your orders, send you updates about your order status, improve our services, and send you promotional offers if you have opted in.'
      },
      {
        'title': '3. Data Security',
        'content': 'We implement appropriate security measures to protect your personal information from unauthorized access, alteration, or disclosure. However, no method of transmission over the internet is 100% secure.'
      },
      {
        'title': '4. Third-Party Services',
        'content': 'We may use third-party services for payments and delivery. These providers have access to your information only to perform specific tasks on our behalf and are obligated not to disclose it.'
      },
      {
        'title': '5. Your Rights',
        'content': 'You have the right to access, update, or delete your personal information at any time through your profile settings or by contacting us.'
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18 * scale,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20 * scale),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last Updated: October 2023',
              style: GoogleFonts.poppins(
                fontSize: 12 * scale,
                color: isDark ? Colors.white38 : Colors.black38,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 24 * scale),
            ...sections.map((section) => Padding(
              padding: EdgeInsets.bottom(24 * scale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section['title']!,
                    style: GoogleFonts.poppins(
                      fontSize: 15 * scale,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF2D1A0E),
                    ),
                  ),
                  SizedBox(height: 8 * scale),
                  Text(
                    section['content']!,
                    style: GoogleFonts.poppins(
                      fontSize: 13 * scale,
                      height: 1.6,
                      color: isDark ? Colors.white70 : const Color(0xFF2D1A0E).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            )),
            SizedBox(height: 20 * scale),
            Container(
              padding: EdgeInsets.all(16 * scale),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.1)),
              ),
              child: Text(
                'If you have any questions about this Privacy Policy, please contact us at support@bobupizza.com',
                style: GoogleFonts.poppins(
                  fontSize: 12 * scale,
                  fontStyle: FontStyle.italic,
                  color: AppColors.primary.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 40 * scale),
          ],
        ),
      ),
    );
  }
}
