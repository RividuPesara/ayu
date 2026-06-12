import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String dedupeKey;
  final String title;
  final String subtitle;
  final String type;
  final String priority;
  final String source;
  final String route;
  bool isRead;
  final DateTime createdAt;
  final DateTime? fireAt;
  final DateTime? deliveredAt;

  NotificationModel({
    required this.dedupeKey,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.priority,
    required this.source,
    required this.route,
    required this.isRead,
    required this.createdAt,
    this.fireAt,
    this.deliveredAt,
  });

  // build from a firestore doc
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      dedupeKey: doc.id,
      title: d['title'] ?? '',
      subtitle: d['subtitle'] ?? '',
      type: d['type'] ?? '',
      priority: d['priority'] ?? 'normal',
      source: d['source'] ?? 'push',
      route: d['route'] ?? '',
      isRead: d['isRead'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fireAt: (d['fireAt'] as Timestamp?)?.toDate(),
      deliveredAt: (d['deliveredAt'] as Timestamp?)?.toDate(),
    );
  }

  // build from local cache json
  factory NotificationModel.fromJson(Map<String, dynamic> j) {
    return NotificationModel(
      dedupeKey: j['dedupeKey'],
      title: j['title'],
      subtitle: j['subtitle'],
      type: j['type'],
      priority: j['priority'] ?? 'normal',
      source: j['source'] ?? 'push',
      route: j['route'] ?? '',
      isRead: j['isRead'] ?? false,
      createdAt: DateTime.parse(j['createdAt']),
      fireAt: j['fireAt'] != null ? DateTime.parse(j['fireAt']) : null,
      deliveredAt: j['deliveredAt'] != null ? DateTime.parse(j['deliveredAt']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'dedupeKey': dedupeKey,
        'title': title,
        'subtitle': subtitle,
        'type': type,
        'priority': priority,
        'source': source,
        'route': route,
        'isRead': isRead,
        'createdAt': createdAt.toIso8601String(),
        'fireAt': fireAt?.toIso8601String(),
        'deliveredAt': deliveredAt?.toIso8601String(),
      };

  // helpers for shared prefs list serialisation
  static String encodeList(List<NotificationModel> list) =>
      jsonEncode(list.map((n) => n.toJson()).toList());

  static List<NotificationModel> decodeList(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => NotificationModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
