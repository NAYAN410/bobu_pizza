import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../services/cart_service.dart';
import 'tabs/home_tab.dart';
import 'tabs/menu_tab.dart';
import 'tabs/cart_tab.dart';
import 'tabs/orders_tab.dart';
import 'tabs/profile_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  static const double _navBarHeight = 75.0;

  late AnimationController _cartBarController;
  late Animation<Offset> _cartBarSlide;
  late Animation<double> _cartBarFade;

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  int _prevItemCount = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'Menu'),
    _NavItem(icon: Icons.shopping_bag_outlined, activeIcon: Icons.shopping_bag_rounded, label: 'Cart'),
    _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'Orders'),
    _NavItem(icon: Icons.person_outline, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _setupSystemUI();
    _initAnimations();
    CartService.cartItemsNotifier.addListener(_onCartChanged);
    CartService.fetchCartFromDb();
  }

  void _setupSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  void _initAnimations() {
    _cartBarController = AnimationController(duration: const Duration(milliseconds: 420), vsync: this);
    _cartBarSlide = Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cartBarController, curve: Curves.easeOutBack));
    _cartBarFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _cartBarController, curve: Curves.easeOut));

    _pulseController = AnimationController(duration: const Duration(milliseconds: 350), vsync: this);
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 60),
    ]).animate(_pulseController);
  }

  void _onCartChanged() {
    final items = CartService.cartItemsNotifier.value;
    final int newCount = items.fold<int>(0, (sum, item) => sum + item.quantity);
    final bool shouldShow = items.isNotEmpty && _selectedIndex != 2;

    if (shouldShow && !_cartBarController.isCompleted) {
      _cartBarController.forward();
    } else if (!shouldShow && _cartBarController.isCompleted) {
      _cartBarController.reverse();
    }

    if (newCount > _prevItemCount && shouldShow) {
      _pulseController.forward(from: 0);
    }
    _prevItemCount = newCount;
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    HapticFeedback.mediumImpact();

    final items = CartService.cartItemsNotifier.value;
    if (index == 2) {
      _cartBarController.reverse();
    } else if (items.isNotEmpty) {
      _cartBarController.forward();
    }
  }

  @override
  void dispose() {
    CartService.cartItemsNotifier.removeListener(_onCartChanged);
    _cartBarController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBody: true, // Required for glass effect to show content behind
      backgroundColor: theme.scaffoldBackgroundColor,
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          HomeTab(),
          MenuTab(),
          CartTab(),
          OrdersTab(),
          ProfileTab(),
        ],
      ),
      bottomNavigationBar: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          _buildMiniCartBar(),
          _buildLiquidNavBar(isDark),
        ],
      ),
    );
  }

  Widget _buildMiniCartBar() {
    return ValueListenableBuilder(
      valueListenable: CartService.cartItemsNotifier,
      builder: (context, items, child) {
        if (items.isEmpty || _selectedIndex == 2) return const SizedBox.shrink();
        final int totalItems = items.fold<int>(0, (sum, item) => sum + item.quantity);

        return Padding(
          padding: const EdgeInsets.only(bottom: _navBarHeight + 15),
          child: SlideTransition(
            position: _cartBarSlide,
            child: FadeTransition(
              opacity: _cartBarFade,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withAlpha(200)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: InkWell(
                  onTap: () => _onItemTapped(2),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        ScaleTransition(
                          scale: _pulseScale,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withAlpha(40), shape: BoxShape.circle),
                            child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('$totalItems item${totalItems > 1 ? 's' : ''} in cart',
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              Text('View Cart', style: GoogleFonts.poppins(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiquidNavBar(bool isDark) {
    final double sw = MediaQuery.of(context).size.width;
    final double itemWidth = sw / _navItems.length;
    final bool isIOS = Platform.isIOS;

    return Container(
      height: _navBarHeight + 20,
      width: sw,
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 15),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            // Background Layer
            if (isIOS)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withAlpha(180) : Colors.white.withAlpha(180),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withAlpha(isDark ? 20 : 80), width: 1),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 50 : 20), blurRadius: 20, offset: const Offset(0, 4))],
                ),
              ),

            // Liquid Moving Indicator
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              left: (_selectedIndex * itemWidth) + (itemWidth / 2) - 30 - 10,
              top: 10,
              child: Container(
                width: 60,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(isIOS ? 30 : 20),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),

            // Navigation Items
            Row(
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final bool isSelected = _selectedIndex == index;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onItemTapped(index),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            isSelected ? item.activeIcon : item.icon,
                            color: isSelected ? AppColors.primary : (isDark ? Colors.white38 : Colors.grey[400]),
                            size: 24,
                          ),
                        ),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: isSelected ? 1.0 : 0.0,
                          child: Text(
                            item.label,
                            style: GoogleFonts.poppins(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}
