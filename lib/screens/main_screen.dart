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
// iOS 26 LIQUID GLASS NAVBAR — Correct Implementation
//
// THE BLACK CARD FIX:
//   ClipRRect wrapping BackdropFilter = black card. Always.
//   Flutter creates an offscreen layer for clipping, and BackdropFilter
//   blurs that layer (which is black/transparent) instead of what's behind it.
//
//   CORRECT APPROACH:
//   - Scaffold uses Stack as body, NOT bottomNavigationBar
//   - Navbar floats INSIDE the body stack as a Positioned widget
//   - BackdropFilter clips itself using its child's borderRadius (no ClipRRect)
//   - This way blur captures the actual scrolling content behind it
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

  // ── Pill spring animation ──
  late AnimationController _pillController;
  late Animation<double> _pillPosition;
  double _pillCurrent = 0.0;

  // ── Drag state ──
  double _dragStartX = 0.0;
  double _dragOffsetFraction = 0.0;
  bool _isDragging = false;

  // ── Cart bar ──
  late AnimationController _cartBarController;
  late Animation<Offset> _cartBarSlide;
  late Animation<double> _cartBarFade;

  // ── Cart pulse ──
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
      _dragOffsetFraction = (_selectedIndex + indexDelta)
              .clamp(0.0, _navItems.length - 1.0) -
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
  // KEY CHANGE: Scaffold has NO bottomNavigationBar.
  // Instead, body is a Stack with the tab content + floating navbar on top.
  // This is the ONLY way BackdropFilter correctly blurs the scrolling content.
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double sw = MediaQuery.of(context).size.width;
    final double barWidth = sw - (_navBarHorizontalMargin * 2);

    return Scaffold(
      // NO extendBody, NO bottomNavigationBar
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ── Tab content (fills entire screen including where navbar is) ──
          IndexedStack(
            index: _selectedIndex,
            children: const [
              HomeTab(),
              MenuTab(),
              CartTab(),
              OrdersTab(),
              ProfileTab(),
            ],
          ),

          // ── Mini cart bar (floats above navbar) ──
          Positioned(
            left: 0,
            right: 0,
            bottom: _navBarHeight + _navBarBottomMargin + 8,
            child: _buildMiniCartBar(),
          ),

          // ── LIQUID GLASS NAV BAR (floats over content) ──
          Positioned(
            left: _navBarHorizontalMargin,
            right: _navBarHorizontalMargin,
            bottom: _navBarBottomMargin,
            height: _navBarHeight,
            child: _buildLiquidGlassNavBar(isDark, barWidth),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIQUID GLASS NAV BAR
  //
  // Structure (no ClipRRect anywhere!):
  //   GestureDetector
  //   └─ Stack
  //      ├─ BackdropFilter (blur) → child has borderRadius decoration
  //      ├─ Glass tint overlay    → borderRadius decoration  
  //      ├─ Top specular rim      → Positioned, 1px tall
  //      ├─ Animated liquid pill  → AnimatedBuilder + Positioned
  //      └─ Row of icon buttons
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLiquidGlassNavBar(bool isDark, double barWidth) {
    final double itemWidth = barWidth / _navItems.length;
    final BorderRadius navBr = BorderRadius.circular(44);

    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: (d) => _onDragUpdate(d, barWidth),
      onHorizontalDragEnd: (d) => _onDragEnd(d, barWidth),
      child: Stack(
        children: [
          // ── LAYER 1: BackdropFilter — NO ClipRRect wrapper ──
          // The trick: give the child Container a borderRadius.
          // The blur itself doesn't get clipped (so no black), but the
          // visual tint container has rounded corners.
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              decoration: BoxDecoration(
                // ── LIGHT MODE: slightly warm tinted glass ──
                // ── DARK MODE: very faint white glass ──
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.white.withOpacity(0.55),
                borderRadius: navBr,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.15)
                      : Colors.white.withOpacity(0.7),
                  width: 0.8,
                ),
              ),
            ),
          ),

          // ── LAYER 2: Subtle inner shadow (depth on glass edges) ──
          Container(
            decoration: BoxDecoration(
              borderRadius: navBr,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(isDark ? 0.05 : 0.18),
                  Colors.transparent,
                  Colors.black.withOpacity(isDark ? 0.08 : 0.03),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ── LAYER 3: 1px specular rim at very top of bar ──
          Positioned(
            top: 0,
            left: 16,
            right: 16,
            height: 1.0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withOpacity(isDark ? 0.4 : 0.9),
                    Colors.transparent,
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(44)),
              ),
            ),
          ),

          // ── LAYER 4: Liquid pill (animated, drag-following) ──
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

          // ── LAYER 5: Nav icons + labels ──
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
                                      : Colors.black.withOpacity(0.45)),
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
                  )
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
// Also uses NO ClipRRect — same technique as the navbar.
// BackdropFilter child has borderRadius on the decoration.
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

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          // ── Pill blur (stronger than bar = depth layering) ──
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              decoration: BoxDecoration(
                // Light mode: warm tinted glass pill
                // Dark mode: faint brand-tinted glass
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          color.withOpacity(0.22),
                          color.withOpacity(0.12),
                        ]
                      : [
                          color.withOpacity(0.18),
                          Colors.white.withOpacity(0.12),
                          color.withOpacity(0.10),
                        ],
                ),
                borderRadius: br,
                border: Border.all(
                  color: color.withOpacity(isDark ? 0.35 : 0.28),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(isDark ? 0.25 : 0.20),
                    blurRadius: 14,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),

          // ── Pill top specular streak ──
          Positioned(
            top: 1.5,
            left: width * 0.25,
            right: width * 0.25,
            height: 1.0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withOpacity(isDark ? 0.55 : 0.85),
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
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
