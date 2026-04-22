import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_app/video_recommendations_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class DailyRecommendationsScreen extends StatefulWidget {
  const DailyRecommendationsScreen({super.key});

  @override
  State<DailyRecommendationsScreen> createState() =>
      _DailyRecommendationsScreenState();
}

class _DailyRecommendationsScreenState
    extends State<DailyRecommendationsScreen> {
  late Future<VideoRecommendationsResponse> _future;

  static const _cacheKey = 'video_recommendations_cache';
  static const _cacheTimeKey = 'video_recommendations_cache_time';
  static const _cacheTtl = Duration(hours: 24);

  @override
  void initState() {
    super.initState();
    _future = _loadRecommendations();
  }

  Future<void> _refresh({bool force = false}) async {
    setState(() {
      _future = _loadRecommendations(forceRefresh: force);
    });
    await _future;
  }

  Future<VideoRecommendationsResponse> _loadRecommendations({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _readCache();
      if (cached != null) {
        return cached;
      }
    }

    final response = await fetchVideoRecommendations(refresh: forceRefresh);
    await _writeCache(response);
    return response;
  }

  Future<VideoRecommendationsResponse?> _readCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    final timestamp = prefs.getInt(_cacheTimeKey);
    if (raw == null || timestamp == null) {
      return null;
    }

    final cachedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (DateTime.now().difference(cachedAt) > _cacheTtl) {
      return null;
    }

    try {
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      return VideoRecommendationsResponse.fromJson(payload);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(VideoRecommendationsResponse response) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'items': response.items
          .map(
            (item) => {
              'video_id': item.videoId,
              'title': item.title,
              'channel': item.channel,
              'thumbnail': item.thumbnail,
              'url': item.url,
              'query_used': item.queryUsed,
              'tags': item.tags,
              'published_at': item.publishedAt?.toIso8601String(),
              'view_count': item.viewCount,
            },
          )
          .toList(),
      'cached': response.cached,
      'generated_at': response.generatedAt?.toIso8601String(),
      'dominant_emotion': response.dominantEmotion,
      'recommendation_mode': response.recommendationMode,
    };
    await prefs.setString(_cacheKey, jsonEncode(payload));
    await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F4F2),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF6B4F3F),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        size: 32,
                        color: Color(0xFF6B4F3F),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Daily Recommendations',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4B3425),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Container(height: 1, color: const Color(0xFFD9D3CF)),
            Expanded(
              child: FutureBuilder<VideoRecommendationsResponse>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _buildMessageList(
                      context,
                      'Could not load recommendations.',
                      'Pull down to retry.',
                    );
                  }

                  final response = snapshot.data;
                  final data = response?.items ?? [];
                  if (data.isEmpty) {
                    return _buildMessageList(
                      context,
                      'No videos yet.',
                      'Pull down to refresh.',
                    );
                  }

                  final items = data.map(_mapItem).toList();

                  return RefreshIndicator(
                    onRefresh: () => _refresh(force: true),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        return RecommendationCard(
                          item: items[index],
                          onTap: () => _openVideo(items[index].video),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    return RefreshIndicator(
      onRefresh: () => _refresh(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4B3425),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6C6C6C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  RecommendationItem _mapItem(VideoRecommendation video) {
    return RecommendationItem(
      video: video,
      image: video.thumbnail,
      title: video.title,
      views: _formatViews(video.viewCount),
      date: _formatDate(video.publishedAt),
    );
  }

  String _formatViews(int? count) {
    if (count == null || count <= 0) {
      return '';
    }

    if (count >= 1000000000) {
      return '${(count / 1000000000).toStringAsFixed(1)}B views';
    }
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M views';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K views';
    }

    return '$count views';
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '';
    }
    final month = _twoDigits(date.month);
    final day = _twoDigits(date.day);
    return '${date.year}-$month-$day';
  }

  String _twoDigits(int value) {
    if (value >= 10) {
      return value.toString();
    }
    return '0$value';
  }

  Future<void> _openVideo(VideoRecommendation video) async {
    final uri = Uri.tryParse(video.url);
    if (uri == null) {
      _showSnack('Invalid video link.');
      return;
    }

    final tags = video.tags;
    try {
      await trackVideoInteraction(videoId: video.videoId, tags: tags);
    } catch (_) {
      _showSnack('Could not record this view.');
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _showSnack('Could not open YouTube.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class RecommendationItem {
  final VideoRecommendation video;
  final String image;
  final String title;
  final String views;
  final String date;

  RecommendationItem({
    required this.video,
    required this.image,
    required this.title,
    required this.views,
    required this.date,
  });
}

class RecommendationCard extends StatelessWidget {
  final RecommendationItem item;
  final VoidCallback? onTap;

  const RecommendationCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumbnail(),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              child: Text(
                item.title,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F160F),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: [
                  Text(
                    item.views,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6C6C6C),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Text(
                    item.date,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6C6C6C),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (item.image.isEmpty) {
      return Container(
        width: double.infinity,
        height: 250,
        color: const Color(0xFFF1ECE8),
        child: const Icon(
          Icons.ondemand_video,
          size: 48,
          color: Color(0xFF6C6C6C),
        ),
      );
    }

    return Image.network(
      item.image,
      width: double.infinity,
      height: 250,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: double.infinity,
          height: 250,
          color: const Color(0xFFF1ECE8),
          child: const Icon(
            Icons.ondemand_video,
            size: 48,
            color: Color(0xFF6C6C6C),
          ),
        );
      },
    );
  }
}
