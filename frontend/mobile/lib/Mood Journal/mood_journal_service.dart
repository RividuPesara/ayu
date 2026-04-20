import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  final String currentStatus;
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
    required this.currentStatus,
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
      currentStatus: json['current_status'] as String? ??
          json['composite_status'] as String? ??
          'Mainly Neutral',
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

class _CachedEntry {
  final JournalEntryItem entry;
  final DateTime cachedAt;

  const _CachedEntry({required this.entry, required this.cachedAt});
}

class MoodJournalRepository {
  MoodJournalRepository._();

  static final MoodJournalRepository instance = MoodJournalRepository._();

  final List<JournalEntryItem> _entries = [];
  final Map<String, _CachedEntry> _entryCache = {};
  List<MoodHistoryItem> _recentHistory = [];
  bool _initialized = false;
  String? _nextCursor;
  bool _hasMore = false;
  String _currentSort = 'desc';
  bool _isFetchingFirstPage = false;
  bool _isFetchingNextPage = false;

  int _activeDaysCount = 0;
  int _journalStreak = 0;
  String _lastActiveDateKey = '';
  bool _pulseRecordedToday = false;
  String _currentStatus = 'Mainly Neutral';
  String _emotionMessage = '';

  static const int _maxRecentEntries = 4;
  static const String _lightCacheKey = 'mood_journal_light_cache_v1';
  static const String _entryCachePrefix = 'mood_journal_entry_cache_v1_';
  static const Duration _entryCacheTtl = Duration(minutes: 20);

  List<JournalEntryItem> get entries => List.unmodifiable(_entries);
  String? get nextCursor => _nextCursor;
  bool get hasMore => _hasMore;
  String get currentSort => _currentSort;
  int get activeDaysCount => _activeDaysCount;
  int get journalStreak => _journalStreak;
  String get lastActiveDateKey => _lastActiveDateKey;
  bool get pulseRecordedToday => _pulseRecordedToday;
  String get currentStatus => _currentStatus;
  String get emotionMessage => _emotionMessage;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lightCacheKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _activeDaysCount = (data['active_days_count'] as num?)?.toInt() ?? 0;
      _journalStreak = (data['journal_streak'] as num?)?.toInt() ?? 0;
      _lastActiveDateKey = data['last_active_date_key'] as String? ?? '';
      _pulseRecordedToday = data['pulse_recorded_today'] as bool? ?? false;
      _currentStatus = data['current_status'] as String? ?? 'Mainly Neutral';
      _emotionMessage = data['emotion_message'] as String? ?? '';

      final recentEntries = (data['recent_entries'] as List<dynamic>? ?? [])
          .map((item) => _entryFromJson(item as Map<String, dynamic>))
          .toList();
      if (recentEntries.isNotEmpty) {
        _entries
          ..clear()
          ..addAll(recentEntries);
        _currentSort = 'desc';
        _nextCursor = null;
        _hasMore = false;
      }

