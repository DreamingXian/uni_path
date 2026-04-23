import 'package:flutter/material.dart';
import '../../services/community_service.dart';
import '../Posts/post_detail_screen.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final CommunityService _communityService = CommunityService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _savedPosts = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
  }

  Future<void> _loadSavedPosts() async {
    setState(() => _isLoading = true);
    final posts = await _communityService.getMySavedPosts();
    if (mounted) {
      setState(() {
        _savedPosts = posts;
        _isLoading = false;
      });
    }
  }

  String _getTimeAgo(String? dateTimeString) {
    if (dateTimeString == null) return "Just now";
    final DateTime postDate = DateTime.parse(dateTimeString);
    final Duration diff = DateTime.now().difference(postDate);
    if (diff.inDays > 7) return "${postDate.day}/${postDate.month}/${postDate.year}";
    if (diff.inDays > 0) return "${diff.inDays} days ago";
    if (diff.inHours > 0) return "${diff.inHours} hours ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes} mins ago";
    return "Just now";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Saved Posts', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedPosts.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("No saved posts yet.", style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("Tap the bookmark icon in the community\nfeed to save posts here.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadSavedPosts,
        child: ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: _savedPosts.length,
          itemBuilder: (context, index) {
            final post = _savedPosts[index];

            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                    post['title'] ?? post['content'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                      "By ${post['users']['full_name']} • ${_getTimeAgo(post['created_at'])}",
                      style: const TextStyle(color: Colors.grey)
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),

                // --- NEW: Open the Detail Screen! ---
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostDetailScreen(post: post),
                    ),
                  ).then((_) => _loadSavedPosts()); // Triggers a list refresh when they press the back button
                },
              ),
            );
          },
        ),
      ),
    );
  }
}