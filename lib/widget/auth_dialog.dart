import 'package:flutter/material.dart';
import '../screens/auth_screen.dart';

/// A reusable function to trigger the Login Required popup anywhere in the app
Future<void> showLoginRequiredDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Login Required'),
        content: const Text('Please log in to proceed with this action.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Just close the dialog
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6A1B9A))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () {
              Navigator.pop(context); // Close the dialog
              // Send them to the Auth Screen!
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AuthScreen(showLogin: true)),
              );
            },
            child: const Text('Login'),
          ),
        ],
      );
    },
  );
}