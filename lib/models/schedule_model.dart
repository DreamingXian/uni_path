class ScheduleModel {
  final int? id;
  final String? userId;
  final String title;
  final String? description;
  final String? locationName;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isHomework;
  final String? labelName;

  ScheduleModel({
    this.id,
    this.userId,
    required this.title,
    this.description,
    this.locationName,
    required this.startTime,
    this.endTime,
    this.isHomework = false,
    this.labelName,
  });

  // Convert for Supabase (Cloud)
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'location_name': locationName,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime?.toUtc().toIso8601String(),
      'is_homework': isHomework,
      'label_name': labelName,
    };
  }

  // Read from Supabase/SQLite
  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      userId: json['user_id'],
      title: json['title'] ?? '',
      description: json['description'],
      locationName: json['location_name'],
      startTime: DateTime.parse(json['start_time']).toLocal(),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']).toLocal() : null,
      // SQLite uses 1/0, Supabase uses true/false
      isHomework: json['is_homework'] == 1 || json['is_homework'] == true,
      labelName: json['label_name'],
    );
  }
}