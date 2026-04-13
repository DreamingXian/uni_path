import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_service.dart';
import '../models/user_model.dart';

class AuthService {
  final _supabase = Supabase.instance.client;
  final _userService = UserService();

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String studentId,
  }) async {
    // 1. Create the Auth User
    final AuthResponse res = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    final User? user = res.user;

    if (user != null) {
      // 2. Create the Public Profile using the ID from Auth
      UserModel newUser = UserModel(
        id: user.id,
        fullName: fullName,
        role: 'student',
        studentId: studentId,
        email: email,
      );

      await _userService.insertUser(newUser);
    }
  }

  // Inside AuthService class
  Future<UserModel?> signIn({required String email, required String password}) async {
    try {
      // 1. Authenticate with Supabase Auth
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // 2. If login is successful, fetch the full profile from public.users
      if (response.user != null) {
        return await _userService.getUserById(response.user!.id);
      }
      return null;
    } catch (e) {
      log('Login error: $e');
      rethrow;
    }
  }

  /// Signs the current user out of Supabase and clears the local session.
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      log('User signed out.');
    } catch (e) {
      log('Sign-out error: $e');
      rethrow;
    }
  }

}