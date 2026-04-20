import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mobile_app/core/network/backend_connector.dart';

class DoctorSummary {
  DoctorSummary({
    required this.uid,
    required this.fullName,
    required this.specialty,
    required this.phone,
    required this.avatarUrl,
    required this.email,
  });

  final String uid;
  final String fullName;
  final String specialty;
  final String phone;
  final String avatarUrl;
  final String email;

  factory DoctorSummary.fromJson(Map<String, dynamic> json) {
    return DoctorSummary(
      uid: (json['uid'] ?? '') as String,
      fullName: (json['full_name'] ?? '') as String? ?? '',
      specialty: (json['specialty'] ?? '') as String? ?? '',
      phone: (json['phone'] ?? '') as String? ?? '',
      avatarUrl: (json['avatar_url'] ?? '') as String? ?? '',
      email: (json['email'] ?? '') as String? ?? '',
    );
  }
}

class DoctorService {
  DoctorService({BackendConnector? backend})
    : _backend = backend ?? BackendConnector.instance;

  final BackendConnector _backend;

  Future<List<DoctorSummary>> fetchDoctors({int limit = 200}) async {
    final response = await _backend.get(
      '/doctors',
      queryParameters: {'limit': limit},
    );
    return _decodeListResponse(
      response,
      (item) => DoctorSummary.fromJson(item),
    );
  }

  List<T> _decodeListResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>) mapper,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response));
    }

    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.map((item) => mapper(item as Map<String, dynamic>)).toList();
  }

  String _extractErrorMessage(http.Response response) {
    if (response.body.isEmpty) {
      return 'Request failed. (${response.statusCode})';
    }

    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = decoded['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    } catch (_) {
      // ignore parse issues
    }

    return response.body;
  }
}
