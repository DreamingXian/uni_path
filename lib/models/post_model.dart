class PostModel {
  final int? id;
  final String userId;
  final String? title;
  final String content;
  final String? category;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
  final String status; // 'published', 'archived', etc.

  PostModel({
    this.id,
    required this.userId,
    this.title,
    required this.content,
    this.category,
    this.locationName,
    this.latitude,
    this.longitude,
    this.createdAt,
    required this.status,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) => PostModel(
    id: json['id'],
    userId: json['user_id'],
    title: json['title'],
    content: json['content'] ?? '',
    category: json['category'],
    locationName: json['location_name'],
    latitude: json['latitude']?.toDouble(),
    longitude: json['longitude']?.toDouble(),
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'])
        : null,
    status: json['status'] ?? 'published',
  );

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'title': title,
    'content': content,
    'category': category,
    'location_name': locationName,
    'latitude': latitude,
    'longitude': longitude,
    'status': status,
  };
}