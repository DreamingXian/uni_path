import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/community_service.dart';
import '../../widget/like_button.dart';
import '../../widget/comment_bottom_sheet.dart';
import 'edit_post_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final CommunityService _communityService = CommunityService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    final posts = await _communityService.getFeedPosts();
    if (mounted) {
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePost(int postId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text('This will permanently remove your post and media.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _communityService.deletePost(postId);
        await _loadPosts();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post deleted.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
      }
    }
  }

  // --- Helper 1: Calculate "Time Ago" for Layer 1 ---
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



  // --- Helper 2: Swipeable Media Gallery for Layer 3 ---
  Widget _buildMediaGallery(List images) {
    if (images.isEmpty) return const SizedBox.shrink();

    // If only one image, show it normally
    if (images.length == 1) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        width: double.infinity,
        height: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: NetworkImage(images[0]['image_url']),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // If multiple images, make them swipeable!
    return Container(
      margin: const EdgeInsets.only(top: 12),
      height: 250,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, imgIndex) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: NetworkImage(images[imgIndex]['image_url']),
                fit: BoxFit.cover,
              ),
            ),
            // A small badge to show "1/3" images
            alignment: Alignment.topRight,
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${imgIndex + 1}/${images.length}",
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_posts.isEmpty) return const Center(child: Text("No posts yet. Be the first to share!", style: TextStyle(color: Colors.grey)));

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.builder(
        itemCount: _posts.length,
        padding: const EdgeInsets.all(12.0),
        itemBuilder: (context, index) {
          final post = _posts[index];
          final List images = post['post_images'] ?? [];

          final currentUser = Provider.of<UserProvider>(context).currentUser;
          final bool isMyPost = currentUser != null && post['user_id'] == currentUser.id;

          // Standardizing map keys (handling both camelCase and snake_case variations from DB)
          final String title = post['title'] ?? '';
          final String content = post['content'] ?? '';
          final String category = post['category'] ?? 'General';
          final String? location = post['locationName'] ?? post['location_name'];
          final String authorName = post['users']?['full_name'] ?? 'Unknown Student';

          return Card(
            margin: const EdgeInsets.only(bottom: 16.0),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200), // Clean, flat border
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // --- LAYER 1: Header (User Info + ⋯ Menu) ---
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF6A1B9A).withOpacity(0.1),
                        child: Text(authorName[0].toUpperCase(), style: const TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(_getTimeAgo(post['created_at']), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz, color: Colors.grey),
                        onSelected: (value) async {
                          if (value == 'delete') _deletePost(post['id']);
                          if (value == 'report') {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post reported.')));
                          }
                          if (value == 'edit') {
                            // Open the edit screen and wait to see if they saved changes
                            final bool? didEdit = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditPostScreen(post: post),
                              ),
                            );

                            // If they hit SAVE, refresh the feed to show the updated text!
                            if (didEdit == true) {
                              _loadPosts();
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post updated successfully!')));
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          if (isMyPost) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          if (isMyPost) const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                          if (!isMyPost) const PopupMenuItem(value: 'report', child: Text('Report')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // --- LAYER 2: Post Content ---
                  if (title.isNotEmpty) ...[
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 6),
                  ],
                  if (content.isNotEmpty)
                    Text(content, style: const TextStyle(fontSize: 15, height: 1.4)),

                  // --- LAYER 3: Media ---
                  _buildMediaGallery(images),

                  const SizedBox(height: 16),

                  // --- LAYER 4: Metadata Context ---
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Category Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6A1B9A).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(category, style: const TextStyle(color: Color(0xFF6A1B9A), fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      // Location Chip (if available)
                      if (location != null && location.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on, size: 14, color: Colors.grey.shade700),
                              const SizedBox(width: 4),
                              Text(location, style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(height: 20),
                  ),

                  // --- LAYER 5: Interaction Bar ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          LikeButton(postId: post['id']),
                          const SizedBox(width: 20),
                          // Comment Button
                          // Comment Button
                          InkWell(
                            onTap: () {
                              // --- NEW: Trigger the Slide-up Sheet ---
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true, // Crucial for the keyboard pushing the UI up
                                backgroundColor: Colors.transparent, // Makes the rounded top corners look nice
                                builder: (context) => CommentBottomSheet(postId: post['id']),
                              );
                            },
                            child: Row(
                              children: [
                                Icon(Icons.chat_bubble_outline, color: Colors.grey.shade600, size: 22),
                                const SizedBox(width: 6),
                                const Text('Reply', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)), // Changed "0" to "Reply" to make it simple
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Save Bookmark Icon
                      IconButton(
                        icon: Icon(Icons.bookmark_border, color: Colors.grey.shade600),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to bookmarks!')));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}