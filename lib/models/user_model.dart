class UserModel {
  final String id; // UUID from Supabase Auth
  final String fullName;
  final String role;
  final String? studentId; // Nullable for Society accounts
  final String email;
  final String? avatarUrl;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.fullName,
    required this.role,
    this.studentId,
    required this.email,
    this.avatarUrl,
    this.createdAt,
  });

  // Convert Map (JSON) from Supabase to Dart Object
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      fullName: json['full_name'] ?? '',
      role: json['role'] ?? 'student',
      studentId: json['student_id'],
      email: json['email'] ?? '',
      avatarUrl: json['avatar_url'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  // Convert Dart Object to Map (JSON) for Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'role': role,
      'student_id': studentId,
      'email': email,
      'avatar_url': avatarUrl,
    };
  }
}