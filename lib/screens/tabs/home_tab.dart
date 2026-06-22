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
    try {
      final results = await Future.wait([
        SupabaseService.getBanners(),
        SupabaseService.getCategories(),
        SupabaseService.getPopularPizzas(),
      ]);

      if (mounted) {
        setState(() {
          _banners = (results[0] as List).map((e) => BannerModel.fromJson(e)).toList();
          _categories = (results[1] as List).map((e) => CategoryModel.fromJson(e)).toList();
          _popularPizzas = (results[2] as List).map((e) => Pizza.fromJson(e)).toList();
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
                _buildSectionHeader('Categories', scale, isDark),
                if (_categories.isNotEmpty) _buildCategories(scale, isDark),
                _buildSectionHeader('Popular Pizzas', scale, isDark),
                if (_popularPizzas.isNotEmpty) _buildVerticalPizzaList(scale, isDark),
                _buildSectionHeader('Why Choose Us?', scale, isDark),
                _buildWhyUs(scale, isDark),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_getGreeting(),
                style: GoogleFonts.poppins(fontSize: 13 * scale, color: isDark ? Colors.white38 : const Color(0xFF2D1A0E).withAlpha(128), fontWeight: FontWeight.w500)),
              SizedBox(height: 2 * scale),
              Text('What\'s your craving?',
                style: GoogleFonts.poppins(fontSize: 20 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF2D1A0E))),
            ],
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
                        return ListTile(
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 17 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF2D1A0E))),
          Text('View all', style: GoogleFonts.poppins(fontSize: 13 * scale, fontWeight: FontWeight.w600, color: AppColors.primary)),
        ],
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
                          child: Center(
                            child: pizza.imageUrl.startsWith('http')
                                ? Image.network(
                                    pizza.imageUrl,
                                    height: 150 * scale,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Image.asset('assets/images/pizza.png', height: 150 * scale),
                                  )
                                : Image.asset(
                                    'assets/images/pizza.png',
                                    height: 150 * scale,
                                    fit: BoxFit.contain,
                                  ),
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

  void _showPizzaDetails(BuildContext context, Pizza item, double scale, bool isDark) {
    int quantity = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                                  Text('₹${(item.price * quantity).toInt()}', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 14)),
                                Text('₹${(item.discountedPrice * quantity).toInt()}', style: GoogleFonts.poppins(fontSize: 22 * scale, fontWeight: FontWeight.bold, color: AppColors.primary)),
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
                              CartService.addToCart(item, quantity: quantity);
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
