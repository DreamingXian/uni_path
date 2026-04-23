import 'dart:developer';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class UserService {
  final _supabase = Supabase.instance.client;

  // --- CREATE ---

  /// Creates a new profile record in the public.users table.
  /// Typically called immediately after a successful Supabase Auth sign-up.
  Future<void> insertUser(UserModel user) async {
    try {
      await _supabase.from('users').insert(user.toMap());
      log('User profile created: ${user.id}');
    } catch (e) {
      log('Error creating user profile: $e');
      rethrow;
    }
  }

  /// Upload avatar image to supabase storage and return the public URL
  Future<String?> uploadAvatar(File imageFile) async {
    try {
      final fileExtension = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_avatar.$fileExtension';
      await _supabase.storage.from('avatars').upload(fileName, imageFile);
      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      log('Error uploading avatar: $e');
      return null;
    }
  }

  // --- READ (Single Records) ---

  /// Retrieves a user profile using their unique UUID.
  Future<UserModel?> getUserById(String id) async {
    try {
      final data = await _supabase
          .from('users')
          .select()
          .eq('id', id)
          .single();
      return UserModel.fromJson(data);
    } catch (e) {
      log('Error fetching user by ID ($id): $e');
      return null;
    }
  }

  /// Retrieves a user profile by email address.
  /// Useful for checking if an account exists during onboarding.
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final data = await _supabase
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle(); // Returns null instead of throwing an error if not found

      if (data == null) return null;
      return UserModel.fromJson(data);
    } catch (e) {
      log('Error fetching user by email ($email): $e');
      return null;
    }
  }

  /// Retrieves a user profile by Student ID.
  Future<UserModel?> getUserByStudentId(String studentId) async {
    try {
      final data = await _supabase
          .from('users')
          .select()
          .eq('student_id', studentId)
          .maybeSingle();

      if (data == null) return null;
      return UserModel.fromJson(data);
    } catch (e) {
      log('Error fetching user by Student ID ($studentId): $e');
      return null;
    }
  }

  // --- READ (Multiple Records) ---

  /// Returns all users in the system.
  Future<List<UserModel>> getAllUsers() async {
    try {
      final response = await _supabase.from('users').select().order('full_name');
      return (response as List).map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      log('Error fetching all users: $e');
      return [];
    }
  }

  /// Filters users by their role (e.g., fetch only 'society' accounts for an event list).
  Future<List<UserModel>> getUsersByRole(String role) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('role', role)
          .order('full_name');
      return (response as List).map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      log('Error fetching users by role ($role): $e');
      return [];
    }
  }

  /// Searches users by name. Useful for the Community/Contact search feature.
  Future<List<UserModel>> searchUsersByName(String query) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .ilike('full_name', '%$query%') // Case-insensitive search
          .order('full_name');
      return (response as List).map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      log('Error searching users: $e');
      return [];
    }
  }

  // --- UPDATE ---

  /// Updates existing profile information.
  Future<void> updateUser(UserModel user) async {
    try {
      await _supabase
          .from('users')
          .update(user.toMap())
          .eq('id', user.id);
      log('User profile updated: ${user.id}');
    } catch (e) {
      log('Error updating user profile: $e');
      rethrow;
    }
  }
}