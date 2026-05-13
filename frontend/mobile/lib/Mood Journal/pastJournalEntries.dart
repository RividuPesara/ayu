import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_app/Mood Journal/journalEntryScreen.dart';
import 'package:mobile_app/Mood Journal/mood_journal_service.dart';

const Color screenBg = Color(0xFFF4F4F4);
const Color textDark = Color(0xFF4B3425);
const Color mutedText = Color(0xFFA39A93);

const Color greenCard = Color(0xFF9BB068);
const Color orangeCard = Color(0xFFFE814B);
const Color paleGreen = Color(0xFFF2F5EB);
const Color paleOrange = Color(0xFFFFE3D6);

class PastJournalEntriesScreen extends StatefulWidget {
  const PastJournalEntriesScreen({super.key, this.isReadOnly = false});

  final bool isReadOnly;

  @override
  State<PastJournalEntriesScreen> createState() =>
      _PastJournalEntriesScreenState();
}

class _PastJournalEntriesScreenState extends State<PastJournalEntriesScreen> {
  final ScrollController _scrollController = ScrollController();
  final MoodJournalRepository _repository = MoodJournalRepository.instance;

  String selectedSort = 'Newest';
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  List<JournalEntryItem> _entries = [];
  String? _nextCursor;
  bool _hasMore = false;
  int _activeDaysCount = MoodJournalRepository.instance.activeDaysCount;

