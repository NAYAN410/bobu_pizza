import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../services/supabase_service.dart';
import '../../models/pizza_model.dart';
import '../../models/category_model.dart';
import '../../models/banner_model.dart';
import '../../services/cart_service.dart';
import '../../services/location_service.dart';
import '../main_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final PageController _bannerController = PageController();
  final TextEditingController _searchController = TextEditingController();
  int _currentBanner = 0;
  Timer? _bannerTimer;

  List<BannerModel> _banners = [];
  List<CategoryModel> _categories = [];
  List<Pizza> _popularPizzas = [];
  Map<String, dynamic>? _lastDeliveredOrder;
  String _currentAddress = "Fetching location...";
  bool _isLoading = true;
  int _activeCategoryIndex = 0;

  // Search state
  List<Pizza> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    _fetchLocation(); // Start fetching location in parallel
    try {
      final results = await Future.wait([
        SupabaseService.getBanners(),
        SupabaseService.getCategories(),
        SupabaseService.getPopularPizzas(),
        SupabaseService.getUserOrders(),
      ]);

      if (mounted) {
        setState(() {
          _banners = (results[0] as List).map((e) => BannerModel.fromJson(e)).toList();
          _categories = (results[1] as List).map((e) => CategoryModel.fromJson(e)).toList();
          _popularPizzas = (results[2] as List).map((e) => Pizza.fromJson(e)).toList();
          
          final orders = results[3] as List<Map<String, dynamic>>;
          _lastDeliveredOrder = orders.firstWhere(
            (o) => o['status'].toString().toLowerCase() == 'delivered',
            orElse: () => {},
          );
          if (_lastDeliveredOrder!.isEmpty) _lastDeliveredOrder = null;

          _isLoading = false;
        });
        _startBannerTimer();
      }
    } catch (e) {
      debugPrint('Error loading home data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchLocation() async {
    try {
      final address = await LocationService.getCurrentAddress();
      if (mounted) {
        setState(() {
          _currentAddress = address;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress = "Location error";
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        return;
      }

      setState(() => _isSearching = true);
      try {
        final data = await SupabaseService.searchPizzas(query);
        if (mounted) {
          setState(() {
            _searchResults = data.map((e) => Pizza.fromJson(e)).toList();
            _isSearching = false;
          });
        }
      } catch (e) {
        debugPrint('Search error: $e');
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    if (_banners.length <= 1) return;
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_bannerController.hasClients) return;
      final next = (_currentBanner + 1) % _banners.length;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning ☀️';
    if (hour < 17) return 'Good Afternoon 🌤️';
    if (hour < 21) return 'Good Evening 🌇';
    return 'Good Night 🌙';
  }

  void _showTopSnackBar(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _TopSnackBarWidget(
        message: message,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final double contentWidth = sw.clamp(0.0, 500.0);
    final double scale = (contentWidth / 375).clamp(0.85, 1.15);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: AppColors.primary,
      child: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(scale, isDark),
                _buildSearchBar(scale, isDark),
                if (_banners.isNotEmpty) _buildBannerCarousel(scale, contentWidth),
                
                // ── Cafe Timing Indicator ──
                _buildCafeTimingIndicator(scale, isDark),
                
                if (_lastDeliveredOrder != null) ...[
                  _buildSectionHeaderWithAction('Recent Order', 'See all', scale, isDark, () {
                    MainScreen.of(context)?.setIndex(3);
                  }),
                  _buildLastOrderCard(_lastDeliveredOrder!, scale, isDark),
                ],

                _buildSectionHeader('Popular Pizzas', scale, isDark),
                if (_popularPizzas.isNotEmpty) _buildVerticalPizzaList(scale, isDark),
                SizedBox(height: 120 * scale), // Space for floating nav bar
              ],
            ),
          ),
          
          // Search Overlay
          if (_searchController.text.isNotEmpty)
            _buildSearchOverlay(scale, isDark),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────

  Widget _buildHeader(double scale, bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20 * scale, 16 * scale, 20 * scale, 8 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, 
                      color: AppColors.primary, 
                      size: 14 * scale
                    ),
                    SizedBox(width: 4 * scale),
                    Expanded(
                      child: Text(
                        _currentAddress,
                        style: GoogleFonts.poppins(
                          fontSize: 11 * scale,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8 * scale),
                Text(_getGreeting(),
                  style: GoogleFonts.poppins(fontSize: 13 * scale, color: isDark ? Colors.white38 : const Color(0xFF2D1A0E).withAlpha(128), fontWeight: FontWeight.w500)),
                SizedBox(height: 2 * scale),
                Text('What\'s your craving?',
                  style: GoogleFonts.poppins(fontSize: 20 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF2D1A0E))),
              ],
            ),
          ),
          Stack(
            children: [
              Container(
                padding: EdgeInsets.all(10 * scale),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(13) : Colors.white, 
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8D5C0), width: 1.2),
                  boxShadow: isDark ? [] : [BoxShadow(color: const Color(0xFF2D1A0E).withAlpha(15), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Icon(Icons.notifications_none_outlined, color: isDark ? Colors.white70 : const Color(0xFF2D1A0E), size: 22 * scale),
              ),
              Positioned(
                right: 9, top: 9,
                child: Container(
                  height: 9, width: 9,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Search bar ───────────────────────────────────────────────────

  Widget _buildSearchBar(double scale, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 10 * scale),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 54 * scale,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(13) : Colors.white.withAlpha(180), 
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8D5C0), width: 1.2),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black, fontSize: 14 * scale),
              decoration: InputDecoration(
                hintText: 'Search pizzas...',
                hintStyle: GoogleFonts.poppins(color: isDark ? Colors.white24 : Colors.grey[600], fontSize: 13 * scale),
                prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white24 : AppColors.primary, size: 22 * scale),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, size: 20 * scale, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : Icon(Icons.tune_rounded, color: AppColors.primary, size: 20 * scale),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16 * scale),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchOverlay(double scale, bool isDark) {
    return Positioned(
      top: 130 * scale, // Adjust based on your header + search bar height
      left: 20 * scale,
      right: 20 * scale,
      bottom: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withAlpha(200) : Colors.white.withAlpha(230),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8D5C0)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: _isSearching 
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _searchResults.isEmpty 
                  ? Center(child: Text('No pizzas found', style: GoogleFonts.poppins(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final pizza = _searchResults[index];
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            onTap: () {
                              _searchController.clear();
                              _onSearchChanged('');
                              _showPizzaDetails(context, pizza, scale, isDark);
                            },
                            leading: Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                              child: Image.network(pizza.imageUrl, errorBuilder: (_, __, ___) => Image.asset('assets/images/pizza.png')),
                            ),
                            title: Text(pizza.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                            subtitle: Text('₹${pizza.discountedPrice.toInt()}', style: GoogleFonts.poppins(color: AppColors.primary, fontWeight: FontWeight.w600)),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                          ),
                        );
                      },
                    ),
          ),
        ),
      ),
    );
  }

  // ─── Banner carousel ──────────────────────────────────────────────

  Widget _buildBannerCarousel(double scale, double contentWidth) {
    return Column(
      children: [
        SizedBox(
          height: 165 * scale,
          child: PageView.builder(
            controller: _bannerController,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _currentBanner = i),
            itemBuilder: (context, index) => _buildBannerCard(_banners[index], scale, contentWidth),
          ),
        ),
        SizedBox(height: 12 * scale),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (i) {
            final isActive = i == _currentBanner;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic,
              margin: EdgeInsets.symmetric(horizontal: 3 * scale),
              width: isActive ? 20 * scale : 6 * scale, height: 6 * scale,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.primary.withAlpha(64),
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildBannerCard(BannerModel b, double scale, double contentWidth) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20 * scale),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: b.imageUrl.startsWith('http')
            ? Image.network(
                b.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => _buildPlaceholderBanner(scale),
              )
            : Image.asset(
                'assets/images/pizza.png', 
                fit: BoxFit.cover,
                width: double.infinity,
              ),
      ),
    );
  }

  Widget _buildPlaceholderBanner(double scale) {
    return Container(
      color: AppColors.primary,
      child: Center(
        child: Icon(Icons.image_outlined, color: Colors.white.withAlpha(128), size: 50 * scale),
      ),
    );
  }

  Widget _buildSectionHeader(String title, double scale, bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20 * scale, 20 * scale, 20 * scale, 12 * scale),
      child: Text(title, style: GoogleFonts.poppins(fontSize: 17 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF2D1A0E))),
    );
  }

  Widget _buildSectionHeaderWithAction(String title, String action, double scale, bool isDark, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20 * scale, 20 * scale, 20 * scale, 12 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 17 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF2D1A0E))),
          GestureDetector(
            onTap: onTap,
            child: Text(action, style: GoogleFonts.poppins(fontSize: 13 * scale, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildLastOrderCard(Map<String, dynamic> order, double scale, bool isDark) {
    final items = order['order_items'] as List;
    final firstItem = items.isNotEmpty ? items[0]['pizzas'] : null;
    
    return GestureDetector(
      onTap: () => MainScreen.of(context)?.setIndex(3),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20 * scale),
        padding: EdgeInsets.all(16 * scale),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(13) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8D5C0)),
          boxShadow: isDark ? [] : [
            BoxShadow(
              color: const Color(0xFF2D1A0E).withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50 * scale,
              height: 50 * scale,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(10) : const Color(0xFFFFF0DC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: firstItem != null && firstItem['image_url'] != null
                    ? Image.network(firstItem['image_url'], fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.local_pizza_outlined, color: AppColors.primary))
                    : const Icon(Icons.local_pizza_outlined, color: AppColors.primary),
              ),
            ),
            SizedBox(width: 14 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order['id'].toString().substring(0, 8)}...',
                    style: GoogleFonts.poppins(fontSize: 14 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Delivered',
                        style: GoogleFonts.poppins(fontSize: 11 * scale, color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Repeat Order Button
            ElevatedButton(
              onPressed: () async {
                final List items = order['order_items'];
                for (var item in items) {
                  final pizzaData = item['pizzas'];
                  if (pizzaData != null) {
                    final pizza = Pizza.fromJson(pizzaData);
                    await CartService.addToCart(
                      pizza, 
                      quantity: item['quantity'] ?? 1,
                      size: item['selected_size'],
                      addons: (item['selected_addons'] as List?)?.map((e) => e.toString()).toList() ?? [],
                    );
                  }
                }
                if (mounted) {
                  _showTopSnackBar(context, 'Order repeated! Items added to cart.');
                  MainScreen.of(context)?.setIndex(2); // Go to Cart Tab
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary.withAlpha(26),
                foregroundColor: AppColors.primary,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 8 * scale),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Repeat',
                style: GoogleFonts.poppins(fontSize: 12 * scale, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 8 * scale),
            Icon(Icons.arrow_forward_ios_rounded, size: 12 * scale, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories(double scale, bool isDark) {
    return SizedBox(
      height: 100 * scale,
      child: ListView.builder(
        padding: EdgeInsets.only(left: 20 * scale),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isActive = index == _activeCategoryIndex;
          return GestureDetector(
            onTap: () => setState(() => _activeCategoryIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic,
              margin: EdgeInsets.only(right: 14 * scale),
              padding: EdgeInsets.symmetric(horizontal: 18 * scale),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : (isDark ? Colors.white.withAlpha(13) : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isActive ? AppColors.primary : (isDark ? Colors.white10 : const Color(0xFFE8D5C0)), width: 1.2),
                boxShadow: isActive ? [BoxShadow(color: AppColors.primary.withAlpha(64), blurRadius: 10, offset: const Offset(0, 4))] : (isDark ? [] : [BoxShadow(color: const Color(0xFF2D1A0E).withAlpha(13), blurRadius: 10, offset: const Offset(0, 4))]),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cat.icon, style: TextStyle(fontSize: 22 * scale)),
                  SizedBox(width: 8 * scale),
                  Text(cat.name, style: GoogleFonts.poppins(fontSize: 13 * scale, fontWeight: FontWeight.w600, color: isActive ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF2D1A0E)))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerticalPizzaList(double scale, bool isDark) {
    return Column(
      children: _popularPizzas.map((pizza) {
        return GestureDetector(
          onTap: () => _showPizzaDetails(context, pizza, scale, isDark),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 10 * scale),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(13) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8D5C0), width: 1),
              boxShadow: isDark ? [] : [
                BoxShadow(
                  color: const Color(0xFF2D1A0E).withAlpha(20),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: Image + Tags
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: Container(
                        width: double.infinity,
                        height: 180 * scale,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withAlpha(5) : const Color(0xFFFFF0DC),
                        ),
                        child: Hero(
                          tag: 'pizza_home_${pizza.id}',
                          child: pizza.imageUrl.startsWith('http')
                              ? Image.network(
                                  pizza.imageUrl,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover, // Poora fill karega
                                  errorBuilder: (context, error, stackTrace) => 
                                    Image.asset('assets/images/pizza.png', fit: BoxFit.cover),
                                )
                              : Image.asset(
                                  'assets/images/pizza.png',
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                    // Discount Tag (Left)
                    if (pizza.discount > 0)
                      Positioned(
                        top: 15 * scale,
                        left: 0,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
                          decoration: const BoxDecoration(
                            color: Color(0xFF388E3C),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Text(
                            '${pizza.discount}% OFF',
                            style: GoogleFonts.poppins(
                              fontSize: 11 * scale,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    // Bestseller Tag (Right)
                    if (pizza.category == 'Bestseller')
                      Positioned(
                        top: 15 * scale,
                        right: 15 * scale,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 5 * scale),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withAlpha(76),
                                blurRadius: 8,
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, color: Colors.white, size: 12 * scale),
                              SizedBox(width: 4 * scale),
                              Text(
                                'Bestseller',
                                style: GoogleFonts.poppins(
                                  fontSize: 10 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                // Bottom: Content
                Padding(
                  padding: EdgeInsets.all(20 * scale),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 12 * scale,
                                      height: 12 * scale,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: pizza.isVeg ? Colors.green : Colors.red, width: 1),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 6 * scale,
                                          height: 6 * scale,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: pizza.isVeg ? Colors.green : Colors.red,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8 * scale),
                                    Expanded(
                                      child: Text(
                                        pizza.name,
                                        style: GoogleFonts.poppins(
                                          fontSize: 18 * scale,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF2D1A0E),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                              SizedBox(width: 4 * scale),
                              Text(
                                pizza.rating.toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: 14 * scale,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : const Color(0xFF2D1A0E),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 8 * scale),
                      Text(
                        pizza.description,
                        style: GoogleFonts.poppins(
                          fontSize: 13 * scale,
                          color: isDark ? Colors.white38 : const Color(0xFF2D1A0E).withAlpha(128),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 20 * scale),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (pizza.discount > 0)
                                Text(
                                  '₹${pizza.price.toInt()}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12 * scale,
                                    color: isDark ? Colors.white24 : const Color(0xFF2D1A0E).withAlpha(76),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              Text(
                                '₹${pizza.discountedPrice.toInt()}',
                                style: GoogleFonts.poppins(
                                  fontSize: 22 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF2D1A0E),
                                ),
                              ),
                            ],
                          ),
                    SizedBox(
                      height: 48 * scale,
                      child: ElevatedButton(
                        onPressed: () {
                          CartService.addToCart(pizza);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: AppColors.primary.withAlpha(102),
                          padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Add to Cart',
                          style: GoogleFonts.poppins(
                            fontSize: 14 * scale,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCafeTimingIndicator(double scale, bool isDark) {
    final now = DateTime.now();
    final currentHour = now.hour;
    // Open from 12 PM (12) to 10 PM (22)
    final isOpen = currentHour >= 12 && currentHour < 22;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 8 * scale),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(13) : Colors.white.withAlpha(150),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8D5C0), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  height: 10 * scale,
                  width: 10 * scale,
                  decoration: BoxDecoration(
                    color: isOpen ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isOpen ? Colors.green : Colors.red).withAlpha(100),
                        blurRadius: 6,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOpen ? 'We\'re Open Now!' : 'We\'re Currently Closed',
                        style: GoogleFonts.poppins(
                          fontSize: 13 * scale,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Cafe Hours: 12:00 PM - 10:00 PM',
                        style: GoogleFonts.poppins(
                          fontSize: 11 * scale,
                          color: isDark ? Colors.white38 : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isOpen)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(26),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Closed',
                      style: GoogleFonts.poppins(
                        fontSize: 10 * scale,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPizzaDetails(BuildContext context, Pizza item, double scale, bool isDark) {
    int quantity = 1;
    String? selectedSize = (item.sizes != null && item.sizes!.isNotEmpty) ? item.sizes!.first.name : null;
    List<String> selectedAddons = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Calculate price based on size and addons
            double currentUnitPrice = item.getPriceForSize(selectedSize ?? '');
            
            // Addon logic
            final bool isSmall = selectedSize?.toLowerCase() == 'small';
            for (var addon in selectedAddons) {
              if (addon == 'Extra Cheese') currentUnitPrice += isSmall ? 20 : 30;
              else if (addon == 'Paneer') currentUnitPrice += isSmall ? 30 : 50;
              else if (addon == 'Veggie') currentUnitPrice += isSmall ? 20 : 30;
            }

            final double totalDisplayPrice = currentUnitPrice * quantity;

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Large Image Header
                        Container(
                          width: double.infinity,
                          height: 300 * scale,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withAlpha(5) : const Color(0xFFFFF0DC),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Hero(
                                  tag: 'pizza_details_home_${item.id}',
                                  child: item.imageUrl.startsWith('http')
                                      ? Image.network(item.imageUrl, height: 220 * scale, fit: BoxFit.contain)
                                      : Image.asset('assets/images/pizza.png', height: 220 * scale, fit: BoxFit.contain),
                                ),
                              ),
                              // Close Button
                              Positioned(
                                top: 20 * scale,
                                right: 20 * scale,
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: isDark ? Colors.white.withAlpha(26) : Colors.white, shape: BoxShape.circle),
                                    child: Icon(Icons.close, color: isDark ? Colors.white : Colors.black, size: 20),
                                  ),
                                ),
                              ),
                              // Bestseller & Discount tags
                              if (item.category == 'Bestseller')
                                Positioned(
                                  top: 20 * scale,
                                  left: 20 * scale,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text('BESTSELLER', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: EdgeInsets.all(24 * scale),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 2. Info Row (Veg icon + Name + Rating)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 16 * scale, height: 16 * scale,
                                              decoration: BoxDecoration(
                                                border: Border.all(color: item.isVeg ? Colors.green : Colors.red, width: 1),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: Center(
                                                child: Container(
                                                  width: 8 * scale, height: 8 * scale,
                                                  decoration: BoxDecoration(shape: BoxShape.circle, color: item.isVeg ? Colors.green : Colors.red),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 10 * scale),
                                            Text(item.category, style: GoogleFonts.poppins(fontSize: 12 * scale, color: isDark ? Colors.white38 : AppColors.textGrey, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                        SizedBox(height: 8 * scale),
                                        Text(item.name, style: GoogleFonts.poppins(fontSize: 26 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF2D1A0E))),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.amber.withAlpha(26), borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                                        const SizedBox(width: 4),
                                        Text(item.rating.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: 16 * scale),

                              // ── Size Selection ──
                              if (item.sizes != null && item.sizes!.isNotEmpty) ...[
                                Text('Select Size', style: GoogleFonts.poppins(fontSize: 16 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                                SizedBox(height: 12 * scale),
                                Row(
                                  children: item.sizes!.map((size) {
                                    bool isSelected = selectedSize == size.name;
                                    return GestureDetector(
                                      onTap: () => setModalState(() => selectedSize = size.name),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        margin: EdgeInsets.only(right: 12 * scale),
                                        padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 10 * scale),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppColors.primary : (isDark ? Colors.white.withAlpha(13) : Colors.grey[100]),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: isSelected ? AppColors.primary : (isDark ? Colors.white10 : Colors.transparent)),
                                        ),
                                        child: Text(
                                          size.name,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13 * scale,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                SizedBox(height: 24 * scale),
                              ],

                              // ── Add-ons Selection ──
                              if (item.category.contains('Pizza')) ...[
                                Text('Add Extras', style: GoogleFonts.poppins(fontSize: 16 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                                SizedBox(height: 12 * scale),
                                ...['Extra Cheese', 'Paneer', 'Veggie'].map((addon) {
                                  bool isSelected = selectedAddons.contains(addon);
                                  int price = 0;
                                  bool isS = selectedSize?.toLowerCase() == 'small';
                                  if (addon == 'Extra Cheese') price = isS ? 20 : 30;
                                  else if (addon == 'Paneer') price = isS ? 30 : 50;
                                  else if (addon == 'Veggie') price = isS ? 20 : 30;

                                  return GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        if (isSelected) selectedAddons.remove(addon);
                                        else selectedAddons.add(addon);
                                      });
                                    },
                                    child: Container(
                                      margin: EdgeInsets.only(bottom: 10 * scale),
                                      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.primary.withAlpha(26) : (isDark ? Colors.white.withAlpha(13) : Colors.grey[50]),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: isSelected ? AppColors.primary : (isDark ? Colors.white10 : Colors.grey[200]!)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                            color: isSelected ? AppColors.primary : Colors.grey,
                                            size: 20 * scale,
                                          ),
                                          SizedBox(width: 12 * scale),
                                          Expanded(
                                            child: Text(
                                              addon,
                                              style: GoogleFonts.poppins(
                                                fontSize: 14 * scale,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '+₹$price',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13 * scale,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                                SizedBox(height: 24 * scale),
                              ],

                              // 3. Description
                              Text('Description', style: GoogleFonts.poppins(fontSize: 16 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                              SizedBox(height: 8 * scale),
                              Text(item.description, style: GoogleFonts.poppins(fontSize: 14 * scale, color: isDark ? Colors.white60 : AppColors.textGrey, height: 1.5)),
                              
                              SizedBox(height: 100 * scale), // Space for bottom bar
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 5. Fixed Bottom Pricing Bar
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: EdgeInsets.all(24 * scale),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(26), blurRadius: 20, offset: const Offset(0, -5))],
                      ),
                      child: Row(
                        children: [
                          // Price info
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.discount > 0)
                                  Text('₹${(item.price * (selectedSize != null ? (item.sizes!.firstWhere((s) => s.name == selectedSize).price / item.price) : 1) * quantity).toInt()}', 
                                      style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 14)),
                                Text('₹${totalDisplayPrice.toInt()}', style: GoogleFonts.poppins(fontSize: 22 * scale, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ],
                            ),
                          ),
                          // Quantity Counter
                          Container(
                            decoration: BoxDecoration(border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!), borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                IconButton(onPressed: quantity > 1 ? () => setModalState(() => quantity--) : null, icon: const Icon(Icons.remove, color: Colors.grey)),
                                Text('$quantity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                                IconButton(onPressed: () => setModalState(() => quantity++), icon: const Icon(Icons.add, color: AppColors.primary)),
                              ],
                            ),
                          ),
                          SizedBox(width: 16 * scale),
                          // Add Button
                          ElevatedButton(
                            onPressed: () {
                              CartService.addToCart(item, quantity: quantity, size: selectedSize, addons: selectedAddons);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 16 * scale),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWhyUs(double scale, bool isDark) {
    final perks = [
      {'icon': '🚀', 'title': 'Fast Delivery', 'sub': 'Under 30 minutes'},
      {'icon': '🍕', 'title': 'Fresh Dough', 'sub': 'Made daily'},
      {'icon': '💰', 'title': 'Best Price', 'sub': 'No hidden fees'},
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
      child: Row(
        children: perks.map((p) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: p != perks.last ? 10 * scale : 0),
              padding: EdgeInsets.symmetric(vertical: 14 * scale, horizontal: 8 * scale),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(13) : Colors.white, 
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8D5C0), width: 1),
                boxShadow: isDark ? [] : [BoxShadow(color: const Color(0xFF2D1A0E).withAlpha(13), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(
                children: [
                  Text(p['icon']!, style: TextStyle(fontSize: 24 * scale)),
                  SizedBox(height: 6 * scale),
                  Text(p['title']!, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 11 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF2D1A0E))),
                  SizedBox(height: 2 * scale),
                  Text(p['sub']!, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 9 * scale, color: isDark ? Colors.white38 : const Color(0xFF2D1A0E).withAlpha(115))),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TopSnackBarWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _TopSnackBarWidget({required this.message, required this.onDismiss});

  @override
  State<_TopSnackBarWidget> createState() => _TopSnackBarWidgetState();
}

class _TopSnackBarWidgetState extends State<_TopSnackBarWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _controller.forward();

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SlideTransition(
            position: _offsetAnimation,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: sw * 0.9,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark 
                          ? Colors.white.withAlpha(20) 
                          : AppColors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white.withAlpha(30) : AppColors.primary.withAlpha(60),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(isDark ? 60 : 20),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(40),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.message,
                              style: GoogleFonts.poppins(
                                color: isDark ? Colors.white : const Color(0xFF2D1A0E),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
