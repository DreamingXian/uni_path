import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../providers/user_provider.dart';
import '../../services/community_service.dart';
import '../../services/file_service.dart';
import '../../models/post_model.dart';
import '../../models/post_image_model.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  final CommunityService _communityService = CommunityService();
  final FileService _fileService = FileService();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isFetchingLocation = false; // Loading state for GPS
  String _selectedCategory = 'Marketplace';
  final List<String> _categories = ['General', 'Lost & Found', 'Campus News', 'Event', 'Marketplace'];

  List<File> _selectedImages = [];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // --- NEW: Hardware GPS Logic ---
  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      // 1. Check if GPS is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      // 2. Check Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Location permissions denied.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      // 3. Get Coordinates
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      // 4. Translate Coordinates to Address
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Format the address nicely (e.g., "Setapak, Kuala Lumpur")
        setState(() {
          _locationController.text = "${place.subLocality ?? place.name}, ${place.locality}";
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  // --- Image Picker Logic (Unchanged) ---
  Future<void> _pickImages(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(imageQuality: 70);
      if (pickedFiles.isNotEmpty) {
        setState(() => _selectedImages.addAll(pickedFiles.map((file) => File(file.path))));
      }
    } else {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
      if (pickedFile != null) {
        setState(() => _selectedImages.add(File(pickedFile.path)));
      }
    }
  }

  // --- Submit Logic (Unchanged) ---
  Future<void> _submitPost() async {
    if (_titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title and Description are required!')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Provider.of<UserProvider>(context, listen: false).currentUser;
      if (user == null) throw Exception('You must be logged in to post.');

      final newPost = PostModel(
        userId: user.id,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        category: _selectedCategory,
        locationName: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        status: 'published',
      );

      final int? postId = await _communityService.insertPost(newPost);

      if (_selectedImages.isNotEmpty && postId != null) {
        List<PostImageModel> uploadedImageModels = [];
        for (int i = 0; i < _selectedImages.length; i++) {
          final String fileName = 'post_${postId}_img${i}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final String? imageUrl = await _fileService.uploadImage(
            file: _selectedImages[i], bucket: 'posts', fileName: fileName,
          );
          if (imageUrl != null) uploadedImageModels.add(PostImageModel(postId: postId, imageUrl: imageUrl));
        }
        if (uploadedImageModels.isNotEmpty) await _communityService.insertPostImages(uploadedImageModels);
      }

      if (mounted) Navigator.pop(context, true);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI Styling Helper ---
  InputDecoration _buildInputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF6A1B9A)) : null,
      filled: true,
      fillColor: Colors.grey[100], // Soft background color
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none, // Removes the harsh black line
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6A1B9A), width: 2), // Purple glow when typing
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('New Post', style: TextStyle(fontWeight: FontWeight.bold)), // Changed Title!
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: _isLoading ? null : _submitPost,
              child: _isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('POST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Dropdown (Styled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedCategory,
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.w500)))).toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val!),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Post Title
            TextField(
              controller: _titleController,
              maxLength: 50,
              decoration: _buildInputDecoration("Post Title"),
            ),
            const SizedBox(height: 12),

            // GPS Location Tag
            TextField(
              controller: _locationController,
              readOnly: true, // Prevents manual typing
              decoration: _buildInputDecoration("Tag Location", icon: Icons.location_on).copyWith(
                suffixIcon: IconButton(
                  icon: _isFetchingLocation
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                  onPressed: _getCurrentLocation,
                  tooltip: "Get Current Location",
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Post Description
            TextField(
              controller: _contentController,
              maxLines: 6,
              decoration: _buildInputDecoration("What do you want to share?"),
            ),
            const SizedBox(height: 16),

            // --- NEW: Visible Media Attach Frame ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.camera_alt, color: Color(0xFF6A1B9A)),
                        label: const Text("Camera"),
                        onPressed: () => _pickImages(ImageSource.camera),
                      ),
                      const SizedBox(width: 16),
                      TextButton.icon(
                        icon: const Icon(Icons.photo_library, color: Color(0xFF6A1B9A)),
                        label: const Text("Gallery"),
                        onPressed: () => _pickImages(ImageSource.gallery),
                      ),
                    ],
                  ),
                  if (_selectedImages.isNotEmpty) ...[
                    const Divider(),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 8, top: 8),
                                width: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(image: FileImage(_selectedImages[index]), fit: BoxFit.cover),
                                ),
                              ),
                              Positioned(
                                top: 0, right: 0,
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedImages.removeAt(index)),
                                  child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, size: 14, color: Colors.white)),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}