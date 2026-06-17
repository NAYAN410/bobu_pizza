class Pizza {
  final int id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final bool isAvailable;
  final double rating;
  final String tag;
  final bool isPopular;
  final bool isVeg;
  final int discount; // Discount in percentage

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
  });

  double get discountedPrice {
    if (discount > 0) {
      return price - (price * discount / 100);
    }
    return price;
  }

  factory Pizza.fromJson(Map<String, dynamic> json) {
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
    );
  }
}
