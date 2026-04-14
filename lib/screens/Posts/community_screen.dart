import 'package:flutter/material.dart';
import '../../services/community_service.dart';
import '../../widget/like_button.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  // 1. Connect to the service your team built
  final CommunityService _communityService = CommunityService();

  // 2. Variables to hold our screen's state
  bool _isLoading = true;
  List<Map<String, dynamic>> _posts = [];

  // 3. This runs automatically when the screen first opens
  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  // 4. The function to fetch data from Supabase
  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);

    // Fetch posts using your teammate's pre-written function
    final posts = await _communityService.getFeedPosts();

    setState(() {
      _posts = posts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading spinner while fetching data
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show a friendly message if the database is empty
    if (_posts.isEmpty) {
      return const Center(
        child: Text(
          "No posts yet. Be the first to share!",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    // Build a scrollable list of posts with Pull-to-Refresh
    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.builder(
        itemCount: _posts.length,
        padding: const EdgeInsets.all(8.0),
        itemBuilder: (context, index) {
          final post = _posts[index];

          // Check if this post has any images attached in the database
          final List images = post['post_images'] ?? [];
          final bool hasImage = images.isNotEmpty;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            clipBehavior: Clip.antiAlias, // Keeps image inside the rounded corners
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: Chip(
                    label: Text(post['category'] ?? 'General', style: const TextStyle(fontSize: 10)),
                  ),
                  title: Text(
                    post['content'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "Posted by ${post['users']['full_name']}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),

                // --- NEW: Display the image if one exists ---
                if (hasImage)
                  Image.network(
                    images[0]['image_url'], // Get the URL from the database join
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover, // Crops the image to fit the box perfectly
                  ),

                // --- Our Interaction Bar ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      LikeButton(postId: post['id']),
                      const SizedBox(width: 24),
                      const Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 20),
                      const SizedBox(width: 6),
                      const Text('0', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}