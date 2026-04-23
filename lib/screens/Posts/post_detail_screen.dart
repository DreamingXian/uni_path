import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../../services/community_service.dart';
import '../../widget/like_button.dart';
import '../../widget/comment_bottom_sheet.dart';
import '../../widget/auth_dialog.dart';

class PostDetailScreen extends StatefulWidget {
  // We pass the full post data from the previous screen into this one
  final Map<String, dynamic> post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final CommunityService _communityService = CommunityService();
  bool _isSaved = true; // Since they opened it from the Saved list, we assume it's saved

  @override
  void initState() {
    super.initState();
    _checkIfSaved();
  }

  // Double check the database to ensure the bookmark icon color is correct
  Future<void> _checkIfSaved() async {
    final savedIds = await _communityService.getSavedPostIds();
    if (mounted) {
      setState(() {
        _isSaved = savedIds.contains(widget.post['id']);
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

  Widget _buildMediaGallery(List images) {
    if (images.isEmpty) return const SizedBox.shrink();
    if (images.length == 1) {
      return Container(
        margin: const EdgeInsets.only(top: 12), width: double.infinity, height: 250,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: NetworkImage(images[0]['image_url']), fit: BoxFit.cover)),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 12), height: 250,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, imgIndex) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: NetworkImage(images[imgIndex]['image_url']), fit: BoxFit.cover)),
            alignment: Alignment.topRight,
            child: Container(
              margin: const EdgeInsets.all(8), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
              child: Text("${imgIndex + 1}/${images.length}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final String title = post['title'] ?? '';
    final String content = post['content'] ?? '';
    final String category = post['category'] ?? 'General';
    final String? location = post['locationName'] ?? post['location_name'];
    final String authorName = post['users']?['full_name'] ?? 'Unknown Student';
    final List images = post['post_images'] ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Post', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      // We use SingleChildScrollView so the post can scroll if the text is very long
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Layer 1: Header
            Row(
              children: [
                CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF6A1B9A).withOpacity(0.1),
                    child: Text(authorName[0].toUpperCase(), style: const TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.bold, fontSize: 20))
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(_getTimeAgo(post['created_at']), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Layer 2 & 3: Content & Media
            if (title.isNotEmpty) ...[Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)), const SizedBox(height: 12)],
            if (content.isNotEmpty) Text(content, style: const TextStyle(fontSize: 16, height: 1.5)),
            _buildMediaGallery(images),
            const SizedBox(height: 20),

            // Layer 4: Metadata Context
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF6A1B9A).withOpacity(0.08), borderRadius: BorderRadius.circular(20)), child: Text(category, style: const TextStyle(color: Color(0xFF6A1B9A), fontSize: 13, fontWeight: FontWeight.bold))),
                if (location != null && location.isNotEmpty)
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.location_on, size: 16, color: Colors.grey.shade700), const SizedBox(width: 4), Text(location, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500))])),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider(height: 30)),

            // Layer 5: Interaction Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    LikeButton(postId: post['id']),
                    const SizedBox(width: 24),
                    InkWell(
                      onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => CommentBottomSheet(postId: post['id'])),
                      child: Row(children: [Icon(Icons.chat_bubble_outline, color: Colors.grey.shade600, size: 24), const SizedBox(width: 6), const Text('Reply', style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.bold))]),
                    ),
                  ],
                ),
                // The Bookmark Icon inside the Detail Screen
                IconButton(
                  icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, color: _isSaved ? const Color(0xFF6A1B9A) : Colors.grey.shade600, size: 28),
                  onPressed: () async {
                    final currentUser = Provider.of<UserProvider>(context, listen: false).currentUser;
                    if (currentUser == null) {
                      showLoginRequiredDialog(context);
                      return;
                    }
                    final int pId = post['id'];
                    final bool currentlySaved = _isSaved;

                    setState(() => _isSaved = !_isSaved); // Optimistic UI Update

                    try {
                      await _communityService.toggleSavedPost(pId, currentlySaved);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(currentlySaved ? 'Removed from saved' : 'Post saved'), duration: const Duration(seconds: 1)));
                      }
                    } catch (e) {
                      if (mounted) setState(() => _isSaved = currentlySaved); // Rollback on error
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}