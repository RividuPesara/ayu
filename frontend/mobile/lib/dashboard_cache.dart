import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'Tracker/tracker_service.dart';
import 'Todo List/task_service.dart';

class DashboardCache {
  DashboardCache._();
  static final DashboardCache instance = DashboardCache._();

  String fullName = '';
  String? avatarUrl;
  String quoteKey = '';
  List<ScheduleItem> todayMeds = [];
  List<TaskItem> todayTasks = [];
  bool isReady = false;

  Completer<void>? _completer;

  static const _quoteKeys = <String, List<String>>{
    'Christian': [
      'quote.christian.0',
      'quote.christian.1',
      'quote.christian.2',
      'quote.christian.3',
      'quote.christian.4',
      'quote.christian.5',
      'quote.christian.6',
    ],
    'Muslim': [
      'quote.muslim.0',
      'quote.muslim.1',
      'quote.muslim.2',
      'quote.muslim.3',
      'quote.muslim.4',
      'quote.muslim.5',
      'quote.muslim.6',
    ],
    'Buddhist': [
      'quote.buddhist.0',
      'quote.buddhist.1',
      'quote.buddhist.2',
      'quote.buddhist.3',
      'quote.buddhist.4',
      'quote.buddhist.5',
      'quote.buddhist.6',
    ],
    'Hindu': [
      'quote.hindu.0',
      'quote.hindu.1',
      'quote.hindu.2',
      'quote.hindu.3',
      'quote.hindu.4',
      'quote.hindu.5',
      'quote.hindu.6',
    ],
    'Other': [
      'quote.other.0',
      'quote.other.1',
      'quote.other.2',
      'quote.other.3',
      'quote.other.4',
      'quote.other.5',
      'quote.other.6',
    ],
    'Prefer not to say': [
      'quote.other.0',
      'quote.other.1',
      'quote.other.2',
      'quote.other.3',
      'quote.other.4',
      'quote.other.5',
      'quote.other.6',
    ],
  };

  static DateTime adjustedNow() {
    final now = DateTime.now();
    return now.hour < 5 ? now.subtract(const Duration(days: 1)) : now;
  }

  static String adjustedDayKey() {
    final d = adjustedNow();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _pickQuote(String? religion) {
    final list = _quoteKeys[religion] ?? _quoteKeys['Other']!;
    final now = DateTime.now();
    final d = now.hour < 5 ? now.subtract(const Duration(days: 1)) : now;
    final dayOfYear = d.difference(DateTime(d.year, 1, 1)).inDays;
    return list[dayOfYear % list.length];
  }

  static String? resolveUid() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> preload() {
    if (_completer != null) return _completer!.future;
    _completer = Completer<void>();

    () async {
      try {
        await _loadUser();
        await Future.wait([_loadMeds(), _loadTasks()]);
        await _precacheAvatar();
      } catch (_) {}
      isReady = true;
      _completer!.complete();
    }();

    return _completer!.future;
  }

  Future<void> _precacheAvatar() async {
    if (avatarUrl == null) return;
    try {
      final stream = NetworkImage(avatarUrl!).resolve(ImageConfiguration.empty);
      final done = Completer<void>();
      stream.addListener(
        ImageStreamListener(
          (_, _) {
            if (!done.isCompleted) done.complete();
          },
          onError: (_, _) {
            if (!done.isCompleted) done.complete();
          },
        ),
      );
      await done.future;
    } catch (_) {}
  }

  Future<void> refreshMeds() async {
    TrackerRepository.instance.invalidateDate(adjustedDayKey());
    await _loadMeds();
  }

  Future<void> refreshTasks() async {
    try {
      todayTasks = await TaskRepository.instance.fetchTasks(adjustedDayKey());
    } catch (_) {}
  }

  void invalidate() {
    _completer = null;
    isReady = false;
    fullName = '';
    avatarUrl = null;
    quoteKey = '';
    todayMeds = [];
    todayTasks = [];
  }

  Future<void> _loadTasks() async {
    final dateKey = adjustedDayKey();
    final repo = TaskRepository.instance;
    await repo.loadCachedTasks(dateKey);
    todayTasks = repo.tasksFor(dateKey);
    if (!repo.hasFreshCache(dateKey)) {
      try {
        todayTasks = await repo.fetchTasks(dateKey);
      } catch (_) {}
    }
  }

  Future<void> _loadUser() async {
    String? uid;
    try {
      final user = await FirebaseAuth.instance
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 4));
      uid = user?.uid;
    } catch (_) {
      uid = resolveUid();
    }

    if (uid != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final data = doc.data();
        fullName = data?['fullName'] as String? ?? '';
        final avatar = data?['avatar'] as String?;
        avatarUrl = (avatar != null && avatar.isNotEmpty) ? avatar : null;
        quoteKey = _pickQuote(data?['religion'] as String?);
      } catch (_) {
        if (quoteKey.isEmpty) quoteKey = _pickQuote(null);
      }
    } else {
      quoteKey = _pickQuote(null);
    }
  }

  Future<void> refreshProfile() async {
    await _loadUser();
    await _precacheAvatar();
  }

  Future<void> _loadMeds() async {
    final dateKey = adjustedDayKey();
    final repo = TrackerRepository.instance;
    await repo.loadCachedSchedule(dateKey);
    todayMeds = repo.scheduleFor(dateKey);
    if (!repo.hasFreshCache(dateKey)) {
      try {
        todayMeds = await repo.fetchSchedule(dateKey);
      } catch (_) {}
    }
  }
}
