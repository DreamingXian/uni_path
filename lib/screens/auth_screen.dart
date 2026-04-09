import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import 'home.dart';

class AuthScreen extends StatefulWidget {
  final bool showLogin;
  const AuthScreen({super.key, this.showLogin = true});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool isLogin; // State to toggle between Login and Sign Up
  bool isPasswordVisible = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _studentIdController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    isLogin = widget.showLogin; // Set initial state from constructor
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9), // Off-white background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // --- Header Section ---
              const Text(
                'UniPath',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E), // Navy/Dark Charcoal
                ),
              ),
              Text(
                'Your Campus Companion',
                style: TextStyle(fontSize: 16, color: Colors.blueGrey),
              ),
              const SizedBox(height: 40),

              // --- Segmented Toggle ---
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    _buildToggleButton(title: 'Log In', active: isLogin),
                    _buildToggleButton(title: 'Sign Up', active: !isLogin),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // --- Input Form Card ---
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    if (!isLogin) ...[
                      _buildTextField(label: 'Full Name', icon: Icons.person_outline, controller: _nameController),
                      const SizedBox(height: 16),
                      _buildTextField(label: 'Student ID', icon: Icons.badge_outlined, controller: _studentIdController),
                      const SizedBox(height: 16),
                    ],
                    _buildTextField(
                      label: 'University Email',
                      icon: Icons.email_outlined,
                      placeholder: 'yourname@student.tarumt.edu.my',
                      controller: _emailController
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Password',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      controller: _passwordController
                    ),
                    if (isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text('Forgot Password?', style: TextStyle(color: Color(0xFF3F51B5))),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // --- Primary Action Button (Purple Gradient) ---
                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: isLogin ? _handleLogin : _handleSignUp,
                        child: Text(
                          isLogin ? 'Log In' : 'Create Account',
                          style: const TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('or continue with', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),

              // --- Social Login ---
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.g_mobiledata, size: 30),
                label: const Text('Google'),
                onPressed: () {},
              ),

              const SizedBox(height: 30),

              // --- Guest Button (Dashed Blue Border) ---
              GestureDetector(
                // Inside the Guest Button GestureDetector
                  onTap: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const HomePage()),
                          (route) => false,
                    );
                  },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueAccent, style: BorderStyle.solid), // Note: Standard Flutter doesn't support dashed borders natively without a package, but we'll style it clean.
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Continue as Guest 🚀',
                    style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Inside _AuthScreenState
  final _authService = AuthService();

  void _handleSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final studentId = _studentIdController.text.trim();

    if(name == ''){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }
    if(studentId == ''){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your studentID')),
      );
      return;
    }
    if(password == ''){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password')),
      );
      return;
    }
    // Basic Validation
    if (!email.endsWith('@student.tarc.edu.my')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please use your TARUMT student email')),
      );
      return;
    }

    try {
      await _authService.signUp(
        email: email,
        password: password,
        fullName: name,
        studentId: studentId,
      );

      // On success, go to home!
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created! Please log in.')),
        );

        // Switch the UI back to the Login tab
        setState(() {
          isLogin = true;
          // Optional: Clear the password field for safety
          _passwordController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

// Inside _AuthScreenState
  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      UserModel? userProfile = await _authService.signIn(email: email, password: password);

      if (userProfile != null && mounted) {
        // Save the user globally!
        Provider.of<UserProvider>(context, listen: false).setUser(userProfile);

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login Failed: ${e.toString()}')),
        );
      }
    }
  }
  // --- Helper Widgets ---

  Widget _buildToggleButton({required String title, required bool active}) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => isLogin = title == 'Log In'),
        child: Container(
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: active ? const Color(0xFF6A1B9A) : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required String label, required IconData icon, required TextEditingController controller, String? placeholder, bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF37474F))),
        const SizedBox(height: 8),
        TextField(
          obscureText: isPassword && !isPasswordVisible,
          controller: controller,
          decoration: InputDecoration(
            hintText: placeholder,
            prefixIcon: Icon(icon),
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(isPasswordVisible ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
            )
                : null,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}