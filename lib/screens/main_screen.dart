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
  static const double _navBarBottomMargin = 28.0;
  static const double _pillWidth = 68.0;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    final double sw = mq.size.width;
    final double barWidth = sw - (_navBarHorizontalMargin * 2);

    return Scaffold(
      extendBody: true, // tabs render behind navbar → BackdropFilter sees them
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
      // bottomNavigationBar just reserves bottom space + holds the floating UI
      bottomNavigationBar: SizedBox(
        height: _navBarHeight + _navBarBottomMargin + mq.padding.bottom,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Mini cart bar sits above the navbar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildMiniCartBar(),
            ),
            // Liquid glass navbar
            Positioned(
              bottom: _navBarBottomMargin + mq.padding.bottom,
              left: _navBarHorizontalMargin,
              right: _navBarHorizontalMargin,
              height: _navBarHeight,
              child: _buildLiquidGlassNavBar(isDark, barWidth),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIQUID GLASS NAVBAR WIDGET
  //
  // Layer order inside ClipRRect → Stack:
  //   [0] BackdropFilter → transparent SizedBox.expand()  ← MUST be transparent
  //   [1] Tint Container (color + border, NO blur)
  //   [2] Top specular rim (1px gradient)
  //   [3] Animated liquid pill
  //   [4] Icons row
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLiquidGlassNavBar(bool isDark, double barWidth) {
    final double itemWidth = barWidth / _navItems.length;
    const double radius = 44.0;
    final BorderRadius navBr = BorderRadius.circular(radius);

    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: (d) => _onDragUpdate(d, barWidth),
      onHorizontalDragEnd: (d) => _onDragEnd(d, barWidth),
      // ── ClipRRect here is fine because BackdropFilter is INSIDE it ──
      // The clip just shapes the visual output of the whole stack.
      // BackdropFilter's child is transparent → no black offscreen buffer.
      child: ClipRRect(
        borderRadius: navBr,
        child: Stack(
          children: [
            // ── [0] BLUR LAYER — child MUST be transparent ──
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              // DO NOT put any color here. Colors.transparent or SizedBox only.
              child: const SizedBox.expand(),
            ),

            // ── [1] TINT LAYER — separate from blur, sits above ──
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.09)   // dark: subtle white veil
                    : Colors.white.withOpacity(0.52),  // light: frosted milk glass
              ),
            ),

            // ── [2] Border ring (drawn via DecoratedBox, not on Container above) ──
            // Keeping border separate ensures it renders on top of the tint.
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: navBr,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.18)
                      : Colors.white.withOpacity(0.75),
                  width: 0.8,
                ),
              ),
              child: const SizedBox.expand(),
            ),

            // ── [3] Vertical gradient sheen (top bright → bottom dim) ──
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(isDark ? 0.06 : 0.20),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6],
                ),
              ),
            ),

            // ── [4] 1px specular rim at the very top ──
            Positioned(
              top: 0,
              left: 20,
              right: 20,
              height: 1.0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(isDark ? 0.5 : 1.0),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── [5] LIQUID PILL ──
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

            // ── [6] ICONS ──
            Row(
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final bool isSelected = _selectedIndex == index;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onItemTapped(index),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: _navBarHeight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutBack,
                            scale: isSelected ? 1.1 : 1.0,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: Icon(
                                isSelected ? item.activeIcon : item.icon,
                                key: ValueKey('${index}_$isSelected'),
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark
                                        ? Colors.white.withOpacity(0.55)
                                        : Colors.black.withOpacity(0.42)),
                                size: 24,
                              ),
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              style: GoogleFonts.poppins(
                                color: AppColors.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ] else
                            const SizedBox(height: 11),
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
                          color.withOpacity(0.28),
                          color.withOpacity(0.14),
                        ]
                      : [
                          color.withOpacity(0.22),
                          color.withOpacity(0.10),
                        ],
                ),
              ),
            ),

            // Border
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: br,
                border: Border.all(
                  color: color.withOpacity(isDark ? 0.40 : 0.30),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.22),
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
                      Colors.white.withOpacity(isDark ? 0.6 : 0.9),
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
