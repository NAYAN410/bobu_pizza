import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _rotationController;
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      'title': 'Choose Your Pizza',
      'description': 'Select from our wide variety of delicious pizzas made with fresh ingredients.',
    },
    {
      'title': 'Fast Delivery',
      'description': 'We deliver your favorite pizza hot and fresh to your doorstep as quickly as possible.',
    },
    {
      'title': 'Easy Payment',
      'description': 'Pay easily with multiple payment options available in the app.',
    },
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, 
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
        
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_time', false);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final double contentWidth = screenWidth > 500 ? 500 : screenWidth;
    final double scale = contentWidth / 375;
    final pizzaSize = contentWidth * 0.9;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -30 * scale,
                left: -10 * scale,
                child: Hero(
                  tag: 'sauce_splash',
                  child: Image.asset(
                    'assets/images/splash.png',
                    width: contentWidth * 1.5,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              
              Positioned(
                right: -pizzaSize / 2,
                top: (screenHeight - pizzaSize) / 2,
                child: Hero(
                  tag: 'pizza_hero',
                  createRectTween: (begin, end) => MaterialRectArcTween(begin: begin, end: end),
                  child: RotationTransition(
                    turns: _rotationController,
                    child: Image.asset(
                      'assets/images/pizza.png',
                      width: pizzaSize,
                      height: pizzaSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: TextButton(
                          onPressed: _completeOnboarding,
                          child: Text(
                            'Skip',
                            style: GoogleFonts.poppins(
                              fontSize: 14 * scale,
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) => setState(() => _currentPage = index),
                        itemCount: _onboardingData.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.symmetric(horizontal: 30.0 * scale),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: contentWidth * 0.55,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _onboardingData[index]['title']!,
                                        style: GoogleFonts.poppins(
                                          fontSize: 32 * scale,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.textBlack,
                                          height: 1.1,
                                        ),
                                      ),
                                      SizedBox(height: 20 * scale),
                                      Text(
                                        _onboardingData[index]['description']!,
                                        style: GoogleFonts.poppins(
                                          fontSize: 16 * scale,
                                          color: AppColors.textGrey,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _onboardingData.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: _currentPage == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index ? AppColors.primary : AppColors.primary.withAlpha(40),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 40 * scale),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 30 * scale),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56 * scale,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_currentPage == _onboardingData.length - 1) {
                              _completeOnboarding();
                            } else {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeInOutCubic,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            _currentPage == _onboardingData.length - 1 ? 'Get Started' : 'Next',
                            style: GoogleFonts.poppins(fontSize: 18 * scale, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 40 * scale),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
