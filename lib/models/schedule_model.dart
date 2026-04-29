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

  // --- NEW FIELDS FOR WEEKLY REPEATING ---
  final bool isRepeating;
  final List<int>? repeatDays;

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
    this.isRepeating = false,
    this.repeatDays,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'title': title,
      'description': description,
      'location_name': locationName,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'is_homework': isHomework,
      'label_name': labelName,
      // --- MAP NEW FIELDS TO DATABASE COLUMNS ---
      'is_repeating': isRepeating,
      'repeat_days': repeatDays,
    };
  }

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      userId: json['user_id'],
      title: json['title'] ?? '',
      description: json['description'],
      locationName: json['location_name'],
      startTime: DateTime.parse(json['start_time']),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      labelName: json['label_name'],
      isHomework: json['is_homework'] == 1 || json['is_homework'] == true,
      isRepeating: json['is_repeating'] ?? false,
      repeatDays: json['repeat_days'] != null
          ? List<int>.from(json['repeat_days'])
          : null,
    );
  }
}