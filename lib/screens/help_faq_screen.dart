import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';

class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final double scale = (sw.clamp(0.0, 430.0) / 375).clamp(0.85, 1.1);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final faqs = [
      {
        'question': 'How do I place an order?',
        'answer': 'Simply browse our delicious pizzas, add them to your cart, and proceed to checkout. You can choose your preferred delivery address and payment method.'
      },
      {
        'question': 'What are your delivery hours?',
        'answer': 'We deliver every day from 10:00 AM to 11:00 PM. Last orders are taken 30 minutes before closing.'
      },
      {
        'question': 'How can I track my order?',
        'answer': 'Once your order is placed, you can track its status in real-time through the "My Orders" section in your profile.'
      },
      {
        'question': 'What payment methods do you accept?',
        'answer': 'We accept credit/debit cards, UPI, and Cash on Delivery.'
      },
      {
        'question': 'How do I cancel my order?',
        'answer': 'You can cancel your order within 5 minutes of placing it. After that, we start preparing your fresh pizza and cancellations are not possible.'
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Help & FAQ',
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
      body: ListView.builder(
        padding: EdgeInsets.all(16 * scale),
        physics: const BouncingScrollPhysics(),
        itemCount: faqs.length,
        itemBuilder: (context, index) {
          final faq = faqs[index];
          return Container(
            margin: EdgeInsets.only(bottom: 16 * scale),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE8D5C0),
                width: 1,
              ),
              boxShadow: isDark ? [] : [
                BoxShadow(
                  color: const Color(0xFF2D1A0E).withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ExpansionTile(
              shape: const RoundedRectangleBorder(side: BorderSide.none),
              title: Text(
                faq['question']!,
                style: GoogleFonts.poppins(
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF2D1A0E),
                ),
              ),
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16 * scale, 0, 16 * scale, 16 * scale),
                  child: Text(
                    faq['answer']!,
                    style: GoogleFonts.poppins(
                      fontSize: 13 * scale,
                      color: isDark ? Colors.white70 : const Color(0xFF2D1A0E).withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
