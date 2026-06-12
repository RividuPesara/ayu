import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'notification_helper.dart';
import 'notification_model.dart';
import 'notification_navigator.dart';
import 'notification_service.dart';

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  State<Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  List<NotificationModel> _notifications = [];
  bool _loading = true;
  StreamSubscription<List<NotificationModel>>? _sub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    // show cache immediately while the stream connects
    final cached = await NotificationService.instance.fetchNotifications(uid);
    if (mounted) {
      setState(() {
        _notifications = cached;
        _loading = false;
      });
    }

    // then keep in sync via real-time stream
    _sub = NotificationService.instance.streamNotifications(uid).listen((list) {
      if (mounted) setState(() => _notifications = list);
    });
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> _markAllAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      for (final n in _notifications) {
        n.isRead = true;
      }
    });
    await NotificationService.instance.markAllAsRead(uid);
  }

  Map<String, List<NotificationModel>> _grouped() {
    final grouped = <String, List<NotificationModel>>{};
    for (final n in _notifications) {
      final key = getNotificationGroup(n.createdAt);
      grouped.putIfAbsent(key, () => []).add(n);
    }
    return grouped;
  }

  Future<void> _onTap(NotificationModel n) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && !n.isRead) {
      await NotificationService.instance.markAsRead(uid, n.dedupeKey);
      setState(() => n.isRead = true);
    }
    if (!mounted) return;
    _navigateTo(n.route);
  }

  void _navigateTo(String route) {
    final screen = screenForRoute(route);
    if (screen == null) {
      Navigator.pop(context);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // icon and colour per notification type
  IconData _iconFor(String type) {
    switch (type) {
      case 'medication': return Icons.medication;
      case 'mood': return Icons.mood;
      case 'task': return Icons.check_circle_outline;
      case 'companion': return Icons.favorite;
      case 'appointment': return Icons.calendar_today;
      case 'community': return Icons.people;
      default: return Icons.notifications;
    }
  }

  Color _colorFor(String type, String priority) {
    if (priority == 'high') return const Color(0xffE53935);
    switch (type) {
      case 'medication': return const Color(0xff4CAF50);
      case 'mood': return const Color(0xff8E7CFF);
      case 'task': return const Color(0xff2196F3);
      case 'companion': return const Color(0xffE91E63);
      case 'appointment': return const Color(0xffFF9800);
      case 'community': return const Color(0xff009688);
      default: return const Color(0xff9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped();

    return Scaffold(
      backgroundColor: const Color(0xffF7F4F2),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: Color(0xffF7F4F2),
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: Color(0xff4B3425), width: 2.0),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Color(0xff4B3425),
                    size: 25,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Row(
                children: [
                  const Text(
                    "Notifications",
                    style: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff4B3425),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (_unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xffFFD2C2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        "+$_unreadCount",
                        style: const TextStyle(
                          color: Color(0xffFE631B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (_unreadCount > 0)
                    GestureDetector(
                      onTap: _markAllAsRead,
                      child: const Text(
                        "Mark all read",
                        style: TextStyle(
                          color: Color(0xff4B3425),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 33),

              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator(color: Color(0xff4B3425))),
                )
              else if (_notifications.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      "No notifications yet",
                      style: TextStyle(color: Color(0xff706A66), fontSize: 16),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    children: grouped.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xff4B3425),
                                fontSize: 20,
                              ),
                            ),
                          ),
                          ...entry.value.map((n) => _notificationCard(n)),
                          const SizedBox(height: 20),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notificationCard(NotificationModel n) {
    return GestureDetector(
      onTap: () => _onTap(n),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _colorFor(n.type, n.priority),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(_iconFor(n.type), color: Colors.white),
            ),

            const SizedBox(width: 15),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xff4B3425),
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.subtitle,
                    style: const TextStyle(
                      color: Color(0xff706A66),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),

            if (!n.isRead)
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
