class AddressModel {
  final String id;
  final String userId;
  final String title;
  final String fullAddress;
  final String landmark;
  final String phoneNumber;
  final DateTime createdAt;

  AddressModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.fullAddress,
    required this.landmark,
    required this.phoneNumber,
    required this.createdAt,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'] ?? '',
      fullAddress: json['full_address'] ?? '',
      landmark: json['landmark'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'full_address': fullAddress,
      'landmark': landmark,
      'phone_number': phoneNumber,
    };
  }
}
