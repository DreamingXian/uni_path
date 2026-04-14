import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';
import '../models/post_image_model.dart';
import '../models/comment_model.dart';

class CommunityService {
  final _supabase = Supabase.instance.client;

  // --- POST OPERATIONS ---

  /// Creates a new post and returns the generated ID.
  Future<int?> insertPost(PostModel post) async {
    try {
      final response = await _supabase
          .from('posts')
          .insert(post.toMap())
          .select()
          .single();
      log('Post created with ID: ${response['id']}');
      return response['id'] as int;
    } catch (e) {
      log('Error creating post: $e');
      rethrow;
    }
  }

  /// Fetches all published posts.
  /// Includes author profile and images in a single call using joins.
  Future<List<Map<String, dynamic>>> getFeedPosts() async {
    try {
      // Joining with 'users' to get names/avatars and 'post_images' for the gallery
      final response = await _supabase
          .from('posts')
          .select('*, users!inner(*), post_images(*)')
          .eq('status', 'published')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      log('Error fetching feed: $e');
      return [];
    }
  }

  /// Specific fetch for Lost & Found category.
  Future<List<Map<String, dynamic>>> getPostsByCategory(String category) async {
    try {
      final response = await _supabase
          .from('posts')
          .select('*, users!inner(*), post_images(*)')
          .eq('category', category)
          .eq('status', 'published')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      log('Error fetching posts by category: $e');
      return [];
    }
  }
/*
  Future<void> updatePost(PostModel post) async {
    try {
      await _supabase.from('posts').update(post.toMap()).eq('id', post.id!);
    } catch (e) {
      log('Error updating post: $e');
      rethrow;
    }
  }
*/
  // --- NEW: Function to update an existing post ---
  Future<void> updatePost(int postId, String title, String content, String category, String? locationName) async {
    final response = await _supabase.from('posts').update({
      'title': title,
      'content': content,
      'category': category,
      'location_name': locationName,
    }).eq('id', postId); // Make sure we ONLY update this specific post!

    // Supabase returns an error if something goes wrong
    if (response != null && response.error != null) {
      throw Exception(response.error!.message);
    }
  }

  Future<void> deletePost(int postId) async {
    try {
      // Database CASCADE will handle post_images and comments
      await _supabase.from('posts').delete().eq('id', postId);
      log('Post $postId deleted successfully.');
    } catch (e) {
      log('Error deleting post: $e');
      rethrow;
    }
  }

  /// Fetch a single post by its ID with author and images.
  Future<Map<String, dynamic>?> getPostById(int id) async {
    try {
      final data = await _supabase
          .from('posts')
          .select('*, users!inner(*), post_images(*)')
          .eq('id', id)
          .single();
      return data;
    } catch (e) {
      log('Error fetching post $id: $e');
      return null;
    }
  }

  /// Search posts by title OR location name.
  Future<List<Map<String, dynamic>>> searchPosts(String query) async {
    try {
      final response = await _supabase
          .from('posts')
          .select('*, users!inner(*), post_images(*)')
          .or('title.ilike.%$query%,location_name.ilike.%$query%')
          .eq('status', 'published')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      log('Error searching posts: $e');
      return [];
    }
  }

  // --- POST IMAGE OPERATIONS ---

  /// Batch inserts multiple image URLs for a specific post.
  Future<void> insertPostImages(List<PostImageModel> images) async {
    try {
      final data = images.map((img) => img.toMap()).toList();
      await _supabase.from('post_images').insert(data);
    } catch (e) {
      log('Error inserting post images: $e');
      rethrow;
    }
  }

  /// Fetch all images for a specific post.
  Future<List<PostImageModel>> getImagesByPostId(int postId) async {
    try {
      final response = await _supabase
          .from('post_images')
          .select()
          .eq('post_id', postId);
      return (response as List).map((json) => PostImageModel.fromJson(json)).toList();
    } catch (e) {
      log('Error fetching images for post $postId: $e');
      return [];
    }
  }

