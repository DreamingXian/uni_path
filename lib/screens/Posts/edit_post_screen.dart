import 'package:flutter/material.dart';
import '../../services/community_service.dart';

class EditPostScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _locationController;

  final CommunityService _communityService = CommunityService();

  bool _isLoading = false;
  late String _selectedCategory;
  final List<String> _categories = ['General', 'Lost & Found', 'Campus News', 'Event', 'Marketplace'];

  // --- NEW: State variables for handling images ---
  List<dynamic> _currentImages = [];
  final List<int> _imagesToDelete = []; // Keeps track of which images the user wants to remove

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post['title'] ?? '');
    _contentController = TextEditingController(text: widget.post['content'] ?? '');

    String oldLocation = widget.post['locationName'] ?? widget.post['location_name'] ?? '';
    _locationController = TextEditingController(text: oldLocation);

    String oldCat = widget.post['category'] ?? 'General';
    _selectedCategory = _categories.contains(oldCat) ? oldCat : 'General';

    // --- NEW: Load the existing images from the post data ---
    if (widget.post['post_images'] != null) {
      _currentImages = List.from(widget.post['post_images']);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // --- NEW: Mark an image for deletion ---
  void _removeImage(int index) {
    setState(() {
      // 1. Add the database ID of this image to our deletion list
      _imagesToDelete.add(_currentImages[index]['id']);
      // 2. Remove it from the UI so the user thinks it's gone immediately
      _currentImages.removeAt(index);
    });
  }

  Future<void> _submitUpdate() async {
    if (_titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title and Description are required!')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Update the text data
      await _communityService.updatePost(
        widget.post['id'],
        _titleController.text.trim(),
        _contentController.text.trim(),
        _selectedCategory,
        _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      );

      // 2. Process Image Deletions
      if (_imagesToDelete.isNotEmpty) {
        for (int imageId in _imagesToDelete) {
          await _communityService.deletePostImage(imageId);
        }
      }

      if (mounted) Navigator.pop(context, true);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _buildInputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF6A1B9A)) : null,
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6A1B9A), width: 2)),
      // Disabled styling makes it obvious they can't type here
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Post', style: TextStyle(fontWeight: FontWeight.bold)),
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
              onPressed: _isLoading ? null : _submitUpdate,
              child: _isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
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
            TextField(controller: _titleController, maxLength: 50, decoration: _buildInputDecoration("Post Title")),
            const SizedBox(height: 12),

            // --- UPDATED: Read-Only Location Field ---
            TextField(
              controller: _locationController,
              enabled: false, // This completely locks the field
              style: const TextStyle(color: Colors.grey), // Greys out the text
              decoration: _buildInputDecoration("Location (Cannot be changed)", icon: Icons.location_on),
            ),

            const SizedBox(height: 16),
            TextField(controller: _contentController, maxLines: 6, decoration: _buildInputDecoration("Description")),

            // --- NEW: Image Gallery Preview with Delete Buttons ---
            if (_currentImages.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text("Attached Media", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _currentImages.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 8, top: 8),
                            width: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              // We use NetworkImage because these are already uploaded!
                              image: DecorationImage(
                                  image: NetworkImage(_currentImages[index]['image_url']),
                                  fit: BoxFit.cover
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0, right: 0,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.red,
                                  child: Icon(Icons.close, size: 14, color: Colors.white)
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}