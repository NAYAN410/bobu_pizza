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

  static const double _navBarHeight = 68.0;
  static const double _navBarHorizontalMargin = 20.0;
  static const double _navBarBottomMargin = 12.0;
  static const double _pillHeight = 46.0;

  late AnimationController _pillController;
  late Animation<double> _pillPosition;
  double _pillCurrent = 0.0;

  double _dragStartX = 0.0;
  double _dragOffsetFraction = 0.0;
  bool _isDragging = false;

  late AnimationController _cartBarController;
  late Animation<Offset> _cartBarSlide;
  late Animation<double> _cartBarFade;

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  int _prevItemCount = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.home_outlined,         activeIcon: Icons.home_rounded,         label: 'Home'),
    _NavItem(icon: Icons.grid_view_outlined,    activeIcon: Icons.grid_view_rounded,    label: 'Menu'),
    _NavItem(icon: Icons.shopping_bag_outlined, activeIcon: Icons.shopping_bag_rounded, label: 'Cart'),
    _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'Orders'),
    _NavItem(icon: Icons.person_outline,        activeIcon: Icons.person_rounded,       label: 'Profile'),
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
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  void _initAnimations() {
    _pillController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _pillPosition = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _pillController, curve: Curves.elasticOut),
    );

    _cartBarController = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );
    _cartBarSlide = Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cartBarController, curve: Curves.easeOutBack));
    _cartBarFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _cartBarController, curve: Curves.easeOut));

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.35).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
    ]).animate(_pulseController);
  }

  void _animatePillTo(int newIndex) {
    final double from = _pillCurrent;
    _pillCurrent = newIndex.toDouble();
    _pillPosition = Tween<double>(begin: from, end: _pillCurrent).animate(
      CurvedAnimation(parent: _pillController, curve: Curves.elasticOut),
    );
    _pillController.forward(from: 0);
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    HapticFeedback.selectionClick();
    _animatePillTo(index);
    setState(() {
      _selectedIndex = index;
      _dragOffsetFraction = 0.0;
    });
    final items = CartService.cartItemsNotifier.value;
    if (index == 2) {
      _cartBarController.reverse();
    } else if (items.isNotEmpty) {
      _cartBarController.forward();
    }
  }

  void _onDragStart(DragStartDetails d) {
    _dragStartX = d.localPosition.dx;
    _isDragging = true;
    _pillController.stop();
  }

  void _onDragUpdate(DragUpdateDetails d, double barWidth) {
    if (!_isDragging) return;
    final double itemWidth = barWidth / _navItems.length;
    final double indexDelta = (d.localPosition.dx - _dragStartX) / itemWidth;
    setState(() {
      _dragOffsetFraction =
          (_selectedIndex + indexDelta).clamp(0.0, _navItems.length - 1.0) -
              _selectedIndex;
    });
  }

  void _onDragEnd(DragEndDetails d, double barWidth) {
    if (!_isDragging) return;
    _isDragging = false;

    final double itemWidth = barWidth / _navItems.length;
    final double velocity = d.velocity.pixelsPerSecond.dx / itemWidth;

    int targetIndex = _selectedIndex;
    if (_dragOffsetFraction.abs() > 0.35 || velocity.abs() > 1.5) {
      targetIndex = (_dragOffsetFraction + velocity * 0.15 + _selectedIndex)
          .round()
          .clamp(0, _navItems.length - 1);
    }

    _pillCurrent = _selectedIndex + _dragOffsetFraction;
    setState(() => _dragOffsetFraction = 0.0);

    if (targetIndex != _selectedIndex) {
      _onItemTapped(targetIndex);
    } else {
      _animatePillTo(_selectedIndex);
    }
  }

  void _onCartChanged() {
    final items = CartService.cartItemsNotifier.value;
    final int newCount = items.fold<int>(0, (sum, i) => sum + i.quantity);
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

  @override
  void dispose() {
    CartService.cartItemsNotifier.removeListener(_onCartChanged);
    _pillController.dispose();
    _cartBarController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    final double sw = mq.size.width;
    final double barWidth = sw - (_navBarHorizontalMargin * 2);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: IndexedStack(
                index: _selectedIndex,
                children: const [
                  HomeTab(),
                  MenuTab(),
                  CartTab(),
                  OrdersTab(),
                  ProfileTab(),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: mq.padding.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMiniCartBar(),
                  const SizedBox(height: 10),
                  _buildLiquidGlassNavBar(isDark, barWidth),
                  const SizedBox(height: _navBarBottomMargin),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiquidGlassNavBar(bool isDark, double barWidth) {
    final double itemWidth = barWidth / _navItems.length;
    const double radius = 44.0;
    final BorderRadius navBr = BorderRadius.circular(radius);

    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: (d) => _onDragUpdate(d, barWidth),
      onHorizontalDragEnd: (d) => _onDragEnd(d, barWidth),
      child: Container(
        height: _navBarHeight,
        margin: const EdgeInsets.symmetric(horizontal: _navBarHorizontalMargin),
        decoration: BoxDecoration(
          borderRadius: navBr,
          // Outer shadow gives floating feel without any card look
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 50 : 20),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: navBr,
          child: Stack(
            children: [
              // ── [0] BLUR ONLY — child is 100% transparent ──
              // This is the only correct way. Any color here = opaque glass.
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: const SizedBox.expand(), // ← TRANSPARENT, NO COLOR
              ),

              // ── [1] TINT — separate layer, ultra low opacity ──
              // Light mode: just a whisper of white so icons are readable
              // Dark mode: even less — almost nothing
              Container(
                color: isDark
                    ? Colors.white.withAlpha(12)  // ~5%
                    : Colors.white.withAlpha(20), // ~8% — crystal clear
              ),

              // ── [2] Border only ──
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: navBr,
                  border: Border.all(
                    color: AppColors.primary.withAlpha(120), // Added red border
                    width: 1.2,
                  ),
                ),
                child: const SizedBox.expand(),
              ),

              // ── [3] Liquid pill ──
              AnimatedBuilder(
                animation: _pillController,
                builder: (context, _) {
                  final double visualPos = _isDragging
                      ? (_selectedIndex + _dragOffsetFraction)
                      : _pillPosition.value;
                  final double pillLeft = visualPos * itemWidth;

                  return Positioned(
                    left: pillLeft.clamp(0.0, barWidth - itemWidth),
                    top: (_navBarHeight - _pillHeight) / 2,
                    child: _LiquidPill(
                      width: itemWidth,
                      height: _pillHeight,
                      color: AppColors.primary,
                      isDark: isDark,
                    ),
                  );
                },
              ),

              // ── [4] Icons ──
              Row(
                children: List.generate(_navItems.length, (index) {
                  final item = _navItems[index];
                  final bool isSelected = _selectedIndex == index;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onItemTapped(index),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutBack,
                              scale: isSelected ? 1.1 : 1.0,
                              child: Icon(
                                isSelected ? item.activeIcon : item.icon,
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark
                                        ? Colors.white.withAlpha(140)
                                        : Colors.black.withAlpha(110)),
                                size: 26,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.label,
                                style: GoogleFonts.poppins(
                                  color: AppColors.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniCartBar() {
    return ValueListenableBuilder(
      valueListenable: CartService.cartItemsNotifier,
      builder: (context, items, _) {
        if (items.isEmpty || _selectedIndex == 2) return const SizedBox.shrink();
        final int total = items.fold<int>(0, (s, i) => s + i.quantity);

        return SlideTransition(
          position: _cartBarSlide,
          child: FadeTransition(
            opacity: _cartBarFade,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withAlpha(200)],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(70),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () => _onItemTapped(2),
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(
                    children: [
                      ScaleTransition(
                        scale: _pulseScale,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(40),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shopping_bag_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '$total item${total > 1 ? 's' : ''} in cart',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LiquidPill extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final bool isDark;

  const _LiquidPill({
    required this.width,
    required this.height,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(height / 2);

    return ClipRRect(
      borderRadius: br,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            // Blur — transparent child
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: const SizedBox.expand(),
            ),

            // Brand tint — low opacity so pill is glassy not filled
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          color.withAlpha(60),
                          color.withAlpha(30),
                        ]
                      : [
                          color.withAlpha(45),
                          color.withAlpha(20),
                        ],
                ),
              ),
            ),

            // Border
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: br,
                border: Border.all(
                  color: color.withAlpha(isDark ? 90 : 65),
                  width: 0.8,
                ),
              ),
              child: const SizedBox.expand(),
            ),

            // Top specular streak
            Positioned(
              top: 2,
              left: width * 0.25,
              right: width * 0.25,
              height: 1.0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withAlpha(isDark ? 140 : 210),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
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

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
