class PostImageModel {
  final int? id;
  final int postId;
  final String imageUrl;

  PostImageModel({this.id, required this.postId, required this.imageUrl});

  factory PostImageModel.fromJson(Map<String, dynamic> json) => PostImageModel(
    id: json['id'],
    postId: json['post_id'],
    imageUrl: json['image_url'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'post_id': postId,
    'image_url': imageUrl,
  };
}