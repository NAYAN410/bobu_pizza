class BannerModel {
  final int id;
  final String imageUrl;

  BannerModel({
    required this.id,
    required this.imageUrl,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id'],
      imageUrl: json['image_url'] ?? '',
    );
  }
}
