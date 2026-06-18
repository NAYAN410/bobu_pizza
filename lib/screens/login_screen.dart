import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../core/constants.dart';
import '../services/supabase_service.dart';
import '../services/cart_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isOtpSent = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack('Please enter your email', Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );
      setState(() => _isOtpSent = true);
      _showSnack('OTP sent to your email!', Colors.green);
    } on AuthException catch (e) {
      _showSnack(e.message, Colors.red);
    } catch (_) {
      _showSnack('Unexpected error occurred', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      _showSnack('Please enter the OTP', Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email,
      );
      // Sync cart immediately after login
      await CartService.fetchCartFromDb();
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } on AuthException catch (e) {
      _showSnack(e.message, Colors.red);
    } catch (_) {
      _showSnack('Verification failed', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // 1. Generate a random nonce for security
      final rawNonce = Supabase.instance.client.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final googleSignIn = GoogleSignIn(
        clientId: '474443519088-3druogolel6953mb25gkgcb4p3o2jnlo.apps.googleusercontent.com',
        serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
      );
      
      await googleSignIn.signOut();
      final googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; 
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) throw 'No ID Token found.';

      // 2. Pass the raw nonce to Supabase
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
        nonce: rawNonce, // This is crucial to fix the nonce error
      );

      await CartService.fetchCartFromDb();
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      if (mounted) _showSnack('Google sign-in failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double sw = size.width;
    final double sh = size.height;
    final double contentWidth = sw.clamp(0.0, 430.0);
    final double scale = (contentWidth / 375).clamp(0.85, 1.1);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF8F0),
              Color(0xFFFFF0DC),
              Color(0xFFFFE8C8),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              // ── Sauce splash — anchored to TOP of screen, not scroll ──
              Positioned(
                top: -sh * 0.04,
                left: -(contentWidth * 0.1),
                child: Hero(
                  tag: 'sauce_splash',
                  child: Image.asset(
                    'assets/images/splash.png',
                    width: contentWidth * 1.3,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // ── Pizza watermark — anchored to BOTTOM of screen ──
              Positioned(
                bottom: -40 * scale,
                right: -40 * scale,
                child: Opacity(
                  opacity: 0.12,
                  child: Image.asset(
                    'assets/images/pizza.png',
                    width: 180 * scale,
                  ),
                ),
              ),

              // ── Scrollable content ──
              SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Center(
                      child: SizedBox(
                        width: contentWidth,
                        child: SingleChildScrollView(
                          padding:
                          EdgeInsets.symmetric(horizontal: 28 * scale),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Top space — pushes logo to roughly screen center
                              SizedBox(height: sh * 0.10),

                              // ── Logo ──
                              _buildLogo(scale),

                              SizedBox(height: 32 * scale),

                              // ── Heading ──
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  _isOtpSent ? 'Check your email' : 'Welcome!',
                                  key: ValueKey(_isOtpSent),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 26 * scale,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2D1A0E),
                                  ),
                                ),
                              ),

                              SizedBox(height: 6 * scale),

                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  _isOtpSent
                                      ? 'Enter the 6-digit code sent to\n${_emailController.text.trim()}'
                                      : 'Login or register with your email',
                                  key: ValueKey('sub_$_isOtpSent'),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13 * scale,
                                    color: const Color(0xFF2D1A0E)
                                        .withOpacity(0.5),
                                    height: 1.5,
                                  ),
                                ),
                              ),

                              SizedBox(height: 32 * scale),

                              // ── Email field ──
                              _buildTextField(
                                controller: _emailController,
                                hintText: 'Email Address',
                                prefixIcon: Icons.email_outlined,
                                enabled: !_isOtpSent,
                                scale: scale,
                              ),

                              // ── OTP field (slides in when OTP sent) ──
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                child: _isOtpSent
                                    ? Padding(
                                  padding: EdgeInsets.only(
                                      top: 16 * scale),
                                  child: _buildOtpField(scale),
                                )
                                    : const SizedBox.shrink(),
                              ),

                              SizedBox(height: 24 * scale),

                              // ── Primary button ──
                              _buildPrimaryButton(
                                label: _isOtpSent
                                    ? 'Verify & Login'
                                    : 'Send OTP',
                                onTap: _isLoading
                                    ? null
                                    : (_isOtpSent ? _verifyOtp : _sendOtp),
                                isLoading: _isLoading,
                                scale: scale,
                              ),

                              // ── Change email link ──
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                child: _isOtpSent
                                    ? TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () => setState(
                                          () => _isOtpSent = false),
                                  child: Text(
                                    'Change Email',
                                    style: GoogleFonts.poppins(
                                      color: AppColors.primary,
                                      fontSize: 13 * scale,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )
                                    : const SizedBox.shrink(),
                              ),

                              SizedBox(height: 28 * scale),

                              // ── Divider ──
                              _buildDivider(scale),

                              SizedBox(height: 28 * scale),

                              // ── Google button ──
                              _buildGoogleButton(scale),

                              SizedBox(height: 48 * scale),
                            ],
                          ),
                        ),
                      ),
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

  // ─── Logo ─────────────────────────────────────────────────────────

  Widget _buildLogo(double scale) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Bobu',
          textAlign: TextAlign.center,
          style: GoogleFonts.hurricane(
            fontSize: 90 * scale,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            height: 0.75,
            shadows: [
              Shadow(
                color: AppColors.primary.withOpacity(0.15),
                offset: Offset(2 * scale, 3 * scale),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 4 * scale),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 30 * scale,
                  height: 1.2,
                  color: AppColors.pizzaGreen.withOpacity(0.5)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 6 * scale),
                child: Icon(Icons.local_pizza_outlined,
                    size: 13 * scale,
                    color: AppColors.pizzaGreen.withOpacity(0.7)),
              ),
              Container(
                  width: 30 * scale,
                  height: 1.2,
                  color: AppColors.pizzaGreen.withOpacity(0.5)),
            ],
          ),
        ),
        Text(
          'Pizza',
          textAlign: TextAlign.center,
          style: GoogleFonts.italianno(
            fontSize: 36 * scale,
            color: AppColors.pizzaGreen,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  // ─── OTP field with big digit boxes ───────────────────────────────

  Widget _buildOtpField(double scale) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8D5C0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4956A).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _otpController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 22 * scale,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF2D1A0E),
          letterSpacing: 10,
        ),
        decoration: InputDecoration(
          hintText: '• • • • • •',
          hintStyle: GoogleFonts.poppins(
            color: const Color(0xFF2D1A0E).withOpacity(0.25),
            fontSize: 18 * scale,
            letterSpacing: 8,
          ),
          prefixIcon: Icon(Icons.pin_outlined,
              color: AppColors.primary.withOpacity(0.7), size: 20 * scale),
          border: InputBorder.none,
          counterText: '', // hides the maxLength counter
          contentPadding:
          EdgeInsets.symmetric(horizontal: 20, vertical: 16 * scale),
        ),
      ),
    );
  }

  // ─── Email field ───────────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.emailAddress,
    required double scale,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled
            ? Colors.white.withOpacity(0.75)
            : Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8D5C0), width: 1.2),
        boxShadow: [
          if (enabled)
            BoxShadow(
              color: const Color(0xFFD4956A).withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(
          fontSize: 14 * scale,
          color: const Color(0xFF2D1A0E),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(
            color: const Color(0xFF2D1A0E).withOpacity(0.35),
            fontSize: 14 * scale,
          ),
          prefixIcon: Icon(prefixIcon,
              color: AppColors.primary.withOpacity(0.7), size: 20 * scale),
          border: InputBorder.none,
          contentPadding:
          EdgeInsets.symmetric(horizontal: 20, vertical: 16 * scale),
        ),
      ),
    );
  }

  // ─── Primary button ────────────────────────────────────────────────

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onTap,
    required bool isLoading,
    required double scale,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54 * scale,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: AppColors.primary.withOpacity(0.35),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: isLoading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2),
        )
            : Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16 * scale,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // ─── Divider ───────────────────────────────────────────────────────

  Widget _buildDivider(double scale) {
    return Row(
      children: [
        Expanded(
            child: Divider(
                color: const Color(0xFF2D1A0E).withOpacity(0.15))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12 * scale),
          child: Text(
            'OR',
            style: GoogleFonts.poppins(
              color: const Color(0xFF2D1A0E).withOpacity(0.35),
              fontSize: 11 * scale,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
            child: Divider(
                color: const Color(0xFF2D1A0E).withOpacity(0.15))),
      ],
    );
  }

  // ─── Google button ─────────────────────────────────────────────────

  Widget _buildGoogleButton(double scale) {
    return GestureDetector(
      onTap: _isLoading ? null : _signInWithGoogle,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 14 * scale),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8D5C0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
              height: 22 * scale,
              width: 22 * scale,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.g_mobiledata, size: 22 * scale),
            ),
            SizedBox(width: 12 * scale),
            Text(
              'Continue with Google',
              style: GoogleFonts.poppins(
                fontSize: 15 * scale,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2D1A0E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}