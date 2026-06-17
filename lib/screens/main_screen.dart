import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
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

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.home_outlined,         activeIcon: Icons.home_rounded,         label: 'Home'),
    _NavItem(icon: Icons.grid_view_outlined,     activeIcon: Icons.grid_view_rounded,    label: 'Menu'),
    _NavItem(icon: Icons.shopping_bag_outlined,  activeIcon: Icons.shopping_bag_rounded, label: 'Cart'),
    _NavItem(icon: Icons.receipt_long_outlined,  activeIcon: Icons.receipt_long_rounded, label: 'Orders'),
    _NavItem(icon: Icons.person_outline,         activeIcon: Icons.person_rounded,       label: 'Profile'),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    HapticFeedback.lightImpact();
  }

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
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
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    // Each slot width = screen width / 5
    final double slotWidth =
        MediaQuery.of(context).size.width / _navItems.length;

    return Container(
      height: _navBarHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D1A0E).withOpacity(0.08),
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
            child: _buildNavItem(i, slotWidth),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, double slotWidth) {
    final item = _navItems[index];
    final bool isSelected = _selectedIndex == index;

    // Pill can never exceed slot width minus a small margin
    final double maxPillWidth = slotWidth - 8;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(maxWidth: maxPillWidth),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon
              AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFF9E9E9E),
                  size: 24, 
                ),
              ),

              const SizedBox(height: 4),

              // Label
              AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.7,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                    color: isSelected ? AppColors.primary : const Color(0xFF9E9E9E),
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    height: 1.0,
                  ),
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