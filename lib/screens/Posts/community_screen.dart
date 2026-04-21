import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../../services/community_service.dart';
import '../../widget/like_button.dart';
import '../../widget/comment_bottom_sheet.dart';
import 'edit_post_screen.dart';
import '../../widget/auth_dialog.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final CommunityService _communityService = CommunityService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _posts = [];

  // --- NEW: Search Controller ---
  final TextEditingController _searchController = TextEditingController();

  // --- NEW: Filter & Sort State Variables ---
  String _selectedCategory = 'All';
  String _selectedTimeRange = 'All time';
  String _selectedSort = 'Latest';

  final List<String> _categories = ['All', 'General', 'Lost & Found', 'Campus News', 'Event', 'Marketplace'];
  final List<String> _timeRanges = ['All time', 'Today', 'This week', 'This month'];
  final List<String> _sortOptions = ['Latest', 'Most liked', 'Most commented'];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  // --- UPGRADED: Load posts with active filters ---
  Future<void> _loadPosts() async {
    if (_posts.isEmpty) setState(() => _isLoading = true);
    try {
      final posts = await _communityService.getFeedPosts(
        category: _selectedCategory,
        timeRange: _selectedTimeRange,
        sortBy: _selectedSort,
        searchQuery: _searchController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- NEW: Filter Bottom Sheet ---
  void _showFilterSheet() {
    // Temporary variables to hold state inside the modal before applying
    String tempCategory = _selectedCategory;
    String tempTimeRange = _selectedTimeRange;

    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return StatefulBuilder( // Needed to update UI inside the modal
              builder: (context, setModalState) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Filter Posts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),

                      const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _categories.map((cat) => ChoiceChip(
                          label: Text(cat),
                          selected: tempCategory == cat,
                          selectedColor: const Color(0xFF6A1B9A).withOpacity(0.2),
                          onSelected: (selected) => setModalState(() => tempCategory = cat),
                        )).toList(),
                      ),

                      const SizedBox(height: 20),
                      const Text('Time Range', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _timeRanges.map((time) => ChoiceChip(
                          label: Text(time),
                          selected: tempTimeRange == time,
                          selectedColor: const Color(0xFF6A1B9A).withOpacity(0.2),
                          onSelected: (selected) => setModalState(() => tempTimeRange = time),
                        )).toList(),
                      ),

                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedCategory = 'All';
                                  _selectedTimeRange = 'All time';
                                });
                                Navigator.pop(context);
                                _loadPosts();
                              },
                              child: const Text('Reset'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A)),
                              onPressed: () {
                                setState(() {
                                  _selectedCategory = tempCategory;
                                  _selectedTimeRange = tempTimeRange;
                                });
                                Navigator.pop(context);
                                _loadPosts();
                              },
                              child: const Text('Apply', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                );
              }
          );
        }
    );
  }

  // --- NEW: Sort Bottom Sheet ---
  void _showSortSheet() {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sort By', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ..._sortOptions.map((option) => ListTile(
                  title: Text(option),
                  trailing: _selectedSort == option ? const Icon(Icons.check, color: Color(0xFF6A1B9A)) : null,
                  onTap: () {
                    setState(() => _selectedSort = option);
                    Navigator.pop(context);
                    _loadPosts();
                  },
                )),
              ],
            ),
          );
        }
    );
  }

  // ... KEEP your existing _deletePost, _getTimeAgo, and _buildMediaGallery functions here ...
  // (Paste them from your previous community_screen.dart file to maintain functionality)
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

  Future<void> _deletePost(int postId) async {
    // ... your existing delete logic ...
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- Sticky Header: Filter & Sort Bar ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- NEW: Real-time Search Bar ---
              TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {}); // Refreshes UI so the 'Clear' X button appears
                  _loadPosts();    // Instantly searches the database!
                },
                decoration: InputDecoration(
                  hintText: "Search posts by title...",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  // Show a clear button only if they have typed something
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                      _loadPosts(); // Reload full feed when cleared
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Filter'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                      onPressed: _showFilterSheet,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.sort, size: 18),
                      label: Text('Sort: $_selectedSort'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                      onPressed: _showSortSheet,
                    ),
                  ),
                ],
              ),
              // Active Filter Indicator (Only shows if filters are active)
              if (_selectedCategory != 'All' || _selectedTimeRange != 'All time')
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "Active: ${_selectedCategory != 'All' ? _selectedCategory : ''} ${_selectedCategory != 'All' && _selectedTimeRange != 'All time' ? '|' : ''} ${_selectedTimeRange != 'All time' ? _selectedTimeRange : ''}",
                    style: const TextStyle(color: Color(0xFF6A1B9A), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),

        // --- Post Feed ---
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _posts.isEmpty
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text("No posts found. Try adjusting filters.", style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          )
              : RefreshIndicator(
            onRefresh: _loadPosts,
            child: ListView.builder(
              itemCount: _posts.length,
              padding: const EdgeInsets.all(12.0),
              itemBuilder: (context, index) {
                final post = _posts[index];
                final List images = post['post_images'] ?? [];

                final currentUser = Provider.of<UserProvider>(context).currentUser;
                final bool isMyPost = currentUser != null && post['user_id'] == currentUser.id;

                final String title = post['title'] ?? '';
                final String content = post['content'] ?? '';
                final String category = post['category'] ?? 'General';
                final String? location = post['locationName'] ?? post['location_name'];
                final String authorName = post['users']?['full_name'] ?? 'Unknown Student';

                return Card(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Layer 1: Header
                        Row(
                          children: [
                            CircleAvatar(backgroundColor: const Color(0xFF6A1B9A).withOpacity(0.1), child: Text(authorName[0].toUpperCase(), style: const TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.bold))),
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
                                if (value == 'edit') {
                                  final bool? didEdit = await Navigator.push(context, MaterialPageRoute(builder: (context) => EditPostScreen(post: post)));
                                  if (didEdit == true) _loadPosts();
                                }
                              },
                              itemBuilder: (context) => [
                                if (isMyPost) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                if (isMyPost) const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Layer 2 & 3: Content & Media
                        if (title.isNotEmpty) ...[Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(height: 6)],
                        if (content.isNotEmpty) Text(content, style: const TextStyle(fontSize: 15, height: 1.4)),
                        _buildMediaGallery(images),
                        const SizedBox(height: 16),

                        // Layer 4: Metadata Context
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF6A1B9A).withOpacity(0.08), borderRadius: BorderRadius.circular(20)), child: Text(category, style: const TextStyle(color: Color(0xFF6A1B9A), fontSize: 12, fontWeight: FontWeight.bold))),
                            if (location != null && location.isNotEmpty)
                              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.location_on, size: 14, color: Colors.grey.shade700), const SizedBox(width: 4), Text(location, style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w500))])),
                          ],
                        ),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider(height: 20)),

                        // Layer 5: Interaction Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                LikeButton(postId: post['id']),
                                const SizedBox(width: 20),
                                InkWell(
                                  onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => CommentBottomSheet(postId: post['id'])),
                                  child: Row(children: [Icon(Icons.chat_bubble_outline, color: Colors.grey.shade600, size: 22), const SizedBox(width: 6), const Text('Reply', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))]),
                                ),
                              ],
                            ),
                            IconButton(icon: Icon(Icons.bookmark_border, color: Colors.grey.shade600), onPressed: () {
                              if (currentUser == null) {
                                showLoginRequiredDialog(context);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to bookmarks!')));
                              }
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}