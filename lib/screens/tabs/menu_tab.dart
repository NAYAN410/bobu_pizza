import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final Map<int, List<Pizza>> _cache = {};
  final Map<int, bool> _cacheHasMore = {};

  bool _isInitialLoading = true;
  bool _isCategoryLoading = false;
  bool _isMoreLoading = false;
  bool _hasMore = true;

  final int _pageSize = 10;
  final ScrollController _scrollController = ScrollController();

  // ── Sidebar wheel controller ──
  late final FixedExtentScrollController _wheelController =
  FixedExtentScrollController(initialItem: _selectedCategoryIndex);

  // True while a tap-triggered animateToItem is running.
  // Prevents intermediate pass-through items from firing loads/haptics.
  bool _isProgrammaticScroll = false;

  // ── Fixed sizes — sidebar looks identical everywhere ──
  static const double _sidebarWidth = 92.0; // Increased width slightly
  static const double _itemHeight = 82.0; // Increased height to fit 2 lines comfortably

  @override
  void initState() {
    super.initState();
    _initialFetch();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _wheelController.dispose();
    super.dispose();
  }

  Future<void> _initialFetch() async {
    try {
      final categoryData = await SupabaseService.getCategories();
      if (mounted) {
        setState(() {
          final List<CategoryModel> dbCategories =
          categoryData.map((e) => CategoryModel.fromJson(e)).toList();
          _categories = [
            CategoryModel(id: -1, name: 'All', icon: '🍽️'),
            ...dbCategories,
          ];
          _isInitialLoading = false;
        });
        _loadCategoryItems(0);
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _loadCategoryItems(int index) async {
    if (_cache.containsKey(index)) {
      setState(() {
        _allItems = _cache[index]!;
        _hasMore = _cacheHasMore[index] ?? true;
        _isCategoryLoading = false;
      });
      return;
    }

    setState(() {
      _isCategoryLoading = true;
      _allItems = [];
    });

    try {
      final data = await SupabaseService.getPizzas(
        category: index == 0 ? null : _categories[index].name,
        from: 0,
        to: _pageSize - 1,
      );

      final items = data.map((e) => Pizza.fromJson(e)).toList();

      if (mounted) {
        setState(() {
          _allItems = items;
          _cache[index] = items;
          _hasMore = items.length == _pageSize;
          _cacheHasMore[index] = _hasMore;
          _isCategoryLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isCategoryLoading = false);
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isMoreLoading || !_hasMore) return;

    setState(() => _isMoreLoading = true);
    final currentIndex = _selectedCategoryIndex;

    try {
      final nextItemsData = await SupabaseService.getPizzas(
        category: currentIndex == 0 ? null : _categories[currentIndex].name,
        from: _allItems.length,
        to: _allItems.length + _pageSize - 1,
      );

      final nextItems = nextItemsData.map((e) => Pizza.fromJson(e)).toList();

      if (mounted && _selectedCategoryIndex == currentIndex) {
        setState(() {
          _allItems.addAll(nextItems);
          _cache[currentIndex] = List.from(_allItems);
          _hasMore = nextItems.length == _pageSize;
          _cacheHasMore[currentIndex] = _hasMore;
          _isMoreLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isMoreLoading = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreItems();
    }
  }

  /// Called when the user TAPS a category (may be far away, e.g. 1 → 4).
  /// Animates the wheel smoothly through all intermediate items without
  /// triggering loads/haptics for each one it passes.
  Future<void> _onCategoryTapped(int index) async {
    if (index < 0 || index >= _categories.length) return;
    if (index == _selectedCategoryIndex) return;

    final int distance = (index - _selectedCategoryIndex).abs();
    // Slightly longer duration for longer jumps so it still feels natural,
    // capped so it never feels sluggish.
    final int durationMs = (320 + distance * 55).clamp(320, 700);

    HapticFeedback.selectionClick();
    setState(() => _isProgrammaticScroll = true);

    await _wheelController.animateToItem(
      index,
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOutCubic,
    );

    if (!mounted) return;
    setState(() {
      _selectedCategoryIndex = index;
      _isProgrammaticScroll = false;
    });
    _loadCategoryItems(index);
  }

  /// Called when the user physically DRAGS the wheel and it settles on
  /// a new item. Ignored while a tap-triggered animation is in progress.
  void _onWheelSelectedItemChanged(int index) {
    if (_isProgrammaticScroll) return;
    if (index == _selectedCategoryIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedCategoryIndex = index);
    _loadCategoryItems(index);
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final double scale = (sw.clamp(0.0, 500.0) / 375).clamp(0.85, 1.1);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark ? AppColors.bgGradientDark : AppColors.bgGradient,
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20 * scale, 16 * scale, 20 * scale, 12 * scale),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Our Menu',
                  style: GoogleFonts.poppins(
                    fontSize: 22 * scale,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF2D1A0E),
                  ),
                ),
                Icon(Icons.search_rounded, size: 24 * scale, color: isDark ? Colors.white70 : Colors.black87),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                // ── Right Content ──
                Row(
                  children: [
                    const SizedBox(width: _sidebarWidth + 24), // Offset for floating sidebar
                    Expanded(
                      child: _isCategoryLoading
                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                          : RefreshIndicator(
                        onRefresh: () async {
                          _cache.remove(_selectedCategoryIndex);
                          await _loadCategoryItems(_selectedCategoryIndex);
                        },
                        color: AppColors.primary,
                        child: _allItems.isEmpty
                            ? _buildEmptyState(isDark)
                            : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.fromLTRB(0, 12 * scale, 16 * scale, 140 * scale),
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          itemCount: _allItems.length + (_isMoreLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _allItems.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                              );
                            }
                            final item = _allItems[index];
                            return GestureDetector(
                              onTap: () => _showPizzaDetails(context, item, scale, isDark),
                              child: _buildCompactMenuCard(item, scale, isDark),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Left Sidebar (Floating Capsule) ──
                Positioned(
                  top: 0,
                  left: 12 * scale,
                  bottom: 85 * scale, // Sits just above the main navbar
                  child: _buildSidebar(isDark, scale),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Sidebar — Floating Capsule, centered pill, ultra-smooth drag wheel
  // ─────────────────────────────────────────────────────────
  Widget _buildSidebar(bool isDark, double scale) {
    final BorderRadius capsuleRadius = BorderRadius.circular(40 * scale);

    return Container(
      width: _sidebarWidth,
      decoration: BoxDecoration(
        borderRadius: capsuleRadius,
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3), // Reddish border for capsule
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: capsuleRadius,
        child: Stack(
          children: [
            // Glass Background
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.45),
                ),
              ),
            ),

            // Fixed, perfectly centered highlight pill
            Align(
              alignment: Alignment.center,
              child: Container(
                width: _sidebarWidth - 16,
                height: _itemHeight - 14,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(isDark ? 0.25 : 0.16),
                      AppColors.primary.withOpacity(isDark ? 0.10 : 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 15,
                    ),
                  ],
                ),
              ),
            ),

            ListWheelScrollView.useDelegate(
              controller: _wheelController,
              itemExtent: _itemHeight,
              diameterRatio: 2.0,
              perspective: 0.0025,
              physics: const FixedExtentScrollPhysics(),
              overAndUnderCenterOpacity: 1.0,
              onSelectedItemChanged: _onWheelSelectedItemChanged,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: _categories.length,
                builder: (context, index) {
                  return AnimatedBuilder(
                    animation: _wheelController,
                    builder: (context, child) {
                      double diff;
                      if (_wheelController.hasClients && _wheelController.position.hasContentDimensions) {
                        diff = (index * _itemHeight - _wheelController.offset) / _itemHeight;
                      } else {
                        diff = (index - _selectedCategoryIndex).toDouble();
                      }
                      final double closeness = (1 - diff.abs()).clamp(0.0, 1.0);
                      final double iconScale = 0.82 + 0.36 * closeness;
                      final double opacity = (0.4 + 0.6 * closeness).clamp(0.0, 1.0);
                      final bool isActive = index == _selectedCategoryIndex;

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _onCategoryTapped(index),
                        child: Opacity(
                          opacity: opacity,
                          child: Transform.scale(
                            scale: iconScale,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _categories[index].icon,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: _sidebarWidth - 28, // Forces text to wrap before hitting red box edge
                                    child: Text(
                                      _categories[index].name,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      softWrap: true,
                                      style: GoogleFonts.poppins(
                                        fontSize: 9,
                                        height: 1.0, // Tighter line height for 2-line text
                                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                        color: isActive
                                            ? AppColors.primary
                                            : (isDark ? Colors.white54 : Colors.grey[600]),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🍕', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('No items found', style: GoogleFonts.poppins(color: isDark ? Colors.white54 : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCompactMenuCard(Pizza item, double scale, bool isDark) {
    return Container(
      margin: EdgeInsets.only(bottom: 16 * scale),
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!, width: 1),
        boxShadow: isDark
            ? []
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                width: 90 * scale,
                height: 90 * scale,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFFFF0DC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Hero(
                  tag: 'pizza_${item.id}',
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: item.imageUrl.startsWith('http')
                        ? Image.network(item.imageUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Image.asset('assets/images/pizza.png'))
                        : Image.asset('assets/images/pizza.png', fit: BoxFit.contain),
                  ),
                ),
              ),
              if (item.discount > 0)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF388E3C),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(14), bottomRight: Radius.circular(8)),
                    ),
                    child: Text('${item.discount}%', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10 * scale,
                      height: 10 * scale,
                      decoration: BoxDecoration(
                        border: Border.all(color: item.isVeg ? Colors.green : Colors.red, width: 1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Center(
                        child: Container(
                          width: 5 * scale,
                          height: 5 * scale,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: item.isVeg ? Colors.green : Colors.red),
                        ),
                      ),
                    ),
                    if (item.category == 'Bestseller') ...[
                      SizedBox(width: 6 * scale),
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      Text(' Bestseller', style: GoogleFonts.poppins(fontSize: 9, color: Colors.amber[800], fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
                SizedBox(height: 4 * scale),
                Text(
                  item.name,
                  style: GoogleFonts.poppins(
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF2D1A0E),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2 * scale),
                Text(
                  item.description,
                  style: GoogleFonts.poppins(
                    fontSize: 10 * scale,
                    color: isDark ? Colors.white38 : Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8 * scale),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.discount > 0)
                          Text('₹${item.price.toInt()}', style: TextStyle(fontSize: 10, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                        Text('₹${item.discountedPrice.toInt()}', style: GoogleFonts.poppins(fontSize: 15 * scale, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      ],
                    ),
                    SizedBox(
                      height: 32 * scale,
                      child: ElevatedButton(
                        onPressed: () => CartService.addToCart(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('ADD', style: GoogleFonts.poppins(fontSize: 11 * scale, fontWeight: FontWeight.bold)),
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
                        Container(
                          width: double.infinity,
                          height: 300 * scale,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFFFF0DC),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                              Positioned(
                                top: 20 * scale,
                                right: 20 * scale,
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.1) : Colors.white, shape: BoxShape.circle),
                                    child: Icon(Icons.close, color: isDark ? Colors.white : Colors.black, size: 20),
                                  ),
                                ),
                              ),
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
                                              width: 16 * scale,
                                              height: 16 * scale,
                                              decoration: BoxDecoration(
                                                border: Border.all(color: item.isVeg ? Colors.green : Colors.red, width: 1),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: Center(
                                                child: Container(
                                                  width: 8 * scale,
                                                  height: 8 * scale,
                                                  decoration: BoxDecoration(shape: BoxShape.circle, color: item.isVeg ? Colors.green : Colors.red),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 10 * scale),
                                            Text(item.category, style: GoogleFonts.poppins(fontSize: 12 * scale, color: isDark ? Colors.white38 : AppColors.textGrey, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                        SizedBox(height: 8 * scale),
                                        Text(item.name, style: GoogleFonts.poppins(fontSize: 26 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textBlack)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
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
                              Text('Description', style: GoogleFonts.poppins(fontSize: 16 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                              SizedBox(height: 8 * scale),
                              Text(item.description, style: GoogleFonts.poppins(fontSize: 14 * scale, color: isDark ? Colors.white60 : AppColors.textGrey, height: 1.5)),
                              SizedBox(height: 24 * scale),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey[50], borderRadius: BorderRadius.circular(16)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: Colors.blue),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text('Customization options coming soon!', style: GoogleFonts.poppins(fontSize: 12 * scale, color: isDark ? Colors.blue[200] : Colors.blue[800])),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 100 * scale),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(24 * scale),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
                      ),
                      child: Row(
                        children: [
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
}