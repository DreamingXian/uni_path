class TicketModel {
  final int? id;
  final String userId;
  final int eventId;
  final String status; // 'active', 'used', 'cancelled'
  final String passCode;

  TicketModel({this.id, required this.userId, required this.eventId, required this.status, required this.passCode});

  factory TicketModel.fromJson(Map<String, dynamic> json) => TicketModel(
    id: json['id'],
    userId: json['user_id'],
    eventId: json['event_id'],
    status: json['status'],
    passCode: json['pass_code'],
  );

  Map<String, dynamic> toMap() => {
    'event_id': eventId,
    'status': status,
    'pass_code': passCode,
    // Note: user_id is handled by auth.uid() in DB default
  };
}