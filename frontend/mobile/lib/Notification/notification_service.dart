import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mobile_app/Notification/notification_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../main.dart' show flutterLocalNotificationsPlugin;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const _cacheKey = 'ayu_notifications_cache';
  static const _syncKey = 'ayu_notifications_last_sync';
  static const _fetchLimit = 50;

  // writes to firestore (doc id = dedupeKey so its idempotent) and updates local cache
  Future<void> saveNotification({
    required String uid,
    required String dedupeKey,
    required String title,
    required String subtitle,
    required String type,
    required String route,
    String priority = 'normal',
    String source = 'push',
    DateTime? fireAt,
  }) async {
    final ref = FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .doc(dedupeKey);

    // skip if already exists so retries cant duplicate
    final snap = await ref.get();
    if (snap.exists) return;

    final now = DateTime.now();
    await ref.set({
      'title': title,
      'subtitle': subtitle,
      'type': type,
      'priority': priority,
      'source': source,
      'route': route,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'fireAt': fireAt != null ? Timestamp.fromDate(fireAt) : null,
      'deliveredAt': null,
    });

    final model = NotificationModel(
      dedupeKey: dedupeKey,
      title: title,
      subtitle: subtitle,
      type: type,
      priority: priority,
      source: source,
      route: route,
      isRead: false,
      createdAt: now,
      fireAt: fireAt,
    );

    await _addToCache(model);
  }

  // load from local cache first then sync from firestore in background
  Future<List<NotificationModel>> fetchNotifications(String uid) async {
    final cached = await _loadCache();
    _syncFromFirestore(uid);
    return cached;
  }

  // marks a notification as read in firestore and in cache
  Future<void> markAsRead(String uid, String dedupeKey) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .doc(dedupeKey)
        .update({'isRead': true});

    final cached = await _loadCache();
    for (final n in cached) {
      if (n.dedupeKey == dedupeKey) n.isRead = true;
    }
    await _saveCache(cached);
  }

  // reads unread count from local cache for instant badge
  Future<int> getUnreadCount(String uid) async {
    final cached = await _loadCache();
    return cached.where((n) => !n.isRead).length;
  }

  // schedules a local os notification and saves to firestore
  Future<void> scheduleLocal({
    required String uid,
    required String dedupeKey,
    required String title,
    required String subtitle,
    required String type,
    required String route,
    required DateTime fireAt,
    String priority = 'normal',
  }) async {
    await saveNotification(
      uid: uid,
      dedupeKey: dedupeKey,
      title: title,
      subtitle: subtitle,
      type: type,
      route: route,
      priority: priority,
      source: 'local',
      fireAt: fireAt,
    );

    final channelId = priority == 'high' ? 'ayu_crisis' : 'ayu_default';
    final notifId = dedupeKey.hashCode.abs();

    await flutterLocalNotificationsPlugin.zonedSchedule(
      notifId,
      title,
      subtitle,
      tz.TZDateTime.from(fireAt, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId == 'ayu_crisis' ? 'Ayu Crisis Alerts' : 'Ayu Notifications',
          importance: priority == 'high' ? Importance.max : Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: route,
    );
  }

  // cancels a pending local os notification by dedupeKey
  Future<void> cancelLocal(String dedupeKey) async {
    final notifId = dedupeKey.hashCode.abs();
    await flutterLocalNotificationsPlugin.cancel(notifId);
  }

  // sets deliveredAt on the firestore doc when the notification is confirmed received
  Future<void> confirmDelivered(String uid, String dedupeKey) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .doc(dedupeKey)
        .update({'deliveredAt': FieldValue.serverTimestamp()});
  }

  // delta sync from firestore — only fetches docs newer than last sync
  Future<void> _syncFromFirestore(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncMs = prefs.getInt(_syncKey);
      final lastSync = lastSyncMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastSyncMs)
          : DateTime.fromMillisecondsSinceEpoch(0);

      var query = FirebaseFirestore.instance
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .orderBy('createdAt', descending: true)
          .limit(_fetchLimit);

      if (lastSyncMs != null) {
        query = query.where('createdAt',
            isGreaterThan: Timestamp.fromDate(lastSync));
      }

      final snap = await query.get();
      if (snap.docs.isEmpty) return;

      final fetched = snap.docs.map(NotificationModel.fromFirestore).toList();
      final cached = await _loadCache();

      // merge fetched into cache, newer firestore data wins
      final map = {for (final n in cached) n.dedupeKey: n};
      for (final n in fetched) {
        map[n.dedupeKey] = n;
      }

      final merged = map.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      await _saveCache(merged);
      await prefs.setInt(_syncKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // sync failure is silent, cached data still shows
    }
  }

  Future<List<NotificationModel>> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return [];
    return NotificationModel.decodeList(raw);
  }

  Future<void> _saveCache(List<NotificationModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, NotificationModel.encodeList(list));
  }

  Future<void> _addToCache(NotificationModel model) async {
    final cached = await _loadCache();
    cached.insert(0, model);
    await _saveCache(cached);
  }
}
