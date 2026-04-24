import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import 'saved_posts_screen.dart';

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
              Text(
                'change_avatar'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEDE7F6),
                  child: Icon(Icons.photo_library_outlined, color: Color(0xFF6A1B9A)),
                ),
                title: Text('choose_gallery'.tr()),
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
                title: Text('take_photo'.tr()),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('err_picking_image'.tr())));
      }
    }
  }

  // ─── PROFILE UPDATE ───
  Future<void> _handleSaveProfile(UserModel currentUser) async {
    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('err_fullname_empty'.tr())));
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('update_profile'.tr()),
        content: Text('confirm_save_changes'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('cancel'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('confirm'.tr()),
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

      final updatedUser = UserModel(
        id: currentUser.id,
        email: currentUser.email,
        fullName: _fullNameController.text.trim(),
        role: currentUser.role,
        studentId: currentUser.studentId,
        avatarUrl: newAvatarUrl,
        createdAt: currentUser.createdAt,
      );

      await _userService.updateUser(updatedUser);

      if (mounted) {
        Provider.of<UserProvider>(context, listen: false).setUser(updatedUser);
        setState(() {
          _isEditingProfile = false;
          _isLoading = false;
          _avatarFile = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('profile_updated_success'.tr()), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${'error_prefix'.tr()}$e'), backgroundColor: Colors.red));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('err_pass_length'.tr()), backgroundColor: Colors.red));
      return;
    }
    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('err_pass_match'.tr()), backgroundColor: Colors.red));
      return;
    }
    if (currentPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('err_current_pass'.tr()), backgroundColor: Colors.red));
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('change_password'.tr()),
        content: Text('confirm_change_password'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('cancel'.tr())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      try {
        await _authService.signIn(email: currentUser.email, password: currentPass);
      } catch (authError) {
        throw Exception('incorrect_password'.tr());
      }

      await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPass));

      if (mounted) {
        setState(() {
          _isChangingPassword = false;
          _isLoading = false;
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('pass_changed_success'.tr()), backgroundColor: Colors.green));
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
      return Scaffold(body: Center(child: Text('please_login'.tr())));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('user_profile'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

                      if (_isEditingProfile)
                        TextFormField(
                          controller: _fullNameController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'full_name'.tr(),
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
                      Text(user.email, style: const TextStyle(fontSize: 16, color: Colors.black54)),
                      if (user.studentId != null && user.studentId!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('${'student_id_prefix'.tr()}${user.studentId}', style: const TextStyle(fontSize: 14, color: Colors.black45)),
                      ],
                      const SizedBox(height: 24),

                      if (_isEditingProfile)
                        Row(
                          children: [
                            Expanded(child: OutlinedButton(onPressed: () => _cancelProfileEdit(user), child: Text('cancel'.tr()))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                onPressed: () => _handleSaveProfile(user),
                                child: Text('save'.tr()),
                              ),
                            ),
                          ],
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.edit, size: 18),
                            label: Text('edit_profile'.tr()),
                            onPressed: () => setState(() {
                              _isEditingProfile = true;
                              _isChangingPassword = false;
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

                const SizedBox(height: 24),

                // ── ACTIVITY SECTION (MERGED SAVED POSTS) ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                          shape: BoxShape.circle
                      ),
                      child: const Icon(Icons.bookmark, color: Color(0xFF6A1B9A)),
                    ),
                    title: Text('saved_posts'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A237E))),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedPostsScreen()));
                    },
                  ),
                ),

                const SizedBox(height: 24),

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
                      Row(
                        children: [
                          const Icon(Icons.security, color: Color(0xFF1A237E)),
                          const SizedBox(width: 10),
                          Text('security_settings'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (_isChangingPassword) ...[
                        TextFormField(
                          controller: _currentPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'current_password'.tr(),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'new_password'.tr(),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.lock_reset),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'confirm_new_password'.tr(),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.check_circle_outline),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: OutlinedButton(onPressed: _cancelPasswordEdit, child: Text('cancel'.tr()))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                onPressed: () => _handleSavePassword(user),
                                child: Text('confirm'.tr()),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.password, size: 18),
                            label: Text('change_password'.tr()),
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
              color: Colors.black.withValues(alpha: 0.3), // Changed .withValues() to standard .withOpacity() to avoid potential version errors
              child: const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A))),
            ),
        ],
      ),
    );
  }
}