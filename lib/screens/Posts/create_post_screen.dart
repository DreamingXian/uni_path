import 'dart:io'; // Needed to handle physical files
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart'; // The new package

import '../../providers/user_provider.dart';
import '../../services/community_service.dart';
import '../../services/file_service.dart'; // Your teammate's upload tool
import '../../models/post_model.dart';
import '../../models/post_image_model.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final CommunityService _communityService = CommunityService();
  final FileService _fileService = FileService(); // Tool to upload files
  final ImagePicker _picker = ImagePicker();      // Tool to open camera

  bool _isLoading = false;
  String _selectedCategory = 'General';
  final List<String> _categories = ['General', 'Lost & Found', 'Campus News', 'Event'];

  File? _selectedImage; // This will hold the photo the user takes

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  // --- NEW: Function to open Camera or Gallery ---
  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 70); // Compress slightly

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path); // Save the picture to our state
      });
    }
  }

  // --- UPDATED: Submit function to handle images ---
  Future<void> _submitPost() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write something first!')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Provider.of<UserProvider>(context, listen: false).currentUser;
      if (user == null) throw Exception('You must be logged in to post.');

      final newPost = PostModel(
        userId: user.id,
        content: _contentController.text.trim(),
        category: _selectedCategory,
        status: 'published',
      );

      // 1. Save the text post first and get its new ID
      final int? postId = await _communityService.insertPost(newPost);

      // 2. If they selected an image, upload it now
      if (_selectedImage != null && postId != null) {
        // Create a unique file name using the time
        final String fileName = 'post_${postId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        // Upload to Supabase Storage
        final String? imageUrl = await _fileService.uploadImage(
          file: _selectedImage!,
          bucket: 'posts', // Assuming your team named the storage bucket 'post_images'
          fileName: fileName,
        );

        // 3. Link the uploaded image URL to the post in the database
        if (imageUrl != null) {
          final postImage = PostImageModel(postId: postId, imageUrl: imageUrl);
          await _communityService.insertPostImages([postImage]);
        }else {
          // --- NEW: Throw an error if the upload fails! ---
          throw Exception("Post text saved, but the image upload was blocked by Supabase.");
        }
      }

      if (mounted) Navigator.pop(context, true);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitPost,
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator())
                : const Text('POST', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              items: _categories.map((category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
              onChanged: (newValue) => setState(() => _selectedCategory = newValue!),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                decoration: const InputDecoration(hintText: "What's happening on campus?", border: InputBorder.none),
              ),
            ),

            // --- NEW: Image Preview Box ---
            if (_selectedImage != null)
              Stack(
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover),
                    ),
                  ),
                  // 'X' button to remove the picture
                  Positioned(
                    top: 8, right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.white, size: 30),
                      onPressed: () => setState(() => _selectedImage = null),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      // --- NEW: Camera & Gallery Buttons ---
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.camera_alt, color: Color(0xFF6A1B9A), size: 30),
                onPressed: () => _pickImage(ImageSource.camera),
              ),
              IconButton(
                icon: const Icon(Icons.photo_library, color: Color(0xFF6A1B9A), size: 30),
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}