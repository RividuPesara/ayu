import 'package:flutter/material.dart';
import 'package:mobile_app/Mood Journal/journalEntryScreen.dart';
import 'package:mobile_app/Mood Journal/mood_journal_service.dart';
import 'package:mobile_app/Mood Journal/pastJournalEntries.dart';

class MoodStatusScreen extends StatefulWidget {
  const MoodStatusScreen({super.key});

  @override
  State<MoodStatusScreen> createState() => _MoodStatusScreenState();
}

class _MoodStatusScreenState extends State<MoodStatusScreen> {
  bool _isLoading = true;
  String? _error;
  MoodStats? _stats;
  List<MoodHistoryItem> _cachedRecentHistory = const [];

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    await MoodJournalRepository.instance.ensureInitialized();
    if (!mounted) {
      return;
    }

    setState(() {
      _cachedRecentHistory = MoodJournalRepository.instance
          .recentHistoryFromCache();
    });

    await _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await fetchMoodStats();
      MoodJournalRepository.instance.syncFromMoodStats(data);
      if (!mounted) {
        return;
      }

      setState(() {
        _stats = data;
        _cachedRecentHistory = MoodJournalRepository.instance
            .recentHistoryFromCache();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _statusChipColor(String dominantEmotion) {
    final key = dominantEmotion.toLowerCase();
    if (key == 'fragile') {
      return const Color(0xFFFF8A80);
    }
    if (key.contains('positive')) {
      return const Color(0xFFA8D85A);
    }
    if (key.contains('low')) {
      return const Color(0xFFFFB36A);
    }
    return const Color(0xFFD7B8A8);
  }

  @override
  Widget build(BuildContext context) {
    const Color bgYellow = Color(0xFFF1C24C);
    const Color brown = Color(0xFF4B3326);
    const Color whiteSection = Color(0xFFF4F4F4);

    final stats = _stats;
    final String dominantEmotion = stats?.dominantEmotion ?? 'Mainly Neutral';
    final String statusText = dominantEmotion.toUpperCase();
    final String detailText =
        stats?.emotionMessage ??
        'Keep journaling to build a clearer mood pattern.';
    final history = _cachedRecentHistory.isNotEmpty
        ? _cachedRecentHistory
        : (stats?.recentHistory ?? const <MoodHistoryItem>[]);

    return Scaffold(
      backgroundColor: bgYellow,
      body: SizedBox.expand(
        child: Stack(
          children: [
            // top background image
            Positioned.fill(
              child: Column(
                children: [
                  Expanded(
                    child: Image.asset(
                      'assets/moodjournal.png',
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ],
              ),
            ),
            // bottom white curved section
            Positioned(
              left: 0,
              right: 0,
              bottom: -80,
              child: ClipPath(
                clipper: TopArcClipper(),
                child: Container(height: 650, color: whiteSection),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    // header
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black87,
                                width: 1,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.chevron_left,
                                size: 32,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Mood Journal',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 100),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _statusChipColor(dominantEmotion),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          statusText,
                          style: const TextStyle(
                            fontSize: 32,
                            fontFamily: 'Urbanist',
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        _error ?? detailText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 27,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 62),
                    // plus button
                    Center(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const NewJournalEntryPage(),
                              ),
                            );
                            if (!mounted) {
                              return;
                            }
                            setState(() {
                              _cachedRecentHistory = MoodJournalRepository
                                  .instance
                                  .recentHistoryFromCache();
                            });
                            await _loadStatus();
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: Ink(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: brown,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 35,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Journals',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: brown,
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PastJournalEntriesScreen(),
                              ),
                            );
                            await _loadStatus();
                          },
                          child: const Text(
                            'View All',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: brown,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Expanded(child: _buildHistoryList(history)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(List<MoodHistoryItem> history) {
    if (_isLoading && history.isEmpty) {
      return _buildHistorySkeleton();
    }

    if (_error != null && history.isEmpty) {
      return Center(
        child: TextButton(onPressed: _loadStatus, child: const Text('Retry')),
      );
    }

    if (history.isEmpty) {
      return const Center(
        child: Text(
          'No history yet. Add your first journal entry.',
          style: TextStyle(
            color: Color(0xFF4B3326),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = history[index];
        return MoodHistoryCard(
          month: item.month,
          day: item.day,
          title: item.title,
          mood: item.mood,
        );
      },
    );
  }

  Widget _buildHistorySkeleton() {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          height: 92,
          decoration: BoxDecoration(
            color: const Color(0xFFEDE6E1),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4F2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9CFC8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9CFC8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MoodHistoryCard extends StatelessWidget {
  final String month;
  final String day;
  final String title;
  final String mood;

  const MoodHistoryCard({
    super.key,
    required this.month,
    required this.day,
    required this.title,
    required this.mood,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: const Color(0xFFEFEAE7),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4F2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  month,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: Color(0xFFA49C96),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  day,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5A4A41),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4D3D35),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mood: $mood',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6C5A4F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TopArcClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 90);
    path.quadraticBezierTo(size.width / 2, 0, size.width, 80);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
