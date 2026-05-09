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
  String quote = '';
  List<ScheduleItem> todayMeds = [];
  List<TaskItem> todayTasks = [];
  bool isReady = false;

  Completer<void>? _completer;

  static const _quotes = <String, List<String>>{
    'Christian': [
      'With God, all things are possible.',
      'Be still and know that I am God.',
      'Fear not, for I am with you.',
      'Joy comes in the morning.',
      'I can do all things through Christ.',
      'Cast your worries on Him; He cares.',
      'The Lord is my shepherd.',
    ],
    'Muslim': [
      'With hardship comes ease.',
      'Allah does not burden beyond capacity.',
      'In His remembrance, hearts find rest.',
      'Be patient. Allah is with the patient.',
      'Speak good, or remain silent.',
      'Trust in Allah and take action.',
      'Every difficulty holds a hidden mercy.',
    ],
    'Buddhist': [
      'The mind is everything. What you think, you become.',
      'Let go of what has passed.',
      'Every morning we are born again.',
      'Peace begins with a single breath.',
      'Compassion is the root of all healing.',
      'You yourself must strive.',
      'Small deeds done are better than great ones planned.',
    ],
    'Hindu': [
      'Do your duty and leave the rest to God.',
      'Act without attachment to the outcome.',
      'Where there is righteousness, there is victory.',
      'The self is never truly lost.',
      'Courage is your greatest virtue.',
      'Let your actions reflect your values.',
      'You are what your deep desire is.',
    ],
    'Other': [
      'You are stronger than you think.',
      "Healing takes time, and that's okay.",
      'One day at a time.',
      'Small steps still move you forward.',
      'You are not alone in this.',
      "Breathe. You've got this.",
      'This too shall pass.',
    ],
    'Prefer not to say': [
      'You are stronger than you think.',
      "Healing takes time, and that's okay.",
      'One day at a time.',
      'Small steps still move you forward.',
      'You are not alone in this.',
      "Breathe. You've got this.",
      'This too shall pass.',
    ],
  };

  static String adjustedDayKey() {
    final now = DateTime.now();
    final d = now.hour < 5 ? now.subtract(const Duration(days: 1)) : now;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _pickQuote(String? religion) {
    final list = _quotes[religion] ?? _quotes['Other']!;
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

    Future.wait([_loadUser(), _loadMeds(), _loadTasks()])
        .then((_) async {
          await _precacheAvatar();
          isReady = true;
          _completer!.complete();
        })
        .catchError((_) {
          isReady = true;
          _completer!.complete();
        });

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
    quote = '';
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
    final uid = resolveUid();
    if (uid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      fullName = data?['fullName'] as String? ?? '';
      final avatar = data?['avatar'] as String?;
      avatarUrl = (avatar != null && avatar.isNotEmpty) ? avatar : null;
      quote = _pickQuote(data?['religion'] as String?);
    } else {
      quote = _pickQuote(null);
    }
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
