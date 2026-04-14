class TagModel {
  final int? id;
  final String name;

  TagModel({
    this.id,
    required this.name,
  });

  factory TagModel.fromJson(Map<String, dynamic> json) => TagModel(
    id: json['id'],
    name: json['name'],
  );

  Map<String, dynamic> toMap() => {
    'name': name,
  };
}