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

  static const double _navBarHeight = 72.0;

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

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    // Cart bar slide + fade
    _cartBarController = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );
    _cartBarSlide = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cartBarController,
      curve: Curves.easeOutBack,
    ));
    _cartBarFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cartBarController, curve: Curves.easeOut),
    );

    // Pulse on item add
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
    ]).animate(_pulseController);

    CartService.cartItemsNotifier.addListener(_onCartChanged);
    CartService.fetchCartFromDb();
  }

  void _onCartChanged() {
    final items = CartService.cartItemsNotifier.value;
    final int newCount =
    items.fold<int>(0, (sum, item) => sum + item.quantity);
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
    HapticFeedback.lightImpact();

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

    // Update status bar brightness based on theme
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMiniCartBar(),
          _buildNavBar(isDark),
        ],
      ),
    );
  }

  // ─── Mini cart bar ────────────────────────────────────────────────

  Widget _buildMiniCartBar() {
    return ValueListenableBuilder(
      valueListenable: CartService.cartItemsNotifier,
      builder: (context, items, child) {
        if (items.isEmpty || _selectedIndex == 2) {
          return const SizedBox.shrink();
        }

        final int totalItems =
        items.fold<int>(0, (sum, item) => sum + item.quantity);

        return SlideTransition(
          position: _cartBarSlide,
          child: FadeTransition(
            opacity: _cartBarFade,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.primary,
                    Color.fromARGB(
                      255,
                      (AppColors.primary.red + 30).clamp(0, 255),
                      AppColors.primary.green,
                      AppColors.primary.blue,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _onItemTapped(2),
                  borderRadius: BorderRadius.circular(18),
                  splashColor: Colors.white.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    child: Row(
                      children: [

                        // Pulsing cart icon
                        ScaleTransition(
                          scale: _pulseScale,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shopping_bag_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Item count text
                        Text(
                          '$totalItems item${totalItems > 1 ? 's' : ''} in cart',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const Spacer(),

                        // View Cart CTA pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View Cart',
                                style: GoogleFonts.poppins(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: AppColors.primary,
                                size: 10,
                              ),
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

  // ─── Nav bar ──────────────────────────────────────────────────────

  Widget _buildNavBar(bool isDark) {
    final double slotWidth =
        MediaQuery.of(context).size.width / _navItems.length;

    return SizedBox(
      height: _navBarHeight,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : const Color(0xFF2D1A0E).withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: List.generate(
            _navItems.length,
                (i) => SizedBox(
              width: slotWidth,
              height: _navBarHeight,
              child: _buildNavItem(i, slotWidth, isDark),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Nav item ─────────────────────────────────────────────────────

  Widget _buildNavItem(int index, double slotWidth, bool isDark) {
    final item = _navItems[index];
    final bool isSelected = _selectedIndex == index;
    final double maxPillWidth = slotWidth - 8;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: SizedBox(
          width: maxPillWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              // Icon
              AnimatedScale(
                scale: isSelected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.white24 : const Color(0xFF9E9E9E)),
                  size: 24,
                ),
              ),

              const SizedBox(height: 4),

              // Label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.poppins(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.white24 : const Color(0xFF9E9E9E)),
                  fontSize: 10,
                  fontWeight: isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  height: 1.0,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  textAlign: TextAlign.center,
                ),
              ),

              // ✅ Active dot — AnimatedSize, no negative constraints
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                clipBehavior: Clip.none,
                child: SizedBox(
                  width: isSelected ? 16 : 0,
                  height: isSelected ? 7 : 0,
                  child: isSelected
                      ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  )
                      : null,
                ),
              ),
            ],
          ),
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