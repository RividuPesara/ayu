import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_app/Connect%20Doctor/appointment_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AppointmentDetailScreen extends StatelessWidget {
  const AppointmentDetailScreen({super.key, required this.appointment});

  final MobileAppointment appointment;

  Future<void> _joinMeeting(BuildContext context) async {
    final fallbackJoinUrl = _buildZoomJoinUrl(
      appointment.zoomMeetingId ?? "",
      appointment.zoomPasscode,
    );
    final url = appointment.zoomJoinUrl ?? fallbackJoinUrl;

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Zoom meeting link is not available.")),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid meeting link.")));
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to open Zoom meeting.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prescriptions = <PrescriptionItem>[
      if (appointment.prescriptionUrl != null &&
          appointment.prescriptionUrl!.isNotEmpty)
        PrescriptionItem(
          name: appointment.prescriptionFilename ?? 'Prescription',
          uploadedBy: appointment.doctorName,
          uploadedAt: appointment.displayDate,
          url: appointment.prescriptionUrl,
        ),
      if (appointment.documentationUrl != null &&
          appointment.documentationUrl!.isNotEmpty)
        PrescriptionItem(
          name: appointment.documentationFilename ?? 'Documentation',
          uploadedBy: appointment.doctorName,
          uploadedAt: appointment.displayDate,
          url: appointment.documentationUrl,
        ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F1EF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),

              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF6A4A3C).withOpacity(0.85),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 30,
                    color: Color(0xFF4B3425),
                  ),
                ),
              ),

              const SizedBox(height: 26),

              const Text(
                'Appointment Details',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4B3425),
                  height: 1.1,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Zoom Meeting Details ${appointment.doctorName}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF7B6E67),
                ),
              ),

              const SizedBox(height: 22),

              Container(
                width: double.infinity,
                height: 280,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1D5DE6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.videocam_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'PLATFORM',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: Color(0xFF7B6E67),
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'zoom',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1662F2),
                                  height: 0.95,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'AT',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                color: Color(0xFF7B6E67),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              appointment.displayTime,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4B3425),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 33),

                    _DetailRow(
                      label: 'MEETING ID',
                      value: appointment.zoomMeetingId ?? '—',
                      showCopy: true,
                      onCopy: () {
                        if (appointment.zoomMeetingId != null) {
                          Clipboard.setData(
                            ClipboardData(text: appointment.zoomMeetingId!),
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    _DetailRow(
                      label: 'PASSCODE',
                      value: appointment.zoomPasscode ?? '—',
                      showCopy: true,
                      onCopy: () {
                        if (appointment.zoomPasscode != null) {
                          Clipboard.setData(
                            ClipboardData(text: appointment.zoomPasscode!),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _joinMeeting(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4B3425),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Join Appointment',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),

              const Text(
                'Uploaded Documents',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4B3425),
                ),
              ),

              const SizedBox(height: 20),

              prescriptions.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'No documents uploaded by the doctor yet.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8A7E78),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : Column(
                      children: prescriptions
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PrescriptionCard(item: item),
                            ),
                          )
                          .toList(),
                    ),

              const SizedBox(height: 22),
            ],
          ),
        ),
      ),
    );
  }
}

String _buildZoomJoinUrl(String meetingId, String? passcode) {
  final cleanedId = meetingId.replaceAll(RegExp(r"\s+"), "");
  if (cleanedId.isEmpty) {
    return "";
  }

  if (passcode == null || passcode.isEmpty) {
    return "https://zoom.us/j/$cleanedId";
  }

  return "https://zoom.us/j/$cleanedId?pwd=$passcode";
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool showCopy;
  final VoidCallback? onCopy;

  const _DetailRow({
    required this.label,
    required this.value,
    this.showCopy = false,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: Color(0xFF7B6E67),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E1D11),
                ),
              ),
            ],
          ),
        ),
        if (showCopy)
          GestureDetector(
            onTap: onCopy,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFDCD5F3)),
              ),
              child: const Icon(
                Icons.copy_rounded,
                size: 17,
                color: Color(0xFF8372B4),
              ),
            ),
          ),
      ],
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  final PrescriptionItem item;

  const _PrescriptionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF4EFEA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: Color(0xFF5A3B2B),
              size: 22,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3D2A20),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Uploaded by ${item.uploadedBy} • ${item.uploadedAt}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8A7E78),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              if (item.url == null || item.url!.isEmpty) {
                return;
              }
              final uri = Uri.tryParse(item.url!);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF5A3B2B),
              size: 29,
            ),
          ),
        ],
      ),
    );
  }
}

class PrescriptionItem {
  final String name;
  final String uploadedBy;
  final String uploadedAt;
  final String? url;

  PrescriptionItem({
    required this.name,
    required this.uploadedBy,
    required this.uploadedAt,
    this.url,
  });
}
