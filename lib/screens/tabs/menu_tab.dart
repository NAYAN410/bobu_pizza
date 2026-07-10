import 'dart:ui';
import 'dart:async';
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

  final TextEditingController _searchController = TextEditingController();
  bool _isSearchActive = false;
  bool _isSearching = false;
  List<Pizza> _searchResults = [];
  Timer? _debounce;

  final Map<int, List<Pizza>> _cache = {};
  final Map<int, bool> _cacheHasMore = {};

  bool _isInitialLoading = true;
  bool _isCategoryLoading = false;
  bool _isMoreLoading = false;
  bool _hasMore = true;

  final int _pageSize = 10;
  final ScrollController _scrollController = ScrollController();

  late final FixedExtentScrollController _wheelController =
  FixedExtentScrollController(initialItem: _selectedCategoryIndex);

  bool _isProgrammaticScroll = false;

  static const double _sidebarWidth = 92.0;
  static const double _itemHeight = 82.0;

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
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final data = await SupabaseService.searchPizzas(query, limit: 15);
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

      if (mounted) {
        if (_selectedCategoryIndex == currentIndex) {
          setState(() {
            _allItems.addAll(nextItems);
            _cache[currentIndex] = List.from(_allItems);
            _hasMore = nextItems.length == _pageSize;
            _cacheHasMore[currentIndex] = _hasMore;
            _isMoreLoading = false;
          });
        } else {
          _isMoreLoading = false;
        }
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

  Future<void> _onCategoryTapped(int index) async {
    if (index < 0 || index >= _categories.length) return;
    if (index == _selectedCategoryIndex) return;

    final int distance = (index - _selectedCategoryIndex).abs();
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
            padding: EdgeInsets.fromLTRB(20 * scale, 16 * scale, 16 * scale, 12 * scale),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _isSearchActive
                  ? _buildSearchField(scale, isDark)
                  : Row(
                      key: const ValueKey('header_title'),
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
                        IconButton(
                          onPressed: () => setState(() => _isSearchActive = true),
                          icon: Icon(Icons.search_rounded, size: 24 * scale, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ],
                    ),
            ),
          ),

          Expanded(
            child: Stack(
              children: [
                Row(
                  children: [
                    const SizedBox(width: _sidebarWidth + 24),
                    Expanded(
                      child: _isSearchActive ? _buildSearchResults(scale, isDark) : _buildCategoryItems(scale, isDark),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  left: 12 * scale,
                  bottom: 85 * scale,
                  child: _buildSidebar(isDark, scale),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(double scale, bool isDark) {
    return Container(
      key: const ValueKey('header_search'),
      height: 48 * scale,
      padding: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white.withAlpha(204),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withAlpha(76)),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: _onSearchChanged,
        style: GoogleFonts.poppins(fontSize: 14 * scale, color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: 'Search pizzas...',
          hintStyle: GoogleFonts.poppins(fontSize: 13 * scale, color: isDark ? Colors.white38 : Colors.grey),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary, size: 20 * scale),
          suffixIcon: IconButton(
            icon: Icon(Icons.close_rounded, size: 20 * scale, color: Colors.grey),
            onPressed: () {
              setState(() {
                _isSearchActive = false;
                _searchController.clear();
                _searchResults = [];
                _isSearching = false;
              });
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSearchResults(double scale, bool isDark) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
    }

    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 48, color: isDark ? Colors.white10 : Colors.grey[200]),
            const SizedBox(height: 12),
            Text('Type to search something yummy...', style: GoogleFonts.poppins(color: isDark ? Colors.white38 : Colors.grey)),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(0, 12 * scale, 16 * scale, 140 * scale),
      physics: const BouncingScrollPhysics(),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        return GestureDetector(
          onTap: () {
            if (item.category == 'BOBU Deals') {
              _showDealDetails(context, item, scale, isDark);
            } else {
              _showPizzaDetails(context, item, scale, isDark);
            }
          },
          child: _buildCompactMenuCard(item, scale, isDark),
        );
      },
    );
  }

  Widget _buildCategoryItems(double scale, bool isDark) {
    return _isCategoryLoading
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
            onTap: () {
              if (item.category == 'BOBU Deals') {
                _showDealDetails(context, item, scale, isDark);
              } else {
                _showPizzaDetails(context, item, scale, isDark);
              }
            },
            child: _buildCompactMenuCard(item, scale, isDark),
          );
        },
      ),
    );
  }

  Widget _buildSidebar(bool isDark, double scale) {
    final BorderRadius capsuleRadius = BorderRadius.circular(40 * scale);

    return Container(
      width: _sidebarWidth,
      decoration: BoxDecoration(
        borderRadius: capsuleRadius,
        border: Border.all(
          color: AppColors.primary.withAlpha(76),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: capsuleRadius,
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: isDark ? Colors.white.withAlpha(10) : Colors.white.withAlpha(115),
                ),
              ),
            ),
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
                      AppColors.primary.withAlpha(isDark ? 64 : 41),
                      AppColors.primary.withAlpha(isDark ? 26 : 15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withAlpha(102), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(51),
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
                                    width: _sidebarWidth - 28,
                                    child: Text(
                                      _categories[index].name,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      softWrap: true,
                                      style: GoogleFonts.poppins(
                                        fontSize: 9,
                                        height: 1.0,
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
          const Text('🍕', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('No pizzas found', style: GoogleFonts.poppins(color: isDark ? Colors.white54 : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCompactMenuCard(Pizza item, double scale, bool isDark) {
    return Container(
      margin: EdgeInsets.only(bottom: 16 * scale),
      padding: EdgeInsets.all(10 * scale),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!, width: 1),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withAlpha(8),
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
                width: 85 * scale,
                height: 85 * scale,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(5) : const Color(0xFFFFF0DC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Hero(
                    tag: 'pizza_${item.id}',
                    child: item.imageUrl.startsWith('http')
                        ? Image.network(
                            item.imageUrl, 
                            fit: BoxFit.cover,
                            cacheWidth: 200,
                            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                              if (wasSynchronouslyLoaded) return child;
                              return AnimatedOpacity(
                                opacity: frame == null ? 0 : 1,
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOut,
                                child: child,
                              );
                            },
                            errorBuilder: (_, __, ___) => Image.asset('assets/images/pizza.png', fit: BoxFit.cover)
                          )
                        : Image.asset('assets/images/pizza.png', fit: BoxFit.cover),
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
              if (item.tag != null && item.tag.isNotEmpty)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomRight: Radius.circular(14),
                      ),
                    ),
                    child: Text(
                      item.tag.toUpperCase(),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 7 * scale,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
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
                      SizedBox(width: 4 * scale),
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                      Text(' Bestseller', style: GoogleFonts.poppins(fontSize: 8, color: Colors.amber[800], fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
                SizedBox(height: 4 * scale),
                Text(
                  item.name,
                  style: GoogleFonts.poppins(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF2D1A0E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.description,
                  style: GoogleFonts.poppins(
                    fontSize: 9 * scale,
                    color: isDark ? Colors.white38 : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8 * scale),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.discount > 0)
                            Text('₹${item.price.toInt()}', 
                              style: TextStyle(fontSize: 9 * scale, color: Colors.grey, decoration: TextDecoration.lineThrough)
                            ),
                          Text('₹${item.discountedPrice.toInt()}', 
                            style: GoogleFonts.poppins(
                              fontSize: 14 * scale, 
                              fontWeight: FontWeight.w800, 
                              color: AppColors.primary
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 28 * scale,
                      child: ElevatedButton(
                        onPressed: () {
                          if (item.category == 'BOBU Deals') {
                            _showDealDetails(context, item, scale, isDark);
                          } else {
                            CartService.addToCart(item);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(horizontal: 8 * scale),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: Text(
                          item.category == 'BOBU Deals' ? 'SELECT' : 'ADD',
                          style: GoogleFonts.poppins(fontSize: 10 * scale, fontWeight: FontWeight.bold)
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
            double currentUnitPrice = item.getPriceForSize(selectedSize ?? '');
            
            final bool isBobu = item.category.toLowerCase().contains('bobu');
            final String size = selectedSize?.toLowerCase() ?? 'small';

            for (var addon in selectedAddons) {
              final a = addon.toLowerCase();
              if (isBobu) {
                if (a.contains('cheese')) currentUnitPrice += (size == 'small' ? 39 : (size == 'medium' ? 69 : 99));
                else if (a.contains('veg topping')) currentUnitPrice += (size == 'small' ? 19 : (size == 'medium' ? 29 : 39));
                else if (a.contains('paneer') || a.contains('olive')) currentUnitPrice += (size == 'small' ? 29 : (size == 'medium' ? 49 : 69));
                else if (a.contains('jalapeno') || a.contains('paprika')) currentUnitPrice += (size == 'small' ? 29 : (size == 'medium' ? 49 : 69));
              } else {
                if (a.contains('cheese')) currentUnitPrice += (size == 'small' ? 20 : 30);
                else if (a.contains('paneer')) currentUnitPrice += (size == 'small' ? 30 : 50);
                else if (a.contains('veggie')) currentUnitPrice += (size == 'small' ? 20 : 30);
              }
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
                        Container(
                          width: double.infinity,
                          height: 300 * scale,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withAlpha(5) : const Color(0xFFFFF0DC),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                                  child: Hero(
                                    tag: 'pizza_details_${item.id}',
                                    child: item.imageUrl.startsWith('http')
                                        ? Image.network(
                                            item.imageUrl, 
                                            fit: BoxFit.cover,
                                            cacheWidth: 1000,
                                            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                              if (wasSynchronouslyLoaded) return child;
                                              return AnimatedOpacity(
                                                opacity: frame == null ? 0 : 1,
                                                duration: const Duration(milliseconds: 500),
                                                curve: Curves.easeOut,
                                                child: child,
                                              );
                                            },
                                          )
                                        : Image.asset('assets/images/pizza.png', fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 20 * scale,
                                right: 20 * scale,
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 20 * scale,
                                left: 20 * scale,
                                child: Row(
                                  children: [
                                    if (item.category == 'Bestseller')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text('BESTSELLER', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    if (item.tag != null && item.tag.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.amber[800],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          item.tag.toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
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

                              if (item.category.contains('Pizza')) ...[
                                Text('Add Extras', style: GoogleFonts.poppins(fontSize: 16 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                                SizedBox(height: 12 * scale),
                                ...(isBobu 
                                    ? ['Extra Cheese', 'Veg Toppings', 'Paneer/Olive', 'Jalapeno/Paprika'] 
                                    : ['Extra Cheese', 'Paneer', 'Veggie']
                                ).map((addon) {
                                  bool isSelected = selectedAddons.contains(addon);
                                  int price = 0;
                                  final String sz = selectedSize?.toLowerCase() ?? 'small';
                                  
                                  if (isBobu) {
                                    if (addon.contains('Cheese')) price = sz == 'small' ? 39 : (sz == 'medium' ? 69 : 99);
                                    else if (addon.contains('Veg')) price = sz == 'small' ? 19 : (sz == 'medium' ? 29 : 39);
                                    else if (addon.contains('Paneer')) price = sz == 'small' ? 29 : (sz == 'medium' ? 49 : 69);
                                    else if (addon.contains('Jalapeno')) price = sz == 'small' ? 29 : (sz == 'medium' ? 49 : 69);
                                  } else {
                                    if (addon == 'Extra Cheese') price = sz == 'small' ? 20 : 30;
                                    else if (addon == 'Paneer') price = sz == 'small' ? 30 : 50;
                                    else if (addon == 'Veggie') price = sz == 'small' ? 20 : 30;
                                  }

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
                                        color: isSelected ? AppColors.primary.withAlpha(26) : (isDark ? Colors.white.withAlpha(5) : Colors.grey[50]),
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

                              Text('Description', style: GoogleFonts.poppins(fontSize: 16 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                              SizedBox(height: 8 * scale),
                              Text(item.description, style: GoogleFonts.poppins(fontSize: 14 * scale, color: isDark ? Colors.white60 : AppColors.textGrey, height: 1.5)),
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
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(26), blurRadius: 20, offset: const Offset(0, -5))],
                      ),
                      child: Row(
                        children: [
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
                              CartService.addToCart(item, quantity: quantity, size: selectedSize, addons: selectedAddons);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 12 * scale),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
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

  void _showDealDetails(BuildContext context, Pizza dealItem, double scale, bool isDark) {
    List<Pizza> selectedPizzas = [];
    List<Pizza> premiumPizzas = [];
    bool isLoading = true;

    String targetSize = dealItem.name.toLowerCase().contains('small') ? 'Small' : 'Medium';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (isLoading && premiumPizzas.isEmpty) {
              SupabaseService.getPizzas(tag: 'Premium Pizza', to: 50).then((data) {
                if (context.mounted) {
                  setModalState(() {
                    premiumPizzas = data.map((e) => Pizza.fromJson(e)).toList();
                    isLoading = false;
                  });
                }
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(24 * scale, 24 * scale, 16 * scale, 16 * scale),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dealItem.name, 
                                style: GoogleFonts.poppins(fontSize: 20 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)
                              ),
                              Text('Select any 2 Premium Pizzas ($targetSize)', 
                                style: GoogleFonts.poppins(fontSize: 12 * scale, color: AppColors.primary, fontWeight: FontWeight.w600)
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : Colors.black54),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.fromLTRB(24 * scale, 10 * scale, 24 * scale, 0),
                    child: Row(
                      children: [
                        _buildSelectionBox(selectedPizzas.isNotEmpty ? selectedPizzas[0] : null, scale, isDark, onRemove: () {
                          setModalState(() => selectedPizzas.removeAt(0));
                        }),
                        SizedBox(width: 12 * scale),
                        _buildSelectionBox(selectedPizzas.length > 1 ? selectedPizzas[1] : null, scale, isDark, onRemove: () {
                          setModalState(() => selectedPizzas.removeAt(1));
                        }),
                      ],
                    ),
                  ),

                  SizedBox(height: 20 * scale),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                    child: Text('Premium Pizzas', style: GoogleFonts.poppins(fontSize: 16 * scale, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  ),

                  Expanded(
                    child: isLoading 
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : ListView.builder(
                          padding: EdgeInsets.all(20 * scale),
                          itemCount: premiumPizzas.length,
                          itemBuilder: (context, index) {
                            final pizza = premiumPizzas[index];
                            final count = selectedPizzas.where((p) => p.id == pizza.id).length;
                            
                            return GestureDetector(
                              onTap: () {
                                if (selectedPizzas.length < 2) {
                                  setModalState(() => selectedPizzas.add(pizza));
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: EdgeInsets.only(bottom: 12 * scale),
                                padding: EdgeInsets.all(12 * scale),
                                decoration: BoxDecoration(
                                  color: count > 0 
                                    ? AppColors.primary.withAlpha(20) 
                                    : (isDark ? Colors.white.withAlpha(8) : Colors.grey[50]),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: count > 0 ? AppColors.primary : (isDark ? Colors.white10 : Colors.grey[200]!),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        pizza.imageUrl, 
                                        width: 50 * scale, height: 50 * scale, 
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Image.asset('assets/images/pizza.png', width: 50, height: 50),
                                      ),
                                    ),
                                    SizedBox(width: 14 * scale),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(pizza.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                          Text(pizza.isVeg ? 'Veg' : 'Non-Veg', style: GoogleFonts.poppins(fontSize: 11, color: pizza.isVeg ? Colors.green : Colors.red, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                    if (count > 0)
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                        child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      )
                                    else
                                      const Icon(Icons.add_circle_outline_rounded, color: Colors.grey),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  ),

                  Container(
                    padding: EdgeInsets.all(24 * scale),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(26), blurRadius: 20, offset: const Offset(0, -5))],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Deal Price', style: GoogleFonts.poppins(fontSize: 12 * scale, color: Colors.grey)),
                              Text('₹${dealItem.discountedPrice.toInt()}', style: GoogleFonts.poppins(fontSize: 24 * scale, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 160 * scale,
                          height: 54 * scale,
                          child: ElevatedButton(
                            onPressed: selectedPizzas.length == 2 ? () {
                              final List<String> addons = selectedPizzas.map((p) => p.name).toList();
                              CartService.addToCart(
                                dealItem, 
                                quantity: 1, 
                                size: targetSize, 
                                addons: addons
                              );
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Deal added to cart!'),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                )
                              );
                            } : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: isDark ? Colors.white10 : Colors.grey[300],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: Text('Add Deal', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16 * scale)),
                          ),
                        ),
                      ],
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

  Widget _buildSelectionBox(Pizza? pizza, double scale, bool isDark, {VoidCallback? onRemove}) {
    return Expanded(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 60 * scale,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(13) : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pizza != null ? AppColors.primary : (isDark ? Colors.white10 : Colors.grey[200]!)),
            ),
            child: pizza != null
              ? Row(
                  children: [
                    const SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(pizza.imageUrl, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_,__,___)=>Image.asset('assets/images/pizza.png')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(pizza.name, 
                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                )
              : Center(
                  child: Text('Select Pizza', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                ),
          ),
          if (pizza != null)
            Positioned(
              top: -8, right: -8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red, 
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(51), blurRadius: 4, offset: const Offset(0, 2))
                    ]
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
