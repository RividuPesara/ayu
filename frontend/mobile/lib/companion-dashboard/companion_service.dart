import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/network/backend_connector.dart';

class CompanionStatus {
  final bool hasPatient;
  final String? patientUid;
  final String? patientName;
  final String? patientAvatar;
  final String linkStatus;

  CompanionStatus({
    required this.hasPatient,
    this.patientUid,
    this.patientName,
    this.patientAvatar,
    this.linkStatus = 'active',
  });

  factory CompanionStatus.fromJson(Map<String, dynamic> json) {
    final companion = json['companion'] as Map<String, dynamic>?;
    return CompanionStatus(
      hasPatient: json['has_companion'] as bool? ?? false,
      patientUid: companion?['uid'] as String?,
      patientName: companion?['name'] as String?,
      patientAvatar: companion?['avatar'] as String?,
      linkStatus: companion?['status'] as String? ?? 'active',
    );
  }
}

class CompanionPrivacy {
  final bool moodJournal;
  final bool todoList;
  final bool tracking;
  final bool doctorAppointments;

  const CompanionPrivacy({
    this.moodJournal = true,
    this.todoList = false,
    this.tracking = true,
    this.doctorAppointments = true,
  });

  factory CompanionPrivacy.fromJson(Map<String, dynamic> json) {
    return CompanionPrivacy(
      moodJournal: json['mood_journal'] as bool? ?? true,
      todoList: json['todo_list'] as bool? ?? false,
      tracking: json['tracking'] as bool? ?? true,
      doctorAppointments: json['doctor_appointments'] as bool? ?? true,
    );
  }

  bool get hasAnyAccess =>
      moodJournal || todoList || tracking || doctorAppointments;
}

class CompanionDashboardService {
  CompanionDashboardService._();
  static final CompanionDashboardService instance =
      CompanionDashboardService._();

  final BackendConnector _backend = BackendConnector.instance;

  static const _quotes = [
    'You are not alone in this.',
    'Small acts of care make a big difference.',
    'Your support means more than words can say.',
    'Being there is the greatest gift.',
    'Compassion is the root of all healing.',
    'Together, every step is lighter.',
    'Your kindness is a source of strength.',
  ];

  static String pickDailyQuote() {
    final now = DateTime.now();
    final d = now.hour < 5 ? now.subtract(const Duration(days: 1)) : now;
    final dayOfYear = d.difference(DateTime(d.year, 1, 1)).inDays;
    return _quotes[dayOfYear % _quotes.length];
  }

  Future<({String fullName, String? avatarUrl})> loadOwnProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return (fullName: '', avatarUrl: null);
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = doc.data();
    final fullName = data?['fullName'] as String? ?? '';
    final avatar = data?['avatar'] as String?;
    return (
      fullName: fullName,
      avatarUrl: (avatar != null && avatar.isNotEmpty) ? avatar : null,
    );
  }

  Future<CompanionStatus> fetchStatus() async {
    try {
      final res = await _backend.get('/companion/status');
      if (res.statusCode == 200) {
        return CompanionStatus.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return CompanionStatus(hasPatient: false);
  }

  Future<CompanionPrivacy> fetchPrivacy() async {
    try {
      final res = await _backend.get('/companion/privacy');
      if (res.statusCode == 200) {
        return CompanionPrivacy.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return const CompanionPrivacy();
  }

  Future<PatientMoodStatus?> fetchPatientMoodStatus() async {
    try {
      final res = await _backend.get('/companion/patient-mood-status');
      if (res.statusCode == 200) {
        return PatientMoodStatus.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }
}

class PatientMoodStatus {
  final String currentStatus;
  final String emotionMessage;
  final bool hasCrisis;
  final bool recentEntryFlagged;
  final String lastActiveDateKey;

  const PatientMoodStatus({
    required this.currentStatus,
    required this.emotionMessage,
    required this.hasCrisis,
    required this.recentEntryFlagged,
    required this.lastActiveDateKey,
  });

  factory PatientMoodStatus.fromJson(Map<String, dynamic> json) {
    return PatientMoodStatus(
      currentStatus: json['current_status'] as String? ?? 'Mainly Neutral',
      emotionMessage: json['emotion_message'] as String? ?? '',
      hasCrisis: json['has_crisis'] as bool? ?? false,
      recentEntryFlagged: json['recent_entry_flagged'] as bool? ?? false,
      lastActiveDateKey: json['last_active_date_key'] as String? ?? '',
    );
  }
}
