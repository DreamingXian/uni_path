class EventTagModel {
  final int eventId;
  final int tagId;

  EventTagModel({
    required this.eventId,
    required this.tagId,
  });

  factory EventTagModel.fromJson(Map<String, dynamic> json) => EventTagModel(
    eventId: json['event_id'],
    tagId: json['tag_id'],
  );

  Map<String, dynamic> toMap() => {
    'event_id': eventId,
    'tag_id': tagId,
  };
}