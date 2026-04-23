import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _userService = UserService();
  final _authService = AuthService();
  final _picker = ImagePicker();

  bool _isEditingProfile = false;
  bool _isChangingPassword = false;
  bool _isLoading = false;

  final TextEditingController _fullNameController = TextEditingController();
  File? _avatarFile;

  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize standard fields securely after first build frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<UserProvider>(context, listen: false).currentUser;
      if (user != null) {
        _fullNameController.text = user.fullName;
      }
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ─── IMAGE PICKING ───

  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Change Avatar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEDE7F6),
                  child: Icon(Icons.photo_library_outlined, color: Color(0xFF6A1B9A)),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickFromSource(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.camera_alt_outlined, color: Colors.green),
                ),
                title: const Text('Take a Photo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickFromSource(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromSource(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 80);
      if (pickedFile != null) {
        setState(() {
          _avatarFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error picking image')));
      }
    }
  }

  // ─── PROFILE UPDATE ───

  Future<void> _handleSaveProfile(UserModel currentUser) async {
    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Full name cannot be empty.')));
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Profile'),
        content: const Text('Are you sure you want to save these changes?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      String? newAvatarUrl = currentUser.avatarUrl;

      if (_avatarFile != null) {
        final url = await _userService.uploadAvatar(_avatarFile!);
        if (url != null) {
          newAvatarUrl = url;
        } else {
          throw Exception("Failed to upload avatar image.");
        }
      }

      // Create updated user model
      final updatedUser = UserModel(
        id: currentUser.id,
        email: currentUser.email,
        fullName: _fullNameController.text.trim(),
        role: currentUser.role,
        studentId: currentUser.studentId,
        avatarUrl: newAvatarUrl,
        createdAt: currentUser.createdAt,
      );

      // Update Database
      await _userService.updateUser(updatedUser);

      // Update Global State immediately
      if (mounted) {
        Provider.of<UserProvider>(context, listen: false).setUser(updatedUser);
        setState(() {
          _isEditingProfile = false;
          _isLoading = false;
          _avatarFile = null; // Clear picked file so we rely on network image again
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _cancelProfileEdit(UserModel user) {
    setState(() {
      _isEditingProfile = false;
      _fullNameController.text = user.fullName;
      _avatarFile = null;
    });
  }

  // ─── PASSWORD UPDATE ───

  Future<void> _handleSavePassword(UserModel currentUser) async {
    final currentPass = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New password must be at least 6 characters long.'), backgroundColor: Colors.red));
      return;
    }
    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New password and confirm password do not match.'), backgroundColor: Colors.red));
      return;
    }
    if (currentPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current password is required.'), backgroundColor: Colors.red));
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: const Text('Are you sure you want to securely change your password?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // 1. Validate Current Password implicitly by attempting a background re-authentication
      try {
        await _authService.signIn(email: currentUser.email, password: currentPass);
      } catch (authError) {
        throw Exception("Current password is incorrect.");
      }

      // 2. Auth successful, proceed to update the underlying Supabase Auth user password
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPass));

      if (mounted) {
        setState(() {
          _isChangingPassword = false;
          _isLoading = false;
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
      }
    }
  }

  void _cancelPasswordEdit() {
    setState(() {
      _isChangingPassword = false;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
  }

  // ─── UI BUILDERS ───

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).currentUser;

    if (user == null) {
      // Fallback UI in case intercept missed it
      return const Scaffold(body: Center(child: Text("Please log in to view your profile.")));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('User Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // ── IDENTITY CARD ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    children: [
                      // Avatar
                      GestureDetector(
                        onTap: _isEditingProfile ? _showImageSourceSheet : null,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: _avatarFile != null
                                  ? FileImage(_avatarFile!) as ImageProvider
                                  : (user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null),
                              child: (_avatarFile == null && user.avatarUrl == null)
                                  ? const Icon(Icons.person, size: 50, color: Colors.grey)
                                  : null,
                            ),
                            if (_isEditingProfile)
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Color(0xFF6A1B9A), shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Name
                      if (_isEditingProfile)
                        TextFormField(
                          controller: _fullNameController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: "Full Name",
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        )
                      else
                        Text(
                          user.fullName,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                        ),
                      
                      const SizedBox(height: 8),
                      // Immutable Details
                      Text(user.email, style: const TextStyle(fontSize: 16, color: Colors.black54)),
                      if (user.studentId != null && user.studentId!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Student ID: ${user.studentId}', style: const TextStyle(fontSize: 14, color: Colors.black45)),
                      ],
                      const SizedBox(height: 24),

                      // Profile Actions
                      if (_isEditingProfile)
                        Row(
                          children: [
                            Expanded(child: OutlinedButton(onPressed: () => _cancelProfileEdit(user), child: const Text('Cancel'))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                onPressed: () => _handleSaveProfile(user), 
                                child: const Text('Save'),
                              ),
                            ),
                          ],
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Edit Profile'),
                            onPressed: () => setState(() {
                              _isEditingProfile = true;
                              _isChangingPassword = false; // mutually exclusive forms for cleanliness
                            }),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6A1B9A),
                              side: const BorderSide(color: Color(0xFF6A1B9A)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),

                // ── SECURITY SECTION ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.security, color: Color(0xFF1A237E)),
                          SizedBox(width: 10),
                          Text("Security Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (_isChangingPassword) ...[
                        TextFormField(
                          controller: _currentPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: "Current Password",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: "New Password",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.lock_reset),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: "Confirm New Password",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.check_circle_outline),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: OutlinedButton(onPressed: _cancelPasswordEdit, child: const Text('Cancel'))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                onPressed: () => _handleSavePassword(user), 
                                child: const Text('Confirm'),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.password, size: 18),
                            label: const Text('Change Password'),
                            onPressed: () => setState(() {
                              _isChangingPassword = true;
                              _isEditingProfile = false;
                            }),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              foregroundColor: Colors.black87,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A))),
            ),
        ],
      ),
    );
  }
}