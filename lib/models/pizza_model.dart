class PizzaSize {
  final String name;
  final double price;

  PizzaSize({required this.name, required this.price});

  factory PizzaSize.fromJson(Map<String, dynamic> json) {
    return PizzaSize(
      name: json['size'] ?? json['name'] ?? '',
      price: (json['price'] as num).toDouble(),
    );
  }
}

class Pizza {
  final int id;
  final String name;
  final String description;
  final double price; // Default price (for small or base)
  final String imageUrl;
  final String category;
  final bool isAvailable;
  final double rating;
  final String tag;
  final bool isPopular;
  final bool isVeg;
  final int discount;
  final List<PizzaSize>? sizes;

  Pizza({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.isAvailable,
    required this.rating,
    required this.tag,
    required this.isPopular,
    required this.isVeg,
    this.discount = 0,
    this.sizes,
  });

  double get discountedPrice {
    if (discount > 0) {
      return price - (price * discount / 100);
    }
    return price;
  }

  // Helper to get discounted price for a specific size
  double getPriceForSize(String sizeName) {
    if (sizes == null || sizes!.isEmpty) return discountedPrice;
    final size = sizes!.firstWhere(
      (s) => s.name.toLowerCase() == sizeName.toLowerCase(),
      orElse: () => PizzaSize(name: sizeName, price: price),
    );
    if (discount > 0) {
      return size.price - (size.price * discount / 100);
    }
    return size.price;
  }

  factory Pizza.fromJson(Map<String, dynamic> json) {
    var sizesList = json['sizes'] as List?;
    List<PizzaSize>? parsedSizes = sizesList?.map((e) => PizzaSize.fromJson(e)).toList();

    return Pizza(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'] ?? '',
      category: json['category'] ?? 'Veg',
      isAvailable: json['is_available'] ?? true,
      rating: (json['rating'] as num? ?? 4.5).toDouble(),
      tag: json['tag'] ?? '',
      isPopular: json['is_popular'] ?? false,
      isVeg: json['is_veg'] ?? (json['category'] == 'Veg'),
      discount: json['discount'] ?? 0,
      sizes: parsedSizes,
    );
  }
}
