import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/network/backend_connector.dart';

final BackendConnector _backend = BackendConnector.instance;

class MoodHistoryItem {
  final String month;
  final String day;
  final String title;
  final String mood;

  MoodHistoryItem({
    required this.month,
    required this.day,
    required this.title,
    required this.mood,
  });

  factory MoodHistoryItem.fromJson(Map<String, dynamic> json) {
    return MoodHistoryItem(
      month: json['month'] as String? ?? '---',
      day: json['day'] as String? ?? '--',
      title: json['title'] as String? ?? '',
      mood: json['mood'] as String? ?? 'NORMAL',
    );
  }
}

class MoodStats {
  final String compositeStatus;
  final String statusLabel;
  final String dominantEmotion;
  final String emotionMessage;
  final int activeDaysCount;
  final int journalStreak;
  final String lastActiveDateKey;
  final bool pulseRecordedToday;
  final bool hasCrisis;
  final List<MoodHistoryItem> recentHistory;

  MoodStats({
    required this.compositeStatus,
    required this.statusLabel,
    required this.dominantEmotion,
    required this.emotionMessage,
    required this.activeDaysCount,
    required this.journalStreak,
    required this.lastActiveDateKey,
    required this.pulseRecordedToday,
    required this.hasCrisis,
    required this.recentHistory,
  });

