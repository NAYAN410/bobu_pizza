import 'dart:async';
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
  int _currentBanner = 0;
  Timer? _bannerTimer;

  List<BannerModel> _banners = [];
  List<CategoryModel> _categories = [];
  List<Pizza> _popularPizzas = [];
  bool _isLoading = true;
  int _activeCategoryIndex = 0;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final double contentWidth = sw.clamp(0.0, 500.0);
    final double scale = (contentWidth / 375).clamp(0.85, 1.15);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF8F0),
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAllData,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(scale),
                _buildSearchBar(scale),
                if (_banners.isNotEmpty) _buildBannerCarousel(scale, contentWidth),
                _buildSectionHeader('Categories', scale),
                if (_categories.isNotEmpty) _buildCategories(scale),
                _buildSectionHeader('Popular Pizzas', scale),
                if (_popularPizzas.isNotEmpty) _buildVerticalPizzaList(scale),
                _buildSectionHeader('Why Choose Us?', scale),
                _buildWhyUs(scale),
                SizedBox(height: 90 * scale),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────

  Widget _buildHeader(double scale) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20 * scale, 16 * scale, 20 * scale, 8 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_getGreeting(),
                style: GoogleFonts.poppins(fontSize: 13 * scale, color: const Color(0xFF2D1A0E).withOpacity(0.5), fontWeight: FontWeight.w500)),
              SizedBox(height: 2 * scale),
              Text('What\'s your craving?',
                style: GoogleFonts.poppins(fontSize: 20 * scale, fontWeight: FontWeight.bold, color: const Color(0xFF2D1A0E))),
            ],
          ),
          Stack(
            children: [
              Container(
                padding: EdgeInsets.all(10 * scale),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8D5C0), width: 1.2),
                  boxShadow: [BoxShadow(color: const Color(0xFF2D1A0E).withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Icon(Icons.notifications_none_outlined, color: const Color(0xFF2D1A0E), size: 22 * scale),
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

  Widget _buildSearchBar(double scale) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 10 * scale),
      child: Container(
        height: 52 * scale,
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8D5C0), width: 1.2),
          boxShadow: [BoxShadow(color: const Color(0xFF2D1A0E).withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            SizedBox(width: 16 * scale),
            Icon(Icons.search_rounded, color: const Color(0xFF2D1A0E).withOpacity(0.3), size: 22 * scale),
            SizedBox(width: 10 * scale),
            Text('Search pizzas, sides, drinks...', style: GoogleFonts.poppins(color: const Color(0xFF2D1A0E).withOpacity(0.3), fontSize: 13 * scale)),
            const Spacer(),
            Container(
              margin: EdgeInsets.all(8 * scale), padding: EdgeInsets.all(6 * scale),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.tune_rounded, color: Colors.white, size: 16 * scale),
            ),
          ],
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
                color: isActive ? AppColors.primary : AppColors.primary.withOpacity(0.25),
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
            color: Colors.black.withOpacity(0.08),
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
        child: Icon(Icons.image_outlined, color: Colors.white.withOpacity(0.5), size: 50 * scale),
      ),
    );
  }

  Widget _buildSectionHeader(String title, double scale) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20 * scale, 20 * scale, 20 * scale, 12 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 17 * scale, fontWeight: FontWeight.bold, color: const Color(0xFF2D1A0E))),
          Text('View all', style: GoogleFonts.poppins(fontSize: 13 * scale, fontWeight: FontWeight.w600, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildCategories(double scale) {
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
                color: isActive ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isActive ? AppColors.primary : const Color(0xFFE8D5C0), width: 1.2),
                boxShadow: [BoxShadow(color: isActive ? AppColors.primary.withOpacity(0.25) : const Color(0xFF2D1A0E).withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cat.icon, style: TextStyle(fontSize: 22 * scale)),
                  SizedBox(width: 8 * scale),
                  Text(cat.name, style: GoogleFonts.poppins(fontSize: 13 * scale, fontWeight: FontWeight.w600, color: isActive ? Colors.white : const Color(0xFF2D1A0E))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerticalPizzaList(double scale) {
    return Column(
      children: _popularPizzas.map((pizza) {
        return GestureDetector(
          onTap: () => _showPizzaDetails(context, pizza, scale),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 10 * scale),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE8D5C0), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2D1A0E).withOpacity(0.08),
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
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF0DC),
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
                                color: AppColors.primary.withOpacity(0.3),
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
                                          color: const Color(0xFF2D1A0E),
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
                                  color: const Color(0xFF2D1A0E),
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
                          color: const Color(0xFF2D1A0E).withOpacity(0.5),
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
                                    color: const Color(0xFF2D1A0E).withOpacity(0.3),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              Text(
                                '₹${pizza.discountedPrice.toInt()}',
                                style: GoogleFonts.poppins(
                                  fontSize: 22 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2D1A0E),
                                ),
                              ),
                            ],
                          ),
                    SizedBox(
                      height: 48 * scale,
                      child: ElevatedButton(
                        onPressed: () {
                          CartService.addToCart(pizza);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${pizza.name} added to cart!'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: AppColors.primary.withOpacity(0.4),
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

  void _showPizzaDetails(BuildContext context, Pizza item, double scale) {
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
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF0DC),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.black, size: 20),
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
                                            Text(item.category, style: GoogleFonts.poppins(fontSize: 12 * scale, color: AppColors.textGrey, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                        SizedBox(height: 8 * scale),
                                        Text(item.name, style: GoogleFonts.poppins(fontSize: 26 * scale, fontWeight: FontWeight.bold, color: const Color(0xFF2D1A0E))),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.amber.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                                        const SizedBox(width: 4),
                                        Text(item.rating.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: 16 * scale),
                              
                              // 3. Description
                              Text('Description', style: GoogleFonts.poppins(fontSize: 16 * scale, fontWeight: FontWeight.bold)),
                              SizedBox(height: 8 * scale),
                              Text(item.description, style: GoogleFonts.poppins(fontSize: 14 * scale, color: AppColors.textGrey, height: 1.5)),
                              
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
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 20, offset: const Offset(0, -5))],
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
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                IconButton(onPressed: quantity > 1 ? () => setModalState(() => quantity--) : null, icon: const Icon(Icons.remove)),
                                Text('$quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${item.name} added to cart!'),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
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

  Widget _buildWhyUs(double scale) {
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
                color: Colors.white, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8D5C0), width: 1),
                boxShadow: [BoxShadow(color: const Color(0xFF2D1A0E).withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(
                children: [
                  Text(p['icon']!, style: TextStyle(fontSize: 24 * scale)),
                  SizedBox(height: 6 * scale),
                  Text(p['title']!, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 11 * scale, fontWeight: FontWeight.bold, color: const Color(0xFF2D1A0E))),
                  SizedBox(height: 2 * scale),
                  Text(p['sub']!, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 9 * scale, color: const Color(0xFF2D1A0E).withOpacity(0.45))),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