      _recentHistory = (data['recent_history'] as List<dynamic>? ?? [])
          .map((item) => _historyFromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Ignore malformed local cache.
    }
  }

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
    _currentStatus = stats.currentStatus.isNotEmpty
        ? stats.currentStatus
        : stats.dominantEmotion;
    _emotionMessage = stats.emotionMessage;
    if (stats.lastActiveDateKey.isNotEmpty) {
      _lastActiveDateKey = stats.lastActiveDateKey;
    }
    if (stats.recentHistory.isNotEmpty) {
      _recentHistory = stats.recentHistory;
    }
    _persistLightCache();
  }

  void syncFromJournalCreateResult(JournalCreateResult result) {
    _activeDaysCount = result.activeDaysCount;
    _journalStreak = result.journalStreak;
    if (result.lastActiveDateKey.isNotEmpty) {
      _lastActiveDateKey = result.lastActiveDateKey;
    }
    _persistLightCache();
  }

  void markPulseRecordedTodayLocally() {
    _pulseRecordedToday = true;
    _persistLightCache();
  }

  void clearLocalPulseFlag() {
    _pulseRecordedToday = false;
    _persistLightCache();
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
    _persistLightCache();
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
    _persistLightCache();
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
      final merged = _mergeWithPendingEntries(page.entries, sort: sort);
      _entries
        ..clear()
        ..addAll(merged);
      _nextCursor = page.nextCursor;
      _hasMore = page.hasMore;
      _persistLightCache();
    } finally {
      _isFetchingFirstPage = false;
    }
  }

  Future<void> refreshFirstPage({String sort = 'desc', int limit = 4}) async {
    if (_isFetchingFirstPage) {
      return;
    }

    _isFetchingFirstPage = true;
    try {
      final page = await fetchJournalEntriesPage(sort: sort, limit: limit);
      _currentSort = sort;
      final merged = _mergeWithPendingEntries(page.entries, sort: sort);
      _entries
        ..clear()
        ..addAll(merged);
      _nextCursor = page.nextCursor;
      _hasMore = page.hasMore;
      _persistLightCache();
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
      final existingIds = _entries.map((item) => item.entryId).toSet();
      final unique = page.entries.where((item) => !existingIds.contains(item.entryId));
      _entries.addAll(unique);
      _nextCursor = page.nextCursor;
      _hasMore = page.hasMore;
      _persistLightCache();
    } finally {
      _isFetchingNextPage = false;
    }
  }

  void insertOptimisticEntry(JournalEntryItem entry) {
    _entries.removeWhere((item) => item.entryId == entry.entryId);
    _entries.insert(0, entry);
    _updateRecentHistoryFromEntry(entry);
    _cacheEntry(entry);
    _persistLightCache();
  }

  void replaceEntry(String targetEntryId, JournalEntryItem replacement) {
    _entries.removeWhere((item) => item.entryId == replacement.entryId);
    final index = _entries.indexWhere((item) => item.entryId == targetEntryId);
    if (index >= 0) {
      _entries[index] = replacement;
      _updateRecentHistoryFromEntry(replacement);
      _cacheEntry(replacement);
      _persistLightCache();
      return;
    }

    _entries.insert(0, replacement);
    _updateRecentHistoryFromEntry(replacement);
    _cacheEntry(replacement);
    _persistLightCache();
  }

  void removeEntryById(String entryId) {
    _entries.removeWhere((item) => item.entryId == entryId);
    _entryCache.remove(entryId);
    _persistLightCache();
  }

  List<MoodHistoryItem> recentHistoryFromCache({int limit = _maxRecentEntries}) {
    final fromEntries = _recentEntriesForHistory(limit: limit)
        .map((entry) => _historyFromEntry(entry))
        .toList();

    final merged = <MoodHistoryItem>[];
    final seen = <String>{};

    void addIfUnique(MoodHistoryItem item) {
      final signature = _historySignature(item);
      if (seen.add(signature)) {
        merged.add(item);
      }
    }

    for (final item in fromEntries) {
      addIfUnique(item);
    }
    for (final item in _recentHistory) {
      if (merged.length >= limit) {
        break;
      }
      addIfUnique(item);
    }

    return merged.take(limit).toList();
  }

  Future<JournalEntryItem> getEntryDetail(String entryId) async {
    final cached = await _tryGetCachedEntry(entryId);
    if (cached != null) {
      return cached;
    }

    final entry = await fetchJournalEntryById(entryId);
    _cacheEntry(entry);
    return entry;
  }

  MoodHistoryItem _historyFromEntry(JournalEntryItem entry) {
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
  }

  Iterable<JournalEntryItem> _recentEntriesForHistory({int limit = _maxRecentEntries}) {
    if (_entries.isEmpty) {
      return const <JournalEntryItem>[];
    }

    if (_currentSort == 'asc') {
      final startIndex = _entries.length - limit;
      final start = startIndex < 0 ? 0 : startIndex;
      return _entries.sublist(start).reversed;
    }

    return _entries.take(limit);
  }

  void _updateRecentHistoryFromEntry(JournalEntryItem entry) {
    final newItem = _historyFromEntry(entry);
    final updated = <MoodHistoryItem>[newItem];
    final newSignature = _historySignature(newItem);

    for (final item in _recentHistory) {
      if (updated.length >= _maxRecentEntries) {
        break;
      }
      if (_historySignature(item) == newSignature) {
        continue;
      }
      updated.add(item);
    }

    _recentHistory = updated;
  }

  String _entryMatchKey(JournalEntryItem entry) {
    final title = entry.title.trim().toLowerCase();
    final mood = entry.userMood.trim().toLowerCase();
    final date = entry.entryDate?.toIso8601String().substring(0, 10) ?? '';
    return '$title|$mood|$date';
  }

  String _historySignature(MoodHistoryItem item) {
    final title = item.title.trim().toLowerCase();
    final day = item.day.trim();
    final mood = item.mood.trim().toLowerCase();
    return '$title|$day|$mood';
  }

  List<JournalEntryItem> _mergeWithPendingEntries(
    List<JournalEntryItem> serverEntries, {
    required String sort,
  }) {
    final seenServerIds = <String>{};
    final uniqueServer = <JournalEntryItem>[];
    for (final entry in serverEntries) {
      if (seenServerIds.add(entry.entryId)) {
        uniqueServer.add(entry);
      }
    }

    final pending = _entries.where((item) => item.entryId.startsWith('local_')).toList();
    if (pending.isEmpty) {
      return uniqueServer;
    }

    final serverSignatures = uniqueServer.map(_entryMatchKey).toSet();
    final filteredPending = pending
      .where((entry) => !serverSignatures.contains(_entryMatchKey(entry)))
        .toList();

    if (sort == 'asc') {
      return [...uniqueServer, ...filteredPending];
    }

    return [...filteredPending, ...uniqueServer];
  }

  Future<void> _persistLightCache() async {
    if (!_initialized) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final recentEntries = _recentEntriesForHistory(limit: _maxRecentEntries).toList();
    final payload = <String, dynamic>{
      'active_days_count': _activeDaysCount,
      'journal_streak': _journalStreak,
      'last_active_date_key': _lastActiveDateKey,
      'pulse_recorded_today': _pulseRecordedToday,
      'current_status': _currentStatus,
      'emotion_message': _emotionMessage,
      'recent_entries': recentEntries.map(_entryToJson).toList(),
      'recent_history': _recentHistory.map(_historyToJson).toList(),
    };

    await prefs.setString(_lightCacheKey, jsonEncode(payload));
  }

  Future<JournalEntryItem?> _tryGetCachedEntry(String entryId) async {
    _pruneExpiredEntryCache();

    final cached = _entryCache[entryId];
    if (cached != null && _isCacheValid(cached.cachedAt)) {
      return cached.entry;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_entryCachePrefix$entryId');
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAt = DateTime.tryParse(data['cached_at'] as String? ?? '');
      if (cachedAt == null || !_isCacheValid(cachedAt)) {
        await prefs.remove('$_entryCachePrefix$entryId');
        return null;
      }

      final entry = _entryFromJson(data['entry'] as Map<String, dynamic>);
      _entryCache[entryId] = _CachedEntry(entry: entry, cachedAt: cachedAt);
      return entry;
    } catch (_) {
      await prefs.remove('$_entryCachePrefix$entryId');
      return null;
    }
  }

  bool _isCacheValid(DateTime cachedAt) {
    return DateTime.now().difference(cachedAt) <= _entryCacheTtl;
  }

  Future<void> _cacheEntry(JournalEntryItem entry) async {
    if (entry.content.isEmpty) {
      return;
    }

    final cachedAt = DateTime.now();
    _entryCache[entry.entryId] = _CachedEntry(entry: entry, cachedAt: cachedAt);

    if (!_initialized) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      {
        'cached_at': cachedAt.toIso8601String(),
        'entry': _entryToJson(entry),
      },
    );
    await prefs.setString('$_entryCachePrefix${entry.entryId}', payload);
  }

  void _pruneExpiredEntryCache() {
    final now = DateTime.now();
    final expiredKeys = _entryCache.entries
        .where((entry) => now.difference(entry.value.cachedAt) > _entryCacheTtl)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _entryCache.remove(key);
    }
  }

  Map<String, dynamic> _entryToJson(JournalEntryItem entry) {
    return {
      'entry_id': entry.entryId,
      'title': entry.title,
      'content': entry.content,
      'user_mood': entry.userMood,
      'ai_mood': entry.aiMood,
      'is_mismatch': entry.isMismatch,
      'safety_flag': entry.safetyFlag,
      'entry_date': entry.entryDate?.toIso8601String(),
    };
  }

  JournalEntryItem _entryFromJson(Map<String, dynamic> json) {
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

  Map<String, dynamic> _historyToJson(MoodHistoryItem item) {
    return {
      'month': item.month,
      'day': item.day,
      'title': item.title,
      'mood': item.mood,
    };
  }

  MoodHistoryItem _historyFromJson(Map<String, dynamic> json) {
    return MoodHistoryItem(
      month: json['month'] as String? ?? '---',
      day: json['day'] as String? ?? '--',
      title: json['title'] as String? ?? '',
      mood: json['mood'] as String? ?? 'NORMAL',
    );
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