  factory MoodStats.fromJson(Map<String, dynamic> json) {
    return MoodStats(
      compositeStatus: json['composite_status'] as String? ?? 'Mainly Neutral',
      statusLabel: json['status_label'] as String? ?? '',
      dominantEmotion: json['dominant_emotion'] as String? ?? 'Mainly Neutral',
      emotionMessage: json['emotion_message'] as String? ?? '',
      activeDaysCount: (json['active_days_count'] as num?)?.toInt() ?? 0,
      journalStreak: (json['journal_streak'] as num?)?.toInt() ?? 0,
      lastActiveDateKey: json['last_active_date_key'] as String? ?? '',
      pulseRecordedToday: json['pulse_recorded_today'] as bool? ?? false,
      hasCrisis: json['has_crisis'] as bool? ?? false,
      recentHistory: (json['recent_history'] as List<dynamic>? ?? [])
          .map((item) => MoodHistoryItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class JournalEntryItem {
  final String entryId;
  final String title;
  final String content;
  final String userMood;
  final String aiMood;
  final bool isMismatch;
  final String safetyFlag;
  final DateTime? entryDate;

  JournalEntryItem({
    required this.entryId,
    required this.title,
    required this.content,
    required this.userMood,
    required this.aiMood,
    required this.isMismatch,
    required this.safetyFlag,
    required this.entryDate,
  });

  factory JournalEntryItem.fromJson(Map<String, dynamic> json) {
    return JournalEntryItem(
      entryId: json['entry_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      userMood: json['user_mood'] as String? ?? 'Normal',
      aiMood: json['ai_mood'] as String? ?? 'pending',
      isMismatch: json['is_mismatch'] as bool? ?? false,
      safetyFlag: json['safety_flag'] as String? ?? 'non_crisis',
      entryDate: json['entry_date'] != null
          ? DateTime.tryParse(json['entry_date'] as String)
          : null,
    );
  }
}

class JournalCreateResult {
  final JournalEntryItem entry;
  final bool queued;
  final int activeDaysCount;
  final int journalStreak;
  final bool dayIncremented;
  final String lastActiveDateKey;

  JournalCreateResult({
    required this.entry,
    required this.queued,
    required this.activeDaysCount,
    required this.journalStreak,
    required this.dayIncremented,
    required this.lastActiveDateKey,
  });

  factory JournalCreateResult.fromJson(Map<String, dynamic> json) {
    return JournalCreateResult(
      entry: JournalEntryItem.fromJson(
        json['entry'] as Map<String, dynamic>? ?? {},
      ),
      queued: json['queued'] as bool? ?? true,
      activeDaysCount: (json['active_days_count'] as num?)?.toInt() ?? 0,
      journalStreak: (json['journal_streak'] as num?)?.toInt() ?? 0,
      dayIncremented: json['day_incremented'] as bool? ?? false,
      lastActiveDateKey: json['last_active_date_key'] as String? ?? '',
    );
  }
}

class DailyPulseUpsertResult {
  final String pulseId;
  final String mood;
  final DateTime? timestamp;
  final MoodStats moodStats;

  DailyPulseUpsertResult({
    required this.pulseId,
    required this.mood,
    required this.timestamp,
    required this.moodStats,
  });

  factory DailyPulseUpsertResult.fromJson(Map<String, dynamic> json) {
    final pulse = json['pulse'] as Map<String, dynamic>? ?? {};
    return DailyPulseUpsertResult(
      pulseId: pulse['pulse_id'] as String? ?? '',
      mood: pulse['mood'] as String? ?? 'Normal',
      timestamp: pulse['timestamp'] != null
          ? DateTime.tryParse(pulse['timestamp'] as String)
          : null,
      moodStats: MoodStats.fromJson(
        json['mood_stats'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class JournalEntriesPage {
  final List<JournalEntryItem> entries;
  final String? nextCursor;
  final bool hasMore;

  JournalEntriesPage({
    required this.entries,
    required this.nextCursor,
    required this.hasMore,
  });

  factory JournalEntriesPage.fromJson(Map<String, dynamic> json) {
    return JournalEntriesPage(
      entries: (json['entries'] as List<dynamic>? ?? [])
          .map(
            (item) => JournalEntryItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      nextCursor: json['next_cursor'] as String?,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}

class MoodJournalRepository {
  MoodJournalRepository._();

  static final MoodJournalRepository instance = MoodJournalRepository._();

  final List<JournalEntryItem> _entries = [];
  String? _nextCursor;
  bool _hasMore = false;
  String _currentSort = 'desc';
  bool _isFetchingFirstPage = false;
  bool _isFetchingNextPage = false;

  int _activeDaysCount = 0;
  int _journalStreak = 0;
  String _lastActiveDateKey = '';
  bool _pulseRecordedToday = false;

  List<JournalEntryItem> get entries => List.unmodifiable(_entries);
  String? get nextCursor => _nextCursor;
  bool get hasMore => _hasMore;
  String get currentSort => _currentSort;
  int get activeDaysCount => _activeDaysCount;
  int get journalStreak => _journalStreak;
  String get lastActiveDateKey => _lastActiveDateKey;
  bool get pulseRecordedToday => _pulseRecordedToday;

  bool hasCacheForSort(String sort) {
    return _entries.isNotEmpty && _currentSort == sort;
  }

  void clearCache() {
    _entries.clear();
    _nextCursor = null;
    _hasMore = false;
  }

  void syncFromMoodStats(MoodStats stats) {
    _activeDaysCount = stats.activeDaysCount;
    _journalStreak = stats.journalStreak;
    _pulseRecordedToday = stats.pulseRecordedToday;
    if (stats.lastActiveDateKey.isNotEmpty) {
      _lastActiveDateKey = stats.lastActiveDateKey;
    }
  }

  void syncFromJournalCreateResult(JournalCreateResult result) {
    _activeDaysCount = result.activeDaysCount;
    _journalStreak = result.journalStreak;
    if (result.lastActiveDateKey.isNotEmpty) {
      _lastActiveDateKey = result.lastActiveDateKey;
    }
  }

  void markPulseRecordedTodayLocally() {
    _pulseRecordedToday = true;
  }

  void clearLocalPulseFlag() {
    _pulseRecordedToday = false;
  }

  bool incrementActiveDayIfNeeded({DateTime? when}) {
    final now = when ?? DateTime.now();
    final todayKey = _dateKey(now);

    if (_lastActiveDateKey == todayKey) {
      return false;
    }

    final previousKey = _lastActiveDateKey;
    _activeDaysCount += 1;
    if (_isPreviousDate(previousKey, todayKey)) {
      _journalStreak += 1;
    } else {
      _journalStreak = 1;
    }
    _lastActiveDateKey = todayKey;
    return true;
  }

  void restoreDayCounters({
    required int activeDaysCount,
    required int journalStreak,
    required String lastActiveDateKey,
  }) {
    _activeDaysCount = activeDaysCount;
    _journalStreak = journalStreak;
    _lastActiveDateKey = lastActiveDateKey;
  }

  String _dateKey(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  bool _isPreviousDate(String previousKey, String currentKey) {
    if (previousKey.isEmpty) {
      return false;
    }

    final previous = DateTime.tryParse(previousKey);
    final current = DateTime.tryParse(currentKey);
    if (previous == null || current == null) {
      return false;
    }

    return current.difference(previous).inDays == 1;
  }

  Future<void> ensureFirstPage({String sort = 'desc', int limit = 4}) async {
    if (_isFetchingFirstPage) {
      return;
    }

    if (hasCacheForSort(sort)) {
      return;
    }

    _isFetchingFirstPage = true;
    try {
      final page = await fetchJournalEntriesPage(sort: sort, limit: limit);
      _currentSort = sort;
      _entries
        ..clear()
        ..addAll(page.entries);
      _nextCursor = page.nextCursor;
      _hasMore = page.hasMore;
    } finally {
      _isFetchingFirstPage = false;
    }
  }

  Future<void> fetchNextPage({int limit = 4}) async {
    if (_isFetchingNextPage || !_hasMore) {
      return;
    }

    if (_nextCursor == null || _nextCursor!.isEmpty) {
      _hasMore = false;
      return;
    }

    _isFetchingNextPage = true;
    try {
      final page = await fetchJournalEntriesPage(
        sort: _currentSort,
        limit: limit,
        cursor: _nextCursor,
      );
      _entries.addAll(page.entries);
      _nextCursor = page.nextCursor;
      _hasMore = page.hasMore;
    } finally {
      _isFetchingNextPage = false;
    }
  }

  void insertOptimisticEntry(JournalEntryItem entry) {
    _entries.removeWhere((item) => item.entryId == entry.entryId);
    _entries.insert(0, entry);
  }

  void replaceEntry(String targetEntryId, JournalEntryItem replacement) {
    final index = _entries.indexWhere((item) => item.entryId == targetEntryId);
    if (index >= 0) {
      _entries[index] = replacement;
      return;
    }

    _entries.insert(0, replacement);
  }

  void removeEntryById(String entryId) {
    _entries.removeWhere((item) => item.entryId == entryId);
  }

  List<MoodHistoryItem> recentHistoryFromCache({int limit = 3}) {
    final visible = _entries.take(limit).toList();
    return visible.map((entry) {
      final now = DateTime.now();
      final dt = entry.entryDate ?? now;
      const months = [
        'JAN',
        'FEB',
        'MAR',
        'APR',
        'MAY',
        'JUN',
        'JUL',
        'AUG',
        'SEP',
        'OCT',
        'NOV',
        'DEC',
      ];
      return MoodHistoryItem(
        month: months[dt.month - 1],
        day: dt.day.toString().padLeft(2, '0'),
        title: entry.title,
        mood: entry.userMood.toUpperCase(),
      );
    }).toList();
  }
}

String _extractErrorMessage(http.Response response) {
  try {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final detail = data['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
  } catch (_) {}
  return 'Request failed with status ${response.statusCode}';
}

Future<DailyPulseUpsertResult> submitDailyPulse(String mood) async {
  final response = await _backend.post('/journal/pulse', body: {'mood': mood});

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return DailyPulseUpsertResult.fromJson(data);
  }

  throw Exception(_extractErrorMessage(response));
}

Future<JournalCreateResult> createJournalEntry({
  required String title,
  required String content,
  required String userMood,
}) async {
  final response = await _backend.post(
    '/journal/entries',
    body: {'title': title, 'content': content, 'user_mood': userMood},
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return JournalCreateResult.fromJson(data);
  }

  throw Exception(_extractErrorMessage(response));
}

Future<JournalEntriesPage> fetchJournalEntriesPage({
  String sort = 'desc',
  int limit = 4,
  String? cursor,
}) async {
  final query = <String, dynamic>{'sort': sort, 'limit': limit};
  if (cursor != null && cursor.isNotEmpty) {
    query['cursor'] = cursor;
  }

  final response = await _backend.get(
    '/journal/entries/page',
    queryParameters: query,
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return JournalEntriesPage.fromJson(data);
  }

  throw Exception(_extractErrorMessage(response));
}

Future<JournalEntryItem> fetchJournalEntryById(String entryId) async {
  final response = await _backend.get('/journal/entries/$entryId');

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return JournalEntryItem.fromJson(data);
  }

  throw Exception(_extractErrorMessage(response));
}

Future<MoodStats> fetchMoodStats() async {
  final response = await _backend.get('/journal/status');
  if (response.statusCode == 200) {
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return MoodStats.fromJson(json);
  }
  throw Exception(_extractErrorMessage(response));
}
