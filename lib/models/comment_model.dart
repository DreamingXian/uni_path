class CommentModel {
  final int? id;
  final int postId;
  final String userId;
  final String type; // 'text' or 'reaction'
  final String content; // The actual comment or the reaction icon/string
  final DateTime? createdAt;

  CommentModel({
    this.id,
    required this.postId,
    required this.userId,
    required this.type,
    required this.content,
    this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) => CommentModel(
    id: json['id'],
    postId: json['post_id'],
    userId: json['user_id'],
    type: json['type'] ?? 'text',
    content: json['content'] ?? '',
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'])
        : null,
  );

  Map<String, dynamic> toMap() => {
    'post_id': postId,
    'user_id': userId,
    'type': type,
    'content': content,
  };
}