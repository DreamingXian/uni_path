class ReminderModel {
  final int? id;
  final int scheduleId;
  final DateTime remindAt;

  ReminderModel({
    this.id,
    required this.scheduleId,
    required this.remindAt,
  });

  factory ReminderModel.fromJson(Map<String, dynamic> json) => ReminderModel(
    id: json['id'],
    scheduleId: json['schedule_id'],
    remindAt: DateTime.parse(json['remind_at']),
  );

  Map<String, dynamic> toMap() => {
    'schedule_id': scheduleId,
    'remind_at': remindAt.toIso8601String(),
  };
}