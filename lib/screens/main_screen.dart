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

// ─────────────────────────────────────────────────────────────────────────────
// LIQUID GLASS NAVBAR — iOS 26 inspired
//
// Key techniques used:
//   1. No opaque container behind BackdropFilter → real glass, no black card
//   2. GestureDetector with onHorizontalDragUpdate → drag-to-slide tab switching
//   3. AnimatedPositioned with SpringSimulation physics → liquid pill movement
//   4. Custom painter for the "specular highlight" rim on the pill
//   5. Separate blur layers: bar blur (light) + pill blur (stronger) → depth
// ─────────────────────────────────────────────────────────────────────────────

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  static const double _navBarHeight = 68.0;
  static const double _navBarHorizontalMargin = 20.0;
  static const double _navBarBottomMargin = 30.0;

  // ── Pill animation (spring-like via elasticOut) ──
  late AnimationController _pillController;
  late Animation<double> _pillPosition; // 0.0 → 1.0 mapped to actual x later
  double _pillTarget = 0.0;
  double _pillCurrent = 0.0;

  // ── Drag state ──
  double _dragStartX = 0.0;
  int _dragStartIndex = 0;
  double _dragOffsetFraction = 0.0; // live fractional offset during drag
  bool _isDragging = false;

  // ── Cart bar ──
  late AnimationController _cartBarController;
  late Animation<Offset> _cartBarSlide;
  late Animation<double> _cartBarFade;

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  int _prevItemCount = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.home_outlined,        activeIcon: Icons.home_rounded,          label: 'Home'),
    _NavItem(icon: Icons.grid_view_outlined,   activeIcon: Icons.grid_view_rounded,     label: 'Menu'),
    _NavItem(icon: Icons.shopping_bag_outlined,activeIcon: Icons.shopping_bag_rounded,  label: 'Cart'),
    _NavItem(icon: Icons.receipt_long_outlined,activeIcon: Icons.receipt_long_rounded,  label: 'Orders'),
    _NavItem(icon: Icons.person_outline,       activeIcon: Icons.person_rounded,        label: 'Profile'),
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
    // Pill — drives a 0→1 value that we map to x positions
    _pillController = AnimationController(
      duration: const Duration(milliseconds: 480),
      vsync: this,
    );
    _pillPosition = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _pillController, curve: Curves.elasticOut),
    );

    // Cart bar
    _cartBarController = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );
    _cartBarSlide = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _cartBarController, curve: Curves.easeOutBack));
    _cartBarFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _cartBarController, curve: Curves.easeOut));

    // Pulse
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

  // ── Pill position helper ─────────────────────────────────────────────────

  /// Animates the pill from current index to [newIndex]
  void _animatePillTo(int newIndex) {
    final double from = _pillCurrent;
    final double to = newIndex.toDouble();
    _pillCurrent = to;

    _pillPosition = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: _pillController, curve: Curves.elasticOut),
    );
    _pillController.forward(from: 0);
  }

  // ── Tap & drag ───────────────────────────────────────────────────────────

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
    _dragStartIndex = _selectedIndex;
    _isDragging = true;
    _pillController.stop(); // freeze spring during drag
  }

  void _onDragUpdate(DragUpdateDetails d, double barWidth) {
    if (!_isDragging) return;
    final double itemWidth = barWidth / _navItems.length;
    final double totalDelta = d.localPosition.dx - _dragStartX;
    final double indexDelta = totalDelta / itemWidth;

    setState(() {
      // Pill moves 1:1 with finger — clamped to valid range
      _dragOffsetFraction = (_dragStartIndex + indexDelta)
          .clamp(0.0, _navItems.length - 1.0) - _selectedIndex;
    });
  }

  void _onDragEnd(DragEndDetails d, double barWidth) {
    if (!_isDragging) return;
    _isDragging = false;

    final double itemWidth = barWidth / _navItems.length;
    final double velocity = d.velocity.pixelsPerSecond.dx / itemWidth;
    final double totalDelta = _dragOffsetFraction;

    // Decide target index by position + fling velocity
    int targetIndex = _selectedIndex;
    if (totalDelta.abs() > 0.35 || velocity.abs() > 1.5) {
      targetIndex = (totalDelta + velocity * 0.15 + _selectedIndex)
          .round()
          .clamp(0, _navItems.length - 1);
    }

    // Animate pill to final spot
    _pillCurrent = _selectedIndex + _dragOffsetFraction; // current visual pos
    setState(() => _dragOffsetFraction = 0.0);
    if (targetIndex != _selectedIndex) {
      _onItemTapped(targetIndex);
    } else {
      // Snap back
      _animatePillTo(_selectedIndex);
    }
  }

  // ── Cart listener ────────────────────────────────────────────────────────

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

    return Scaffold(
      extendBody: true,
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
      bottomNavigationBar: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          _buildMiniCartBar(),
          _buildLiquidGlassNavBar(isDark),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIQUID GLASS NAV BAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLiquidGlassNavBar(bool isDark) {
    final double sw = MediaQuery.of(context).size.width;
    final double barWidth = sw - (_navBarHorizontalMargin * 2);
    final double itemWidth = barWidth / _navItems.length;
    final double pillWidth = 66.0;
    final double pillHeight = 46.0;

    return Container(
      height: _navBarHeight,
      margin: EdgeInsets.fromLTRB(
        _navBarHorizontalMargin,
        0,
        _navBarHorizontalMargin,
        _navBarBottomMargin,
      ),
      child: GestureDetector(
        // ── Drag anywhere on the bar to slide tabs ──
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: (d) => _onDragUpdate(d, barWidth),
        onHorizontalDragEnd: (d) => _onDragEnd(d, barWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(44),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Layer 1: Actual background blur (the "glass") ──
              // FIX: We do NOT put any color in the BackdropFilter child —
              // instead we put a thin translucent overlay ABOVE it.
              // This prevents the "black card" artifact.
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: const SizedBox.expand(), // transparent — just captures blur
              ),

              // ── Layer 2: Very thin tinted glass overlay ──
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withAlpha(18)  // ~7% white in dark
                      : Colors.white.withAlpha(60), // ~24% white in light
                  borderRadius: BorderRadius.circular(44),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withAlpha(35)
                        : Colors.white.withAlpha(120),
                    width: 0.8,
                  ),
                ),
              ),

              // ── Layer 3: Specular top highlight (inner glass rim) ──
              // A thin white gradient strip at the very top — this is the key
              // detail that makes it look like real frosted glass.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1.2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withAlpha(0),
                        Colors.white.withAlpha(isDark ? 60 : 160),
                        Colors.white.withAlpha(0),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(44)),
                  ),
                ),
              ),

              // ── Layer 4: Liquid pill (follows drag live) ──
              AnimatedBuilder(
                animation: _pillController,
                builder: (context, _) {
                  // During drag: pill tracks finger directly
                  // After drag: pill spring-animates to target
                  final double effectivePosition = _isDragging
                      ? (_selectedIndex + _dragOffsetFraction)
                      : _pillPosition.value;

                  final double pillLeft =
                      (effectivePosition * itemWidth) +
                          (itemWidth / 2) -
                          (pillWidth / 2);

                  return Positioned(
                    left: pillLeft.clamp(0.0, barWidth - pillWidth),
                    top: (_navBarHeight - pillHeight) / 2,
                    child: _LiquidPill(
                      width: pillWidth,
                      height: pillHeight,
                      color: AppColors.primary,
                      isDark: isDark,
                    ),
                  );
                },
              ),

              // ── Layer 5: Nav icons ──
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
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutBack,
                              scale: isSelected ? 1.12 : 1.0,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  isSelected ? item.activeIcon : item.icon,
                                  key: ValueKey('${index}_$isSelected'),
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isDark
                                      ? Colors.white.withAlpha(140)
                                      : Colors.black.withAlpha(110)),
                                  size: 24,
                                ),
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(height: 2),
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 250),
                                opacity: 1.0,
                                child: Text(
                                  item.label,
                                  style: GoogleFonts.poppins(
                                    color: AppColors.primary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ] else
                              const SizedBox(height: 11), // keep icon vertically stable
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
  // MINI CART BAR  (unchanged logic, cosmetic polish)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMiniCartBar() {
    return ValueListenableBuilder(
      valueListenable: CartService.cartItemsNotifier,
      builder: (context, items, child) {
        if (items.isEmpty || _selectedIndex == 2) return const SizedBox.shrink();
        final int totalItems =
        items.fold<int>(0, (sum, item) => sum + item.quantity);

        return Padding(
          padding: const EdgeInsets.only(
            bottom: _navBarHeight + _navBarBottomMargin + 8,
          ),
          child: SlideTransition(
            position: _cartBarSlide,
            child: FadeTransition(
              opacity: _cartBarFade,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withAlpha(200),
                    ],
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
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
                            child: const Icon(
                              Icons.shopping_bag_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          '$totalItems item${totalItems > 1 ? 's' : ''} in cart',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 14,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// LIQUID PILL WIDGET
// A frosted glass capsule with:
//   • its own stronger BackdropFilter (gives depth vs the bar blur)
//   • specular highlight rim
//   • subtle inner glow in the brand color
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
      child: ClipRRect(
        borderRadius: br,
        child: Stack(
          children: [
            // ── Stronger blur just inside the pill → depth ──
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: const SizedBox.expand(),
            ),

            // ── Tinted fill: brand color at low alpha + white bleed ──
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withAlpha(isDark ? 55 : 45),
                    color.withAlpha(isDark ? 35 : 28),
                  ],
                ),
                borderRadius: br,
                border: Border.all(
                  color: color.withAlpha(isDark ? 80 : 65),
                  width: 0.8,
                ),
                boxShadow: [
                  // Outer glow
                  BoxShadow(
                    color: color.withAlpha(isDark ? 55 : 45),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                  // Inner white highlight (simulated via a white shadow)
                  BoxShadow(
                    color: Colors.white.withAlpha(isDark ? 15 : 30),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),

            // ── Top specular highlight streak ──
            Positioned(
              top: 1,
              left: width * 0.2,
              right: width * 0.2,
              height: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withAlpha(0),
                      Colors.white.withAlpha(isDark ? 80 : 140),
                      Colors.white.withAlpha(0),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(1),
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