import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../services/supabase_service.dart';
import '../services/cart_service.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'error_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _taglineController;
  late AnimationController _pizzaController;
  late AnimationController _rotationController;
  late AnimationController _dotController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _taglineFade;
  late Animation<Offset> _taglineSlide;
  late Animation<Offset> _pizzaSlide;
  late Animation<double> _pizzaFade;

  @override
  void initState() {
    super.initState();
    _setupSystemUI();
    _initControllers();
    _runSequence();
    _initializeApp();
  }

  void _setupSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // White icons for dark splash
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  void _initControllers() {
    // Logo zoom + fade
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    // Tagline slide up + fade
    _taglineController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeIn),
    );
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeOutCubic),
    );

    // Pizza slide up + fade
    _pizzaController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pizzaSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _pizzaController, curve: Curves.easeOutCubic),
    );
    _pizzaFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pizzaController, curve: Curves.easeIn),
    );

    // Continuous pizza rotation
    _rotationController = AnimationController(
      duration: const Duration(seconds: 22),
      vsync: this,
    )..repeat();

    // Progress bar fill animation — will be manually controlled by initialization steps
    _dotController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  Future<void> _runSequence() async {
    // Logo zooms in immediately
    _logoController.forward();

    // Tagline slides up after 500ms
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) _taglineController.forward();

    // Pizza slides up after 900ms
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) _pizzaController.forward();
  }

  Future<void> _initializeApp() async {
    // We start animations immediately, and run init tasks in parallel
    final stopwatch = Stopwatch()..start();

    try {
      // 1. Critical Parallel Initializations (Core services)
      await Future.wait([
        Firebase.initializeApp(),
        dotenv.load(fileName: ".env"),
        ThemeService().init(),
      ]);
      _dotController.animateTo(0.25, curve: Curves.easeInOut);

      // 2. Supabase depends on dotenv
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL'] ?? '',
        anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
      );
      _dotController.animateTo(0.45, curve: Curves.easeInOut);

      // 3. Run non-blocking services & checks in parallel
      final results = await Future.wait([
        InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3)),
        NotificationService.initialize(),
      ]);
      _dotController.animateTo(0.70, curve: Curves.easeInOut);

      final internetResult = results[0] as List<InternetAddress>;

      // Connectivity Check
      if (internetResult.isEmpty || internetResult[0].rawAddress.isEmpty) {
        throw Exception('No internet');
      }

      // 4. Auth & Navigation logic
      Widget nextScreen;
      try {
        final prefs = await SharedPreferences.getInstance();
        final bool isFirstTime = prefs.getBool('is_first_time') ?? true;
        final user = await SupabaseService.getCurrentUser();

        if (user != null) {
          await CartService.fetchCartFromDb();
          NotificationService.listenToOrderStatus();
          nextScreen = const MainScreen();
        } else if (isFirstTime) {
          nextScreen = const OnboardingScreen();
        } else {
          nextScreen = const LoginScreen();
        }
      } catch (e) {
        final prefs = await SharedPreferences.getInstance();
        final bool isFirstTime = prefs.getBool('is_first_time') ?? true;
        nextScreen = isFirstTime ? const OnboardingScreen() : const LoginScreen();
      }

      _dotController.animateTo(1.0, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);

      // Ensure the splash stays visible for at least 2.5 seconds for branding
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < 2500) {
        await Future.delayed(Duration(milliseconds: 2500 - elapsed));
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      debugPrint('Initialization Error: $e');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ErrorScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    _logoController.dispose();
    _taglineController.dispose();
    _pizzaController.dispose();
    _rotationController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  // ─── Scale helpers ────────────────────────────────────────────────

  double _getScale(double w) => (w / 375).clamp(0.8, 1.2);

  double _getContentWidth(double w) => w.clamp(0, 430);

  // ─── Logo block ───────────────────────────────────────────────────

  Widget _buildLogo(double scale) {
    return FadeTransition(
      opacity: _logoFade,
      child: ScaleTransition(
        scale: _logoScale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // "Bobu"
            Text(
              'Bobu',
              textAlign: TextAlign.center,
              style: GoogleFonts.hurricane(
                fontSize: 118 * scale,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                height: 0.75,
                shadows: [
                  Shadow(
                    color: AppColors.primary.withAlpha(46),
                    offset: Offset(3 * scale, 4 * scale),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),

            // Decorative divider
            Padding(
              padding: EdgeInsets.symmetric(vertical: 5 * scale),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38 * scale,
                    height: 1.4,
                    color: AppColors.pizzaGreen.withAlpha(128),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8 * scale),
                    child: Icon(
                      Icons.local_pizza_outlined,
                      size: 16 * scale,
                      color: AppColors.pizzaGreen.withAlpha(191),
                    ),
                  ),
                  Container(
                    width: 38 * scale,
                    height: 1.4,
                    color: AppColors.pizzaGreen.withAlpha(128),
                  ),
                ],
              ),
            ),

            // "Pizza" + tagline — staggered in
            SlideTransition(
              position: _taglineSlide,
              child: FadeTransition(
                opacity: _taglineFade,
                child: Column(
                  children: [
                    Text(
                      'Pizza',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.italianno(
                        fontSize: 48 * scale,
                        color: AppColors.pizzaGreen,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Text(
                      'AUTHENTIC ITALIAN TASTE',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        fontSize: 10 * scale,
                        color: AppColors.primary.withAlpha(128),
                        letterSpacing: 3.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    // ── Moving Loading Bar here (Away from Pizza) ──
                    SizedBox(height: 32 * scale),
                    _buildLoadingBar(scale),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Pizza image ──────────────────────────────────────────────────

  Widget _buildPizza(double contentWidth) {
    final double pizzaSize = contentWidth * 1.35;

    return SlideTransition(
      position: _pizzaSlide,
      child: FadeTransition(
        opacity: _pizzaFade,
        child: Hero(
          tag: 'pizza_hero',
          child: RotationTransition(
            turns: _rotationController,
            child: Image.asset(
              'assets/images/pizza.png',
              width: pizzaSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  // ── Loading Bar ───────────────────────────────────────────────────

  Widget _buildLoadingBar(double scale) {
    return Container(
      width: 160 * scale,
      height: 4 * scale,
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _dotController,
            builder: (context, child) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _dotController.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withAlpha(150),
                        AppColors.primary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(80),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double sw = size.width;
    final double sh = size.height;
    final double contentWidth = _getContentWidth(sw);
    final double scale = _getScale(sw);

    final double pizzaSize = contentWidth * 1.35;
    final double pizzaVisibleHeight = pizzaSize * 0.30;

    final isDark = ThemeService().isDarkMode;

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
        child: ClipRect(
          child: Center(
            child: SizedBox(
              width: contentWidth,
              height: sh,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [

                  // ── Sauce splash (top-left decoration) ──
                  Positioned(
                    top: -30 * scale,
                    left: -contentWidth * 0.15,
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: Hero(
                        tag: 'sauce_splash',
                        child: Image.asset(
                          'assets/images/splash.png',
                          width: contentWidth * 1.4,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  // ── Logo — perfectly centered ──
                  Positioned(
                    top: (sh / 2) - (pizzaVisibleHeight / 2) - (160 * scale),
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _buildLogo(scale),
                    ),
                  ),

                  // ── Pizza — bottom overflow ──
                  Positioned(
                    bottom: -(pizzaSize / 2) + pizzaVisibleHeight,
                    left: -(pizzaSize - contentWidth) / 2,
                    child: _buildPizza(contentWidth),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
