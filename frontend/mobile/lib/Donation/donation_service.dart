import 'dart:convert';
import 'package:mobile_app/core/network/backend_connector.dart';

class DonationStatus {
  final String applicationId;
  final String status;
  final String? rejectionReason;
  final String createdAt;
  final String updatedAt;

  DonationStatus({
    required this.applicationId,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DonationStatus.fromJson(Map<String, dynamic> json) {
    return DonationStatus(
      applicationId: json['applicationId'] as String,
      status: json['status'] as String,
      rejectionReason: json['rejectionReason'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }
}

class DonationService {
  DonationService({BackendConnector? backend})
    : _backend = backend ?? BackendConnector.instance;

  final BackendConnector _backend;

  // Returns null when the patient has no application yet
  Future<DonationStatus?> fetchStatus() async {
    final response = await _backend.get('/donation/status');
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch donation status: ${response.statusCode}',
      );
    }
    return DonationStatus.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // Returns the applicationId on success
  Future<String> submitDonation({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    final response = await _backend.multipartPost(
      '/donation/submit',
      'file',
      bytes,
      filename,
      contentType: contentType,
    );
    if (response.statusCode == 409) {
      throw const DonationConflictException();
    }
    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['applicationId'] as String;
  }

  static String mimeFromFilename(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'pdf': 'application/pdf',
    };
    return map[ext] ?? 'application/octet-stream';
  }
}

class DonationConflictException implements Exception {
  const DonationConflictException();
  @override
  String toString() => 'You already have an active donation application.';
}
