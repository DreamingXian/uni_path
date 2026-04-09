class EventModel {
  final int? id;
  final String title;
  final String? description;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String status; // 'published', 'cancelled', etc.
  final String createdBy; // UUID
  final double? fees;
  final int? capacity;
  final String? eventPosterUrl;

  EventModel({
    this.id, required this.title, this.description, this.locationName,
    this.latitude, this.longitude, required this.status, required this.createdBy,
    this.fees, this.capacity, this.eventPosterUrl,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) => EventModel(
    id: json['id'],
    title: json['title'] ?? '',
    description: json['description'],
    locationName: json['location_name'],
    latitude: json['latitude']?.toDouble(),
    longitude: json['longitude']?.toDouble(),
    status: json['status'] ?? 'draft',
    createdBy: json['created_by'],
    fees: json['fees']?.toDouble(),
    capacity: json['capacity'],
    eventPosterUrl: json['event_poster_url'],
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'location_name': locationName,
    'latitude': latitude,
    'longitude': longitude,
    'status': status,
    'fees': fees,
    'capacity': capacity,
    'event_poster_url': eventPosterUrl,
  };
}