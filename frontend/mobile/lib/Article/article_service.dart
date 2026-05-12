import 'dart:convert';
import '../core/network/backend_connector.dart';

class ContentImage {
  final String id;
  final String dataUrl;
  final String name;

  ContentImage({required this.id, required this.dataUrl, required this.name});

  factory ContentImage.fromJson(Map<String, dynamic> json) => ContentImage(
        id: json['id'] as String? ?? '',
        dataUrl: json['dataUrl'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
}

class ArticleModel {
  final String id;
  final String title;
  final String genre;
  final String author;
  final String thumbnail;
  final String content;
  final List<ContentImage> contentImages;

  ArticleModel({
    required this.id,
    required this.title,
    required this.genre,
    required this.author,
    required this.thumbnail,
    required this.content,
    required this.contentImages,
  });

  factory ArticleModel.fromJson(Map<String, dynamic> json) => ArticleModel(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        genre: json['genre'] as String? ?? '',
        author: json['author'] as String? ?? '',
        thumbnail: json['thumbnail'] as String? ?? '',
        content: json['content'] as String? ?? '',
        contentImages: (json['contentImages'] as List<dynamic>? ?? [])
            .map((e) => ContentImage.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class ArticleService {
  static final _backend = BackendConnector.instance;

  static Future<List<ArticleModel>> fetchPublished() async {
    final res = await _backend.get('/articles');
    if (res.statusCode != 200) throw Exception('Failed to load articles');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = data['articles'] as List<dynamic>;
    return list.map((e) => ArticleModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }
}
