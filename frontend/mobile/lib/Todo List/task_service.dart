import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/backend_connector.dart';

final BackendConnector _backend = BackendConnector.instance;

class TaskItem {
  final String taskId;
  final String userId;
  final String title;
  final String dateKey;
  final String time;
  bool isDone;

  TaskItem({
    required this.taskId,
    required this.userId,
    required this.title,
    required this.dateKey,
    required this.time,
    required this.isDone,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      taskId: json['task_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      dateKey: json['date_key'] as String? ?? '',
      time: json['time'] as String? ?? '00:00',
      isDone: json['is_done'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'task_id': taskId,
    'user_id': userId,
    'title': title,
    'date_key': dateKey,
    'time': time,
    'is_done': isDone,
  };
}

class TaskRepository {
  TaskRepository._();

  static final TaskRepository instance = TaskRepository._();

  final Map<String, List<TaskItem>> _cache = {};
  final Map<String, DateTime> _cacheTimes = {};

  static const String _cachePrefix = 'tasks_cache_v1_';
  static const Duration _todayTtl = Duration(minutes: 5);
  static const Duration _pastTtl = Duration(hours: 1);

  List<TaskItem> tasksFor(String dateKey) => List.from(_cache[dateKey] ?? []);

  bool hasFreshCache(String dateKey) {
    final cachedAt = _cacheTimes[dateKey];
    if (cachedAt == null || !_cache.containsKey(dateKey)) return false;
    final now = DateTime.now();
    final todayKey = _fmtKey(now);
    final ttl = dateKey == todayKey ? _todayTtl : _pastTtl;
    return now.difference(cachedAt) < ttl;
  }

  // Load persisted tasks from SharedPreferences into memory without marking cache as fresh
  Future<void> loadCachedTasks(String dateKey) async {
    if (_cache.containsKey(dateKey)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix$dateKey');
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((item) => TaskItem.fromJson(item as Map<String, dynamic>))
          .toList();
      _cache[dateKey] = list;
      _cacheTimes[dateKey] = DateTime.fromMillisecondsSinceEpoch(0);
    } catch (_) {}
  }

  Future<List<TaskItem>> fetchTasks(String dateKey) async {
    final response = await _backend.get(
      '/tasks',
      queryParameters: {'date': dateKey},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load tasks (${response.statusCode})');
    }

    final list = (jsonDecode(response.body) as List<dynamic>)
        .map((item) => TaskItem.fromJson(item as Map<String, dynamic>))
        .toList();

    _cache[dateKey] = list;
    _cacheTimes[dateKey] = DateTime.now();
    await _persistTasks(dateKey, list);
    return list;
  }

  Future<void> _persistTasks(String dateKey, List<TaskItem> tasks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_cachePrefix$dateKey',
        jsonEncode(tasks.map((t) => t.toJson()).toList()),
      );
    } catch (_) {}
  }

  // Add a task immediately may use a local temp ID before server confirms
  void insertOptimistic(String dateKey, TaskItem task) {
    final list = List<TaskItem>.from(_cache[dateKey] ?? []);
    list.add(task);
    _cache[dateKey] = list;
    _persistTasks(dateKey, list);
  }

  void removeByTaskId(String dateKey, String taskId) {
    final list = List<TaskItem>.from(_cache[dateKey] ?? []);
    list.removeWhere((t) => t.taskId == taskId);
    _cache[dateKey] = list;
    _persistTasks(dateKey, list);
  }

  // Swap a temp local entry with the server assigned TaskItem after creation succeeds
  void replaceOptimistic(String dateKey, String tempId, TaskItem real) {
    final list = List<TaskItem>.from(_cache[dateKey] ?? []);
    final idx = list.indexWhere((t) => t.taskId == tempId);
    if (idx != -1) {
      list[idx] = real;
    } else {
      list.add(real);
    }
    _cache[dateKey] = list;
    _persistTasks(dateKey, list);
  }

  void optimisticallyToggle(String dateKey, String taskId) {
    final list = _cache[dateKey];
    if (list == null) return;
    for (final task in list) {
      if (task.taskId == taskId) {
        task.isDone = !task.isDone;
        break;
      }
    }
    _persistTasks(dateKey, list);
  }

  // Toggling twice restores the original state
  void revertToggle(String dateKey, String taskId) =>
      optimisticallyToggle(dateKey, taskId);

  void restoreBackup(String dateKey, List<TaskItem> backup) {
    _cache[dateKey] = List.from(backup);
    _persistTasks(dateKey, _cache[dateKey]!);
  }

  void invalidateDate(String dateKey) => _cacheTimes.remove(dateKey);

  void clearAll() {
    _cache.clear();
    _cacheTimes.clear();
  }

  Future<void> clearPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_cachePrefix)).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  String _fmtKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

String _extractErrorMessage(dynamic responseBody, int statusCode) {
  try {
    final data = jsonDecode(responseBody as String) as Map<String, dynamic>;
    final detail = data['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
  } catch (_) {}
  return 'Request failed ($statusCode)';
}

Future<TaskItem> createTask({
  required String title,
  required String dateKey,
  required String time,
}) async {
  final response = await _backend.post(
    '/tasks',
    body: {'title': title, 'date_key': dateKey, 'time': time},
  );

  if (response.statusCode == 201) {
    return TaskItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  throw Exception(_extractErrorMessage(response.body, response.statusCode));
}

Future<TaskItem> toggleTaskApi(String taskId) async {
  final request = await _backend.request('PATCH', '/tasks/$taskId/toggle');
  final streamedResponse = await request.send();
  final body = await streamedResponse.stream.bytesToString();

  if (streamedResponse.statusCode == 200) {
    return TaskItem.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  throw Exception(_extractErrorMessage(body, streamedResponse.statusCode));
}

Future<void> deleteTaskApi(String taskId) async {
  final response = await _backend.delete('/tasks/$taskId');

  if (response.statusCode != 204) {
    throw Exception(_extractErrorMessage(response.body, response.statusCode));
  }
}
