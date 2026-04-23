import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/backend_connector.dart';

final BackendConnector _backend = BackendConnector.instance;

class ScheduleItem {
  final String medicationId;
  final String name;
  final String type;
  final String scheduledTime;
  String status;
  final String? logId;

  ScheduleItem({
    required this.medicationId,
    required this.name,
    required this.type,
    required this.scheduledTime,
    required this.status,
    this.logId,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      medicationId: json['medication_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'Capsule',
      scheduledTime: json['scheduled_time'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      logId: json['log_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'medication_id': medicationId,
    'name': name,
    'type': type,
    'scheduled_time': scheduledTime,
    'status': status,
    'log_id': logId,
  };
}

class MedicationItem {
  final String medicationId;
  final String name;
  final String type;
  final List<String> times;
  final String repeatUntil;
  final String startDate;

  MedicationItem({
    required this.medicationId,
    required this.name,
    required this.type,
    required this.times,
    required this.repeatUntil,
    required this.startDate,
  });

  // Convert API medication response into local model
  factory MedicationItem.fromJson(Map<String, dynamic> json) {
    return MedicationItem(
      medicationId: json['medication_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'Capsule',
      times: (json['times'] as List<dynamic>? ?? []).cast<String>(),
      repeatUntil: json['repeat_until'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
    );
  }
}

class TrackerRepository {
  TrackerRepository._();

  static final TrackerRepository instance = TrackerRepository._();

  final Map<String, List<ScheduleItem>> _scheduleCache = {};
  final Map<String, DateTime> _cacheTimes = {};
  bool _isFetching = false;

  static const String _cachePrefix = 'tracker_schedule_v1_';
  static const Duration _todayTtl = Duration(minutes: 5);
  static const Duration _pastTtl = Duration(hours: 1);

  List<ScheduleItem> scheduleFor(String dateKey) {
    return List.from(_scheduleCache[dateKey] ?? []);
  }

  bool hasFreshCache(String dateKey) {
    final cachedAt = _cacheTimes[dateKey];
    if (cachedAt == null || !_scheduleCache.containsKey(dateKey)) return false;
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final ttl = dateKey == todayKey ? _todayTtl : _pastTtl;
    return now.difference(cachedAt) < ttl;
  }

  // Load saved schedule from shared preferences if it exists
  Future<void> loadCachedSchedule(String dateKey) async {
    if (_scheduleCache.containsKey(dateKey)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix$dateKey');
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((item) => ScheduleItem.fromJson(item as Map<String, dynamic>))
          .toList();
      _scheduleCache[dateKey] = list;
      _cacheTimes[dateKey] = DateTime.fromMillisecondsSinceEpoch(0);
    } catch (_) {
      // Ignore cache read failures quietly
    }
  }

  Future<List<ScheduleItem>> fetchSchedule(String dateKey) async {
    if (_isFetching) return scheduleFor(dateKey);
    _isFetching = true;
    try {
      final response = await _backend.get(
        '/tracker/schedule',
        queryParameters: {'date': dateKey},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load schedule (${response.statusCode})');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((item) => ScheduleItem.fromJson(item as Map<String, dynamic>))
          .toList();

      _scheduleCache[dateKey] = items;
      _cacheTimes[dateKey] = DateTime.now();
      await _persistSchedule(dateKey, items);
      return items;
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _persistSchedule(
    String dateKey,
    List<ScheduleItem> items,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_cachePrefix$dateKey',
        jsonEncode(items.map((i) => i.toJson()).toList()),
      );
    } catch (_) {
      // Ignore write failures schedule can still be fetched again later
    }
  }

  // Add optimistic schedule items for a newly created medication before the server confirms
  void insertOptimisticItems(
    String dateKey,
    String tempId,
    String name,
    String type,
    List<String> times,
  ) {
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final isPast = dateKey.compareTo(todayKey) < 0;

    final existing = List<ScheduleItem>.from(_scheduleCache[dateKey] ?? []);
    for (final time in times) {
      final String itemStatus;
      if (isPast) {
        itemStatus = 'missed';
      } else if (dateKey == todayKey && time.compareTo(currentTime) < 0) {
        itemStatus = 'missed';
      } else {
        itemStatus = 'pending';
      }
      existing.add(
        ScheduleItem(
          medicationId: tempId,
          name: name,
          type: type,
          scheduledTime: time,
          status: itemStatus,
        ),
      );
    }
    existing.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    _scheduleCache[dateKey] = existing;
  }

  void removeOptimisticItems(String dateKey, String tempId) {
    final existing = List<ScheduleItem>.from(_scheduleCache[dateKey] ?? []);
    existing.removeWhere((item) => item.medicationId == tempId);
    _scheduleCache[dateKey] = existing;
  }

  void replaceOptimisticItems(
    String dateKey,
    String tempId,
    MedicationItem med,
  ) {
    final existing = List<ScheduleItem>.from(_scheduleCache[dateKey] ?? []);
    existing.removeWhere((item) => item.medicationId == tempId);
    for (final time in med.times) {
      existing.add(
        ScheduleItem(
          medicationId: med.medicationId,
          name: med.name,
          type: med.type,
          scheduledTime: time,
          status: 'pending',
        ),
      );
    }
    existing.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    _scheduleCache[dateKey] = existing;
  }

  // Mark an item taken right away in local cache, before server reply
  void optimisticallyMarkTaken(
    String dateKey,
    String medicationId,
    String scheduledTime,
  ) {
    final items = _scheduleCache[dateKey];
    if (items == null) return;
    for (final item in items) {
      if (item.medicationId == medicationId &&
          item.scheduledTime == scheduledTime) {
        item.status = 'taken';
        break;
      }
    }
  }

  void revertMarkTaken(
    String dateKey,
    String medicationId,
    String scheduledTime,
    String previousStatus,
  ) {
    final items = _scheduleCache[dateKey];
    if (items == null) return;
    for (final item in items) {
      if (item.medicationId == medicationId &&
          item.scheduledTime == scheduledTime) {
        item.status = previousStatus;
        break;
      }
    }
  }

  void invalidateDate(String dateKey) {
    _cacheTimes.remove(dateKey);
  }

  Future<void> removeItemsForMedication(
    String dateKey,
    String medicationId,
  ) async {
    final existing = List<ScheduleItem>.from(_scheduleCache[dateKey] ?? []);
    existing.removeWhere((item) => item.medicationId == medicationId);
    _scheduleCache[dateKey] = existing;
    await _persistSchedule(dateKey, existing);
  }

  Future<void> setScheduleForDate(
    String dateKey,
    List<ScheduleItem> items,
  ) async {
    _scheduleCache[dateKey] = List.from(items);
    await _persistSchedule(dateKey, items);
  }
}

String _extractErrorMessage(dynamic responseBody, int statusCode) {
  try {
    final data = jsonDecode(responseBody as String) as Map<String, dynamic>;
    final detail = data['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
  } catch (_) {}
  return 'Request failed ($statusCode)';
}

Future<MedicationItem> createMedication({
  required String name,
  required String type,
  required List<String> times,
  required String repeatUntil,
}) async {
  final response = await _backend.post(
    '/tracker/medications',
    body: {
      'name': name,
      'type': type,
      'times': times,
      'repeat_until': repeatUntil,
    },
  );

  if (response.statusCode == 201) {
    return MedicationItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  throw Exception(_extractErrorMessage(response.body, response.statusCode));
}

Future<void> markMedicationTaken({
  required String medicationId,
  required String dateKey,
  required String scheduledTime,
}) async {
  final response = await _backend.post(
    '/tracker/logs/take',
    body: {
      'medication_id': medicationId,
      'date_key': dateKey,
      'scheduled_time': scheduledTime,
    },
  );

  if (response.statusCode != 200) {
    throw Exception(_extractErrorMessage(response.body, response.statusCode));
  }
}

Future<void> deleteMedication({required String medicationId}) async {
  final response = await _backend.delete('/tracker/medications/$medicationId');

  if (response.statusCode != 204) {
    throw Exception(_extractErrorMessage(response.body, response.statusCode));
  }
}
