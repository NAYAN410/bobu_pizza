import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'dart:io';
import '../core/constants.dart';
import '../services/supabase_service.dart';
import 'onboarding_screen.dart';
import 'main_screen.dart';
import 'splash_screen.dart';

class ErrorScreen extends StatefulWidget {
  const ErrorScreen({super.key});

  @override
  State<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<ErrorScreen> {
  bool _isRetrying = false;

  Future<void> _handleRetry() async {
    setState(() => _isRetrying = true);

    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
      if (result.isEmpty || result[0].rawAddress.isEmpty) throw Exception();

      Widget nextScreen;
      try {
        final user = await SupabaseService.getCurrentUser();
        nextScreen = (user != null) ? const MainScreen() : const OnboardingScreen();
      } catch (e) {
        nextScreen = const OnboardingScreen();
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => nextScreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Still unable to connect. Please check your internet.'), backgroundColor: AppColors.primary),
        );
      }
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double contentWidth = screenWidth > 500 ? 500 : screenWidth;
    final double scale = contentWidth / 375;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: EdgeInsets.symmetric(horizontal: 40 * scale),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/animations/lost.json', width: 250 * scale, height: 250 * scale, repeat: true, fit: BoxFit.contain),
              SizedBox(height: 40 * scale),
              Text(
                'Oops!',
                style: GoogleFonts.poppins(fontSize: 32 * scale, fontWeight: FontWeight.bold, color: AppColors.textBlack),
              ),
              SizedBox(height: 16 * scale),
              Text(
                'Failed to connect with server',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 16 * scale, color: AppColors.textGrey),
              ),
              SizedBox(height: 48 * scale),
              SizedBox(
                width: double.infinity, height: 56 * scale,
                child: ElevatedButton(
                  onPressed: _isRetrying ? null : _handleRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isRetrying
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Try Again', style: GoogleFonts.poppins(fontSize: 18 * scale, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
