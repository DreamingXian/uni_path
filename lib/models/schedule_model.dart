class ScheduleModel {
  final int? id;
  final String? userId;
  final String? title;
  final String? description;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime? createdAt;
  // New Fields added for filtering and UI labels
  final String? labelName;
  final String? labelColor;

  ScheduleModel({
    this.id,
    this.userId,
    this.title,
    this.description,
    this.locationName,
    this.latitude,
    this.longitude,
    required this.startTime,
    required this.endTime,
    this.createdAt,
    this.labelName,
    this.labelColor,
  });

  factory ScheduleModel.fromJson(Map<String, dynamic> json) => ScheduleModel(
    id: json['id'],
    userId: json['user_id'],
    title: json['title'],
    description: json['description'],
    locationName: json['location_name'],
    latitude: json['latitude']?.toDouble(),
    longitude: json['longitude']?.toDouble(),
    startTime: DateTime.parse(json['start_time']),
    endTime: DateTime.parse(json['end_time']),
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'])
        : null,
    labelName: json['label_name'],
    labelColor: json['label_color'],
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'location_name': locationName,
    'latitude': latitude,
    'longitude': longitude,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime.toIso8601String(),
    'label_name': labelName,
    'label_color': labelColor,
    // user_id handled by auth.uid() default in DB
  };
}