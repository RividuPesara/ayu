import 'package:flutter/material.dart';
import 'package:mobile_app/Donation/donation_service.dart';
import 'package:mobile_app/Donation/docStatusScreen.dart';
import 'package:mobile_app/Donation/uploadDocScreen.dart';

// Fetches existing application status and routes
class DonationEntryScreen extends StatefulWidget {
  const DonationEntryScreen({super.key});

  @override
  State<DonationEntryScreen> createState() => _DonationEntryScreenState();
}

class _DonationEntryScreenState extends State<DonationEntryScreen> {
  final _service = DonationService();

  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    try {
      final status = await _service.fetchStatus();
      if (!mounted) return;

      if (status == null) {
        // No application yet go to upload
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UploadDocumentScreen()),
        );
      } else {
        // Application existsshow its status
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentStatusScreen(
              status: status.status,
              rejectionReason: status.rejectionReason,
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      // On error default to upload screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UploadDocumentScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5F1EF),
      body: Center(child: CircularProgressIndicator(color: Color(0xFF745BA6))),
    );
  }
}
