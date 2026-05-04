import 'dart:convert';

import 'package:mobile_app/core/network/backend_connector.dart';

class CompanionInfo {
  final String uid;
  final String email;
  final String? name;
  final String? avatar;
  final String status;

  CompanionInfo({
    required this.uid,
    required this.email,
    this.name,
    this.avatar,
    required this.status,
  });

  factory CompanionInfo.fromJson(Map<String, dynamic> json) {
    return CompanionInfo(
      uid: (json['uid'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      name: json['name'] as String?,
      avatar: json['avatar'] as String?,
      status: (json['status'] ?? 'pending') as String,
    );
  }
}

class CompanionStatus {
  final bool hasCompanion;
  final CompanionInfo? companion;

  CompanionStatus({required this.hasCompanion, this.companion});

  factory CompanionStatus.fromJson(Map<String, dynamic> json) {
    return CompanionStatus(
      hasCompanion: (json['has_companion'] ?? false) as bool,
      companion: json['companion'] != null
          ? CompanionInfo.fromJson(json['companion'] as Map<String, dynamic>)
          : null,
    );
  }
}

class CompanionPrivacy {
  final bool moodJournal;
  final bool todoList;
  final bool tracking;
  final bool doctorAppointments;

  CompanionPrivacy({
    required this.moodJournal,
    required this.todoList,
    required this.tracking,
    required this.doctorAppointments,
  });

  factory CompanionPrivacy.fromJson(Map<String, dynamic> json) {
    return CompanionPrivacy(
      moodJournal: (json['mood_journal'] ?? true) as bool,
      todoList: (json['todo_list'] ?? false) as bool,
      tracking: (json['tracking'] ?? true) as bool,
      doctorAppointments: (json['doctor_appointments'] ?? true) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'mood_journal': moodJournal,
        'todo_list': todoList,
        'tracking': tracking,
        'doctor_appointments': doctorAppointments,
      };
}

class CompanionService {
  final _api = BackendConnector.instance;

  Future<String> sendInvite(String email) async {
    final response = await _api.post(
      '/companion/invite',
      body: {'email': email},
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['invite_id'] ?? '') as String;
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception((body['detail'] ?? 'Failed to send invite') as String);
  }

  Future<CompanionStatus> getStatus() async {
    final response = await _api.get('/companion/status');
    if (response.statusCode == 200) {
      return CompanionStatus.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw Exception('Failed to fetch companion status');
  }

  Future<CompanionPrivacy> getPrivacy() async {
    final response = await _api.get('/companion/privacy');
    if (response.statusCode == 200) {
      return CompanionPrivacy.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw Exception('Failed to fetch privacy settings');
  }

  Future<void> savePrivacy(CompanionPrivacy privacy) async {
    final response = await _api.post(
      '/companion/privacy',
      body: privacy.toJson(),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(
        (body['detail'] ?? 'Failed to save privacy settings') as String,
      );
    }
  }
}