  /// Deletes a specific image record.
  /// Note: This deletes the database record, not the file in Storage.
  /*
  Future<void> deletePostImage(int imageId) async {
    try {
      await _supabase.from('post_images').delete().eq('id', imageId);
      log('Post image $imageId deleted.');
    } catch (e) {
      log('Error deleting post image: $e');
      rethrow;
    }
  }
*/
  // --- NEW: Function to delete a specific image from a post ---
  Future<void> deletePostImage(int imageId) async {
    final response = await _supabase
        .from('post_images')
        .delete()
        .eq('id', imageId);

    if (response != null && response.error != null) {
      throw Exception(response.error!.message);
    }
  }

  // --- COMMENT & REACTION OPERATIONS ---

  /// Adds a text comment or a reaction (like).
  Future<void> insertComment(CommentModel comment) async {
    try {
      await _supabase.from('comments').insert(comment.toMap());
    } catch (e) {
      log('Error adding comment/reaction: $e');
      rethrow;
    }
  }

  /// Fetches all comments for a post, including the commenter's profile.
  Future<List<Map<String, dynamic>>> getCommentsForPost(int postId) async {
    try {
      final response = await _supabase
          .from('comments')
          .select('*, users!inner(*)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      log('Error fetching comments: $e');
      return [];
    }
  }

  // --- NEW: Fetch all text comments for a specific post ---
  Future<List<Map<String, dynamic>>> getPostComments(int postId) async {
    final response = await _supabase
        .from('comments')
        .select('*, users(full_name)') // Grab the author's name too!
        .eq('post_id', postId)
        .eq('type', 'text') // Only get text comments, ignore 'heart' reactions
        .order('created_at', ascending: true); // Oldest comments at the top

    return List<Map<String, dynamic>>.from(response);
  }

  /// Counts reactions (likes) for a specific post.
  Future<int> getReactionCount(int postId) async {
    try {
      // We chain .count() at the end to change the return type to PostgrestResponse
      final response = await _supabase
          .from('comments')
          .select()
          .eq('post_id', postId)
          .eq('type', 'reaction')
          .count(CountOption.exact);

      // Now 'response' is a PostgrestResponse, which HAS a .count property
      return response.count;
    } catch (e) {
      log('Error counting reactions: $e');
      return 0;
    }
  }

  /// Counts specific reaction types (e.g., 'heart', 'like') for a specific post.
  Future<int> getSpecificReactionCount(int postId, String reactionType) async {
    try {
      // We filter by post_id, type (must be 'reaction'), and the specific content
      final response = await _supabase
          .from('comments')
          .select()
          .eq('post_id', postId)
          .eq('type', 'reaction')
          .eq('content', reactionType)
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      log('Error counting specific reaction ($reactionType): $e');
      return 0;
    }
  }
  
  Future<void> deleteComment(int commentId) async {
    try {
      await _supabase.from('comments').delete().eq('id', commentId);
    } catch (e) {
      log('Error deleting comment: $e');
      rethrow;
    }
  }

  /// Updates the text of a comment.
  Future<void> updateComment(int commentId, String newContent) async {
    try {
      await _supabase
          .from('comments')
          .update({'content': newContent})
          .eq('id', commentId)
          .eq('type', 'text'); // Safety check to ensure we only update text
      log('Comment $commentId updated.');
    } catch (e) {
      log('Error updating comment: $e');
      rethrow;
    }
  }

  /// Updates a reaction (e.g., user changes from 'like' to 'dislike').
  Future<void> updateReaction(int commentId, String newReaction) async {
    try {
      await _supabase
          .from('comments')
          .update({'content': newReaction})
          .eq('id', commentId)
          .eq('type', 'reaction'); // Safety check
      log('Reaction $commentId updated to $newReaction.');
    } catch (e) {
      log('Error updating reaction: $e');
      rethrow;
    }
  }

}