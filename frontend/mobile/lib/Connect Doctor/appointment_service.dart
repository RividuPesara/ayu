import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mobile_app/core/network/backend_connector.dart';

class AppointmentSlotTime {
  AppointmentSlotTime({required this.time, required this.available});

  final String time;
  final bool available;

  factory AppointmentSlotTime.fromJson(Map<String, dynamic> json) {
    return AppointmentSlotTime(
      time: (json['time'] ?? '') as String,
      available: (json['available'] ?? false) as bool,
    );
  }

  String get displayLabel => _formatDisplayTime(time);
}

class AppointmentSlotDate {
  AppointmentSlotDate({
    required this.dateKey,
    required this.day,
    required this.weekday,
    required this.times,
  });

  final String dateKey;
  final String day;
  final String weekday;
  final List<AppointmentSlotTime> times;

  factory AppointmentSlotDate.fromJson(Map<String, dynamic> json) {
    final timesJson = json['times'] as List<dynamic>? ?? [];
    return AppointmentSlotDate(
      dateKey: (json['date_key'] ?? '') as String,
      day: (json['day'] ?? '') as String,
      weekday: (json['weekday'] ?? '') as String,
      times: timesJson
          .map(
            (item) =>
                AppointmentSlotTime.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  bool get hasAvailability => times.any((time) => time.available);
}

class AppointmentSlotsResponse {
  AppointmentSlotsResponse({required this.timezone, required this.dates});

  final String timezone;
  final List<AppointmentSlotDate> dates;

  factory AppointmentSlotsResponse.fromJson(Map<String, dynamic> json) {
    final datesJson = json['dates'] as List<dynamic>? ?? [];
    return AppointmentSlotsResponse(
      timezone: (json['timezone'] ?? '') as String,
      dates: datesJson
          .map(
            (item) =>
                AppointmentSlotDate.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class MobileAppointment {
  MobileAppointment({
    required this.id,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.doctorAvatarUrl,
    required this.dateKey,
    required this.time,
    required this.status,
    required this.type,
    this.zoomMeetingId,
    this.zoomPasscode,
    this.zoomJoinUrl,
    this.prescriptionUrl,
    this.prescriptionFilename,
    this.documentationUrl,
    this.documentationFilename,
  });

  final String id;
  final String doctorName;
  final String doctorSpecialty;
  final String doctorAvatarUrl;
  final String dateKey;
  final String time;
  final String status;
  final String type;
  final String? zoomMeetingId;
  final String? zoomPasscode;
  final String? zoomJoinUrl;
  final String? prescriptionUrl;
  final String? prescriptionFilename;
  final String? documentationUrl;
  final String? documentationFilename;

  factory MobileAppointment.fromJson(Map<String, dynamic> json) {
    return MobileAppointment(
      id: (json['id'] ?? '') as String,
      doctorName: (json['doctor_name'] ?? '') as String,
      doctorSpecialty: (json['doctor_specialty'] ?? '') as String? ?? '',
      doctorAvatarUrl: (json['doctor_avatar_url'] ?? '') as String? ?? '',
      dateKey: (json['date_key'] ?? '') as String? ?? '',
      time: (json['time'] ?? '') as String? ?? '',
      status: (json['status'] ?? 'upcoming') as String,
      type: (json['type'] ?? 'consultation') as String,
      zoomMeetingId: json['zoom_meeting_id'] as String?,
      zoomPasscode: json['zoom_passcode'] as String?,
      zoomJoinUrl: json['zoom_join_url'] as String?,
      prescriptionUrl: json['prescription_url'] as String?,
      prescriptionFilename: json['prescription_filename'] as String?,
      documentationUrl: json['documentation_url'] as String?,
      documentationFilename: json['documentation_filename'] as String?,
    );
  }

  String get displayDate => _formatDisplayDate(dateKey);

  String get displayTime => _formatDisplayTime(time);
}

class BookAppointmentRequest {
  BookAppointmentRequest({
    required this.dateKey,
    required this.time,
    required this.doctorUid,
    required this.doctorName,
    required this.doctorSpecialty,
  });

  final String dateKey;
  final String time;
  final String doctorUid;
  final String doctorName;
  final String doctorSpecialty;

  Map<String, dynamic> toJson() {
    return {
      'date_key': dateKey,
      'time': time,
      'doctor_uid': doctorUid,
      'doctor_name': doctorName,
      'doctor_specialty': doctorSpecialty,
    };
  }
}

class BookAppointmentResponse {
  BookAppointmentResponse({
    required this.appointmentId,
    required this.dateKey,
    required this.time,
    this.zoomMeetingId,
    this.zoomPasscode,
    this.zoomJoinUrl,
  });

  final String appointmentId;
  final String dateKey;
  final String time;
  final String? zoomMeetingId;
  final String? zoomPasscode;
  final String? zoomJoinUrl;

  factory BookAppointmentResponse.fromJson(Map<String, dynamic> json) {
    return BookAppointmentResponse(
      appointmentId: (json['appointment_id'] ?? '') as String,
      dateKey: (json['date_key'] ?? '') as String,
      time: (json['time'] ?? '') as String,
      zoomMeetingId: json['zoom_meeting_id'] as String?,
      zoomPasscode: json['zoom_passcode'] as String?,
      zoomJoinUrl: json['zoom_join_url'] as String?,
    );
  }
}

class AppointmentService {
  AppointmentService({BackendConnector? backend})
    : _backend = backend ?? BackendConnector.instance;

  final BackendConnector _backend;

  Future<AppointmentSlotsResponse> fetchSlots({
    required String doctorUid,
  }) async {
    final response = await _backend.get(
      '/appointments/slots',
      queryParameters: {'doctor_uid': doctorUid},
    );
    return _decodeResponse(response, AppointmentSlotsResponse.fromJson);
  }

  Future<BookAppointmentResponse> bookAppointment(
    BookAppointmentRequest request,
  ) async {
    final response = await _backend.post(
      '/appointments/book',
      body: request.toJson(),
    );
    return _decodeResponse(response, BookAppointmentResponse.fromJson);
  }

  Future<List<MobileAppointment>> listMyAppointments() async {
    final response = await _backend.get('/appointments/my');
    return _decodeListResponse(
      response,
      (item) => MobileAppointment.fromJson(item),
    );
  }

  T _decodeResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>) mapper,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return mapper(decoded);
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

String _formatDisplayDate(String dateKey) {
  final parts = dateKey.split('-');
  if (parts.length != 3) {
    return dateKey;
  }

  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);

  if (year == null || month == null || day == null) {
    return dateKey;
  }

  final date = DateTime(year, month, day);
  final weekdayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
  final monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final weekday = weekdayNames[date.weekday % 7];
  final monthLabel = monthNames[date.month - 1];
  return '${date.day} $monthLabel, $weekday';
}

String _formatDisplayTime(String time) {
  final parts = time.split(':');
  if (parts.length != 2) {
    return time;
  }

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return time;
  }

  final period = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  final minuteStr = minute.toString().padLeft(2, '0');
  final hourStr = hour12.toString().padLeft(2, '0');
  return '$hourStr.$minuteStr $period';
}
