import 'dart:convert';

import 'package:mobile_app/core/network/backend_connector.dart';

final BackendConnector _backend = BackendConnector.instance;

class VideoRecommendation {
  final String videoId;
  final String title;
  final String channel;
  final String thumbnail;
  final String url;
  final String queryUsed;
  final List<String> tags;
  final int? viewCount;
  final DateTime? publishedAt;

  VideoRecommendation({
    required this.videoId,
    required this.title,
    required this.channel,
    required this.thumbnail,
    required this.url,
    required this.queryUsed,
    required this.tags,
    required this.viewCount,
    required this.publishedAt,
  });

  factory VideoRecommendation.fromJson(Map<String, dynamic> json) {
    return VideoRecommendation(
      videoId: json['video_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      channel: json['channel'] as String? ?? '',
      thumbnail: json['thumbnail'] as String? ?? '',
      url: json['url'] as String? ?? '',
      queryUsed: json['query_used'] as String? ?? '',
      tags:
          (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],
      viewCount: _parseInt(json['view_count']),
      publishedAt: _parseDate(json['published_at']),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class VideoRecommendationsResponse {
  final List<VideoRecommendation> items;
  final bool cached;
  final DateTime? generatedAt;
  final String? dominantEmotion;
  final String? recommendationMode;

  VideoRecommendationsResponse({
    required this.items,
    required this.cached,
    required this.generatedAt,
    required this.dominantEmotion,
    required this.recommendationMode,
  });

  factory VideoRecommendationsResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List<dynamic>? ?? [])
        .map((e) => VideoRecommendation.fromJson(e as Map<String, dynamic>))
        .toList();
    return VideoRecommendationsResponse(
      items: list,
      cached: json['cached'] as bool? ?? false,
      generatedAt: _parseDate(json['generated_at']),
      dominantEmotion: json['dominant_emotion'] as String?,
      recommendationMode: json['recommendation_mode'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

Future<VideoRecommendationsResponse> fetchVideoRecommendations({
  bool refresh = false,
}) async {
  final response = await _backend.get(
    '/videos/recommendations',
    queryParameters: {
      if (refresh) 'refresh': 'true',
    },
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return VideoRecommendationsResponse.fromJson(data);
  }

  throw Exception(
    'Failed to load recommendations: ${response.statusCode} ${response.body}',
  );
}

Future<void> trackVideoInteraction({
  required String videoId,
  required List<String> tags,
}) async {
  final response = await _backend.post(
    '/videos/interactions',
    body: {
      'video_id': videoId,
      'tags': tags,
    },
  );

  if (response.statusCode == 200) {
    return;
  }

  throw Exception(
    'Failed to track interaction: ${response.statusCode} ${response.body}',
  );
}
