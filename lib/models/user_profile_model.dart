class UserProfileModel {
  final String id;
  final String fullName;
  final String phone;
  final bool isAdmin;
  final DateTime updatedAt;

  UserProfileModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.isAdmin,
    required this.updatedAt,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'],
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      isAdmin: json['is_admin'] ?? false,
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'phone': phone,
      'is_admin': isAdmin,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
