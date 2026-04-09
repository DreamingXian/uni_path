import 'package:flutter/material.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  // Set the user and notify the whole app to refresh
  void setUser(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }

  // Clear user data on logout
  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}