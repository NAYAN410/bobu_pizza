import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../services/supabase_service.dart';
import '../../models/pizza_model.dart';
import '../../models/category_model.dart';
import '../../services/cart_service.dart';

class MenuTab extends StatefulWidget {
  const MenuTab({super.key});

  @override
  State<MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<MenuTab> {
  int _selectedCategoryIndex = 0;
  List<CategoryModel> _categories = [];
  List<Pizza> _allItems = [];
  bool _isLoading = true;
  bool _isMoreLoading = false;
  bool _hasMore = true;
  final int _pageSize = 4;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMenuData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isMoreLoading && _hasMore) {
        _loadMoreItems();
      }
    }
  }

  Future<void> _loadMenuData() async {
    setState(() {
      _isLoading = true;
      _allItems = [];
      _hasMore = true;
    });
    try {
      final results = await Future.wait([
        SupabaseService.getCategories(),
        SupabaseService.getPizzas(
          category: _selectedCategoryIndex == 0 ? null : _categories[_selectedCategoryIndex].name,
          from: 0,
          to: _pageSize - 1,
        ),
      ]);

      if (mounted) {
        setState(() {
          if (_categories.isEmpty) {
            _categories = [
              CategoryModel(id: -1, name: 'All', icon: '🍽️'),
              ...(results[0] as List).map((e) => CategoryModel.fromJson(e)),
            ];
          }
          _allItems = (results[1] as List).map((e) => Pizza.fromJson(e)).toList();
          _hasMore = _allItems.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading menu data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreItems() async {
    setState(() => _isMoreLoading = true);
    try {
      final nextItemsData = await SupabaseService.getPizzas(
        category: _selectedCategoryIndex == 0 ? null : _categories[_selectedCategoryIndex].name,
        from: _allItems.length,
        to: _allItems.length + _pageSize - 1,
      );

      final nextItems = nextItemsData.map((e) => Pizza.fromJson(e)).toList();

      if (mounted) {
        setState(() {
          _allItems.addAll(nextItems);
          _hasMore = nextItems.length == _pageSize;
          _isMoreLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading more items: $e');
      if (mounted) setState(() => _isMoreLoading = false);
    }
  }

  // Helper to handle category change
  void _onCategoryTapped(int index) {
    if (_selectedCategoryIndex == index) return;
    setState(() {
      _selectedCategoryIndex = index;
    });
    _loadMenuData();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final double contentWidth = sw.clamp(0.0, 500.0);
    final double scale = (contentWidth / 375).clamp(0.85, 1.1);
    final double bottomPad = MediaQuery.of(context).padding.bottom + 80;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF8F0),
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: EdgeInsets.fromLTRB(20 * scale, 16 * scale, 20 * scale, 0),
              child: Text(
                'Our Menu',
                style: GoogleFonts.poppins(
                  fontSize: 24 * scale,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D1A0E),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 20 * scale, right: 20 * scale, bottom: 14 * scale),
              child: Text(
                'Explore our wide range of pizzas, handcrafted with fresh dough, premium cheeses, and locally sourced toppings.',
                style: GoogleFonts.poppins(
                  fontSize: 13 * scale,
                  color: const Color(0xFF2D1A0E).withOpacity(0.45),
                ),
              ),
            ),

            // ── Category chips ──
            SizedBox(
              height: 42 * scale,
              child: ListView.builder(
                padding: EdgeInsets.only(left: 20 * scale),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final isActive = index == _selectedCategoryIndex;
                  return GestureDetector(
                    onTap: () => _onCategoryTapped(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      margin: EdgeInsets.only(right: 10 * scale),
                      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive ? AppColors.primary : const Color(0xFFE8D5C0),
                          width: 1.2,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_categories[index].icon, style: TextStyle(fontSize: 14 * scale)),
                          SizedBox(width: 6 * scale),
                          Text(
                            _categories[index].name,
                            style: GoogleFonts.poppins(
                              fontSize: 12 * scale,
                              fontWeight: FontWeight.w600,
                              color: isActive ? Colors.white : const Color(0xFF2D1A0E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            SizedBox(height: 12 * scale),

            // ── Item count ──
            Padding(
              padding: EdgeInsets.only(left: 20 * scale, bottom: 10 * scale),
              child: Text(
                '${_allItems.length} items',
                style: GoogleFonts.poppins(
                  fontSize: 12 * scale,
                  color: const Color(0xFF2D1A0E).withOpacity(0.4),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // ── List ──
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadMenuData,
                color: AppColors.primary,
                backgroundColor: Colors.white,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    left: 20 * scale,
                    right: 20 * scale,
                    bottom: bottomPad,
                  ),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  itemCount: _allItems.length + (_isMoreLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _allItems.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary.withOpacity(0.5),
                          ),
                        ),
                      );
                    }
                    final item = _allItems[index];
                    return GestureDetector(
                      onTap: () => _showPizzaDetails(context, item, scale),
                      child: _buildMenuCard(item, scale),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
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
                                  tag: 'pizza_details_${item.id}',
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
                                        Text(item.name, style: GoogleFonts.poppins(fontSize: 26 * scale, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
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
                              
                              SizedBox(height: 24 * scale),
                              
                              // 4. Customization Options (Placeholder)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: Colors.blue),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text('Customization options coming soon!', style: GoogleFonts.poppins(fontSize: 12 * scale, color: Colors.blue[800])),
                                    ),
                                  ],
                                ),
                              ),
                              
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

  Widget _buildMenuCard(Pizza item, double scale) {
    return Container(
      margin: EdgeInsets.only(bottom: 24 * scale),
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
                    tag: 'pizza_${item.id}',
                    child: Center(
                      child: item.imageUrl.startsWith('http')
                          ? Image.network(
                              item.imageUrl,
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
              if (item.discount > 0)
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
                      '${item.discount}% OFF',
                      style: GoogleFonts.poppins(
                        fontSize: 11 * scale,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              // Bestseller Tag (Right)
              if (item.category == 'Bestseller')
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
                                  border: Border.all(color: item.isVeg ? Colors.green : Colors.red, width: 1),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 6 * scale,
                                    height: 6 * scale,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: item.isVeg ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8 * scale),
                              Expanded(
                                child: Text(
                                  item.name,
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
                          item.rating.toString(),
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
                  item.description,
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
                        if (item.discount > 0)
                          Text(
                            '₹${item.price.toInt()}',
                            style: GoogleFonts.poppins(
                              fontSize: 12 * scale,
                              color: const Color(0xFF2D1A0E).withOpacity(0.3),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        Text(
                          '₹${item.discountedPrice.toInt()}',
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
                          CartService.addToCart(item);
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
    );
  }
}

