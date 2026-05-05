import 'dart:convert';
import '../../core/network/backend_connector.dart';

class CommunityApiService {
  static final BackendConnector _backend = BackendConnector.instance;

  // Get All Posts
  static Future<List<Map<String, dynamic>>> getPosts() async {
    final res = await _backend.get('/community/posts');

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // Get My Posts
  static Future<List<Map<String, dynamic>>> getMyPosts() async {
    final res = await _backend.get('/community/posts/mine');

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // Create Post
  static Future<void> createPost({
    required String type,
    String caption = '',
    String text = '',
    String title = '',
    String content = '',
    String imageURL = '',
  }) async {
    final res = await _backend.post(
      '/community/posts',
      body: {
        'type': type,
        'caption': caption,
        'text': text,
        'title': title,
        'content': content,
        'imageURL': imageURL,
      },
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
  }

  // Like/Unlike
  static Future<Map<String, dynamic>> toggleLike(String postId) async {
    final res = await _backend.post('/community/posts/$postId/like');

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }

    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  // Get Comments
  static Future<List<Map<String, dynamic>>> getComments(String postId) async {
    final res = await _backend.get('/community/posts/$postId/comments');

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // Add Comment
  static Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    final res = await _backend.post(
      '/community/posts/$postId/comments',
      body: {
        'text': text,
      },
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
  }
}