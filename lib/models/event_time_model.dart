class EventTimeModel {
  final int? id;
  final int eventId;
  final DateTime startDateTime;
  final DateTime endDateTime;

  EventTimeModel({this.id, required this.eventId, required this.startDateTime, required this.endDateTime});

  factory EventTimeModel.fromJson(Map<String, dynamic> json) => EventTimeModel(
    id: json['id'],
    eventId: json['event_id'],
    startDateTime: DateTime.parse(json['start_date_time']),
    endDateTime: DateTime.parse(json['end_date_time']),
  );

  Map<String, dynamic> toMap() => {
    'event_id': eventId,
    'start_date_time': startDateTime.toIso8601String(),
    'end_date_time': endDateTime.toIso8601String(),
  };
}