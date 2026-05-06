import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_app/core/network/backend_connector.dart';

class PatientProfile {
  PatientProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.status,
  });

  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String avatarUrl;
  final String status;

  String get firstName {
    final parts = fullName.trim().split(' ');
    return parts.first;
  }

  String get lastName {
    final parts = fullName.trim().split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    return PatientProfile(
      uid: (json['uid'] ?? '') as String,
      fullName: (json['full_name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      avatarUrl: (json['avatar_url'] ?? '') as String,
      status: (json['status'] ?? 'active') as String,
    );
  }
}

class PatientService {
  PatientService({BackendConnector? backend})
      : _backend = backend ?? BackendConnector.instance;

  final BackendConnector _backend;

  Future<PatientProfile> fetchProfile() async {
    final response = await _backend.get('/patient/profile');
    _assertOk(response);
    return PatientProfile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<PatientProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{};
    if (firstName != null) body['first_name'] = firstName;
    if (lastName != null) body['last_name'] = lastName;
    if (phone != null) body['phone'] = phone;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;

    final response = await _backend.patch('/patient/profile', body: body);
    _assertOk(response);
    return PatientProfile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String> uploadAvatar(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final filename = imageFile.name;
    final mimeType = imageFile.mimeType ?? _mimeFromName(filename);

    final response = await _backend.multipartPost(
      '/patient/profile/avatar',
      'avatar',
      bytes,
      filename,
      contentType: mimeType,
    );
    _assertOk(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return (json['avatar_url'] ?? '') as String;
  }

  String _mimeFromName(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    const map = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp'};
    return map[ext] ?? 'image/jpeg';
  }

  void _assertOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String detail = 'Request failed (${response.statusCode})';
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final raw = decoded['detail'];
        if (raw is String && raw.isNotEmpty) detail = raw;
      } catch (_) {}
      throw Exception(detail);
    }
  }
}