  void _syncFromRepository() {
    _entries = _repository.entries;
    _nextCursor = _repository.nextCursor;
    _hasMore = _repository.hasMore;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    await _repository.ensureInitialized();
    if (!mounted) {
      return;
    }
    setState(() {
      _syncFromRepository();
      _activeDaysCount = _repository.activeDaysCount;
    });
    await _loadInitial();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoading || _isLoadingMore) {
      return;
    }

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 220) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    try {
      final sort = selectedSort == 'Newest' ? 'desc' : 'asc';
      final hasCache = _repository.hasCacheForSort(sort);

      if (mounted) {
        setState(() {
          _isLoading = !hasCache;
          _error = null;
          _activeDaysCount = _repository.activeDaysCount;
          if (hasCache) {
            _syncFromRepository();
          }
        });
      }

      await _repository.refreshFirstPage(sort: sort, limit: 4);

      if (!mounted) {
        return;
      }

      setState(() {
        _syncFromRepository();
      });

      unawaited(_refreshCounterInBackground());
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

  Future<void> _refreshCounterInBackground() async {
    try {
      final stats = await fetchMoodStats();
      _repository.syncFromMoodStats(stats);

      if (!mounted) {
        return;
      }

      setState(() {
        _activeDaysCount = _repository.activeDaysCount;
      });
    } catch (_) {}
  }

  Future<void> _loadMore() async {
    if (_nextCursor == null || _isLoadingMore || !_hasMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await _repository.fetchNextPage(limit: 4);

      if (!mounted) {
        return;
      }

      setState(() {
        _syncFromRepository();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load more entries.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _openJournalEntry(JournalEntryItem entry) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: textDark)),
    );

    try {
      final detail = await _repository.getEntryDetail(entry.entryId);
      if (!mounted) {
        return;
      }

      Navigator.pop(context);
      _showJournalDialog(
        title: detail.title,
        mood: detail.userMood.toUpperCase(),
        entry: detail.content,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  void _showJournalDialog({
    required String title,
    required String mood,
    required String entry,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF9F7F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Journal Details',
            style: TextStyle(
              color: textDark,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Title',
                  style: TextStyle(
                    color: mutedText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Mood',
                  style: TextStyle(
                    color: mutedText,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mood,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Entry',
                  style: TextStyle(
                    color: mutedText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _cardColorForMood(String mood) {
    final key = mood.toLowerCase();
    if (key == 'normal' ||
        key == 'happy' ||
        key == 'good' ||
        key == 'great' ||
        key == 'joy') {
      return greenCard;
    }
    return orangeCard;
  }

  Color _tagBgForMood(String mood) {
    final key = mood.toLowerCase();
    if (key == 'normal' ||
        key == 'happy' ||
        key == 'good' ||
        key == 'great' ||
        key == 'joy') {
      return paleGreen;
    }
    return paleOrange;
  }

  IconData _iconForMood(String mood) {
    final key = mood.toLowerCase();
    if (key == 'happy' || key == 'good' || key == 'great' || key == 'joy') {
      return Icons.sentiment_very_satisfied_rounded;
    }
    if (key == 'normal' || key == 'neutral') {
      return Icons.sentiment_neutral_rounded;
    }
    return Icons.sentiment_dissatisfied_rounded;
  }

  String _subtitleForEntry(JournalEntryItem entry) {
    final dt = entry.entryDate;
    if (dt == null) {
      return 'Tap to read full journal';
    }

    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$day/$month • Tap to read full journal';
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topSectionHeight = screenHeight * 0.56;

    return Scaffold(
      backgroundColor: screenBg,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: double.infinity,
              height: topSectionHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/moodentries.png', fit: BoxFit.cover),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
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
                                      color: Colors.white.withOpacity(0.8),
                                      width: 1.1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.chevron_left,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                widget.isReadOnly
                                    ? 'Patient\'s Entries'
                                    : 'Your Entries',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Center(
                            child: Text(
                              '$_activeDaysCount/365',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 72,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Center(
                            child: Text(
                              'Active journal days this year.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 175),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipPath(
                clipper: TopArcClipper(),
                child: Container(
                  height: screenHeight * 0.55,
                  decoration: const BoxDecoration(color: screenBg),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 74, 16, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 7),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'All Journals',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: textDark,
                                ),
                              ),
                              _buildSortPill(),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Expanded(child: _buildJournalBody()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!widget.isReadOnly)
              Positioned(
                left: 0,
                right: 0,
                top: topSectionHeight - 118,
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(50),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NewJournalEntryPage(),
                          ),
                        );
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _syncFromRepository();
                        });
                        await _loadInitial();
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: textDark,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalBody() {
    if (_isLoading) {
      if (_entries.isEmpty) {
        return _buildJournalSkeleton();
      }
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: _loadInitial, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_entries.isEmpty) {
      return const Center(
        child: Text(
          'No journal entries yet.',
          style: TextStyle(
            color: textDark,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final showRefreshSlot = _isLoading && _entries.isNotEmpty;
    final refreshSlotCount = showRefreshSlot ? 1 : 0;
    final moreSlotCount = _hasMore || _isLoadingMore ? 1 : 0;
    final itemCount = _entries.length + refreshSlotCount + moreSlotCount;
    final refreshIndex = _entries.length;
    final moreIndex = _entries.length + refreshSlotCount;

    return ListView.separated(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemBuilder: (context, index) {
        if (showRefreshSlot && index == refreshIndex) {
          return _buildRefreshCard();
        }

        if (index == moreIndex) {
          if (_isLoadingMore) {
            return Container(
              width: 120,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: textDark),
            );
          }
          return Container(
            width: 120,
            alignment: Alignment.center,
            child: const Text(
              'Swipe for more',
              textAlign: TextAlign.center,
              style: TextStyle(color: textDark, fontWeight: FontWeight.w700),
            ),
          );
        }

        final entry = _entries[index];
        final cardColor = _cardColorForMood(entry.userMood);
        final tagBg = _tagBgForMood(entry.userMood);

        return JournalCard(
          cardColor: cardColor,
          tagBg: tagBg,
          tagTextColor: cardColor,
          moodText: 'MOOD: ${entry.userMood.toUpperCase()}',
          title: entry.title,
          subtitle: _subtitleForEntry(entry),
          moodIcon: _iconForMood(entry.userMood),
          onTap: () => _openJournalEntry(entry),
        );
      },
    );
  }

  Widget _buildJournalSkeleton() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemBuilder: (context, index) {
        return Container(
          width: 200,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F5F3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 170,
                width: 200,
                margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3DAD3),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Container(
                  height: 18,
                  width: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3DAD3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Container(
                  height: 18,
                  width: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3DAD3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Container(
                  height: 12,
                  width: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3DAD3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRefreshCard() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5F3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 170,
            width: 200,
            margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            decoration: BoxDecoration(
              color: const Color(0xFFE3DAD3),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Container(
              height: 18,
              width: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFE3DAD3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Container(
              height: 18,
              width: 140,
              decoration: BoxDecoration(
                color: const Color(0xFFE3DAD3),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Container(
              height: 12,
              width: 110,
              decoration: BoxDecoration(
                color: const Color(0xFFE3DAD3),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortPill() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: textDark, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedSort,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: textDark,
            size: 18,
          ),
          borderRadius: BorderRadius.circular(14),
          style: const TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          items: const [
            DropdownMenuItem(
              value: 'Newest',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: textDark,
                  ),
                  SizedBox(width: 6),
                  Text('Newest'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'Oldest',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 17,
                    color: textDark,
                  ),
                  SizedBox(width: 6),
                  Text('Oldest'),
                ],
              ),
            ),
          ],
          onChanged: (value) async {
            if (value != null) {
              setState(() {
                selectedSort = value;
              });
              await _loadInitial();
            }
          },
        ),
      ),
    );
  }
}

class JournalCard extends StatelessWidget {
  final Color cardColor;
  final Color tagBg;
  final Color tagTextColor;
  final String moodText;
  final String title;
  final String subtitle;
  final IconData moodIcon;
  final VoidCallback onTap;

  const JournalCard({
    super.key,
    required this.cardColor,
    required this.tagBg,
    required this.tagTextColor,
    required this.moodText,
    required this.title,
    required this.subtitle,
    required this.moodIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F5F3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 170,
              width: 200,
              margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.topLeft,
              child: Icon(moodIcon, color: Colors.white, size: 22),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  moodText,
                  style: TextStyle(
                    color: tagTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: mutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopArcClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 50);
    path.quadraticBezierTo(size.width / 2, -12, size.width, 46);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
