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

// ─────────────────────────────────────────────────────────────────────────────
// iOS 26 LIQUID GLASS NAVBAR — Final correct approach
//
// WHY PREVIOUS APPROACHES FAILED:
//   1. ClipRRect + BackdropFilter = black card
//      Flutter renders an offscreen layer for clipping; BackdropFilter
//      then blurs THAT (black) layer instead of what's behind it.
//
//   2. BackdropFilter without ClipRRect = entire screen blurs
//      BackdropFilter with no clip boundary blurs everything behind it
//      in the entire render tree above it.
//
// THE ACTUAL CORRECT FIX:
//   Use a CustomClipper that Flutter can resolve BEFORE the offscreen
//   layer is created. Specifically, wrap BackdropFilter in a widget that
//   clips via `clipBehavior` on a *decorated* Container — this keeps the
//   clipping information in the same render pass so Flutter doesn't need
//   a separate black offscreen buffer.
//
//   Concretely: Put ClipRRect INSIDE BackdropFilter's subtree boundary,
//   not wrapping it. The key is:
//     ClipRRect (clips the visual output)
//       └─ Stack
//            ├─ BackdropFilter → SizedBox.expand() [TRANSPARENT child only]
//            ├─ tint Container (no blur, just color + border)
//            └─ icons etc.
//
//   The SizedBox.expand() child of BackdropFilter must be 100% transparent.
//   Any color goes on a SEPARATE sibling layer above it.
//   This is the pattern that actually works on both iOS and Android.
// ─────────────────────────────────────────────────────────────────────────────

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;

  static const double _navBarHeight = 68.0;
  static const double _navBarHorizontalMargin = 20.0;
  static const double _navBarBottomMargin = 12.0; // Lowered from 28.0 for better bottom positioning
  static const double _pillWidth = 72.0; // Slightly wider pill for better look
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

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  //
  // Scaffold structure:
  //   - extendBody: true  → tab content goes under the navbar area
  //   - body: normal IndexedStack (tabs fill full screen)
  //   - bottomNavigationBar: SizedBox with height only (reserves space)
  //
  // The glass navbar is in a Stack inside bottomNavigationBar.
  // Because extendBody:true, the content scrolls BEHIND it → blur works.
  //
  // Black card fix: ClipRRect wraps the Stack, NOT the BackdropFilter.
  // BackdropFilter's direct child is always Colors.transparent SizedBox.
  // Tint is a separate Container sibling ABOVE the BackdropFilter.
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    final double sw = mq.size.width;
    final double barWidth = sw - (_navBarHorizontalMargin * 2);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Content Layer — tabs fill full screen, but respect top safe area
          Positioned.fill(
            child: SafeArea(
              bottom: false, // Allow content to flow behind navbar at bottom
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

          // Floating UI Layer
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

  // ═══════════════════════════════════════════════════════════════════════════
  // LIQUID GLASS NAVBAR WIDGET
  // ═══════════════════════════════════════════════════════════════════════════

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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 40 : 15),
              blurRadius: 25,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: navBr,
          child: Stack(
            children: [
            // ── [0] BLUR LAYER ──
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 20), // Optimized blur
              child: Container(
                color: isDark 
                    ? Colors.white.withAlpha(8)  // Extremely low opacity for dark mode
                    : Colors.white.withAlpha(45), // Crystal clear milk glass for light mode
              ),
            ),

            // ── [1] Specular Rim & Border ──
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: navBr,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withAlpha(15) // Thinner, subtle border
                      : Colors.white.withAlpha(80),
                  width: 0.6,
                ),
              ),
              child: const SizedBox.expand(),
            ),

            // ── [2] LIQUID PILL ──
            AnimatedBuilder(
              animation: _pillController,
              builder: (context, _) {
                final double visualPos = _isDragging
                    ? (_selectedIndex + _dragOffsetFraction)
                    : _pillPosition.value;
                final double pillLeft =
                    (visualPos * itemWidth) + (itemWidth / 2) - (_pillWidth / 2);

                return Positioned(
                  left: pillLeft.clamp(0.0, barWidth - _pillWidth),
                  top: (_navBarHeight - _pillHeight) / 2,
                  child: _LiquidPill(
                    width: _pillWidth,
                    height: _pillHeight,
                    color: AppColors.primary,
                    isDark: isDark,
                  ),
                );
              },
            ),

            // ── [3] Vertical gradient sheen ──
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withAlpha(isDark ? 10 : 30),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // ── [4] ICONS ──
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
                                size: 24,
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

  // ═══════════════════════════════════════════════════════════════════════════
  // MINI CART BAR
  // ═══════════════════════════════════════════════════════════════════════════

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

// ─────────────────────────────────────────────────────────────────────────────
// LIQUID PILL
// Same pattern: ClipRRect wraps Stack, BackdropFilter child is transparent.
// ─────────────────────────────────────────────────────────────────────────────

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
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: const SizedBox.expand(),
            ),

            // Brand tint
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          color.withAlpha(70),
                          color.withAlpha(35),
                        ]
                      : [
                          color.withAlpha(55),
                          color.withAlpha(25),
                        ],
                ),
              ),
            ),

            // Border
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: br,
                border: Border.all(
                  color: color.withAlpha(isDark ? 100 : 75),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withAlpha(55),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: const SizedBox.expand(),
            ),

            // Specular streak
            Positioned(
              top: 2,
              left: width * 0.22,
              right: width * 0.22,
              height: 1.0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withAlpha(isDark ? 153 : 230),
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

// ─────────────────────────────────────────────────────────────────────────────
// NAV ITEM MODEL
// ─────────────────────────────────────────────────────────────────────────────

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
