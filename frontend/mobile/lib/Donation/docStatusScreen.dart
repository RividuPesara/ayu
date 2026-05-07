import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobile_app/Donation/comingSoon.dart';
import 'package:mobile_app/Donation/uploadDocScreen.dart';

class DocumentStatusScreen extends StatelessWidget {
  final String status;
  final String? rejectionReason;

  const DocumentStatusScreen({
    super.key,
    required this.status,
    this.rejectionReason,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  @override
  Widget build(BuildContext context) {
    final String lottieIcon = isApproved
        ? 'assets/success.json'
        : isRejected
        ? 'assets/error.json'
        : 'assets/sandclock.json';

    final String label = isApproved
        ? 'APPROVED'
        : isRejected
        ? 'REJECTED'
        : 'WAITING';

    final String title = isApproved
        ? 'Document Approved'
        : isRejected
        ? 'Document Rejected'
        : 'In Review';

    final String description = isApproved
        ? 'Your credentials and documentation\nhave been verified by our compliance team.'
        : isRejected
        ? (rejectionReason != null && rejectionReason!.isNotEmpty
            ? rejectionReason!
            : "We couldn't verify your identity with the documents provided.")
        : 'Your document is currently being reviewed by our admins.\nResults will be provided soon.';

    final String buttonText = isApproved
        ? 'Make a request'
        : isRejected
        ? 'Resubmit'
        : 'Make a request';

    final bool buttonEnabled = !isPending;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3F1),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF4B3425),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Color(0xFF4B3425),
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  const Text(
                    "Document Status",
                    style: TextStyle(
                      fontSize: 24,
                      fontFamily: 'Urbanist',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B3425),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // White Container Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 30,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Lottie Icon
                    Lottie.asset(
                      lottieIcon,
                      width: 85,
                      height: 85,
                      repeat: isPending,
                    ),

                    const SizedBox(height: 20),

                    // Status Label
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 25, vertical: 6),
                      decoration: BoxDecoration(
                        color: isApproved
                            ? Colors.green.withOpacity(0.1)
                            : isRejected
                            ? Colors.red.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isApproved
                              ? Colors.green
                              : isRejected
                              ? Colors.red
                              : Colors.orange,
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Title
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Description
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),

                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Cat image
              Image.asset(
                'assets/doccat.png',
                height: 240,
              ),

              const Spacer(),

              // Button
              Opacity(
                opacity: buttonEnabled ? 1 : 0.9,
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: buttonEnabled ? () {
                      if (isApproved) {
                        // Navigate to coming soon screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ComingSoonScreen(),
                          ),
                        );
                      } else if (isRejected) {
                        // Navigate to upload screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UploadDocumentScreen(),
                          ),
                        );
                      }
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonEnabled
                          ? const Color(0xFF5A3B2E)
                          : const Color(0xFFBFB7B2),
                      disabledBackgroundColor: const Color(0xFFBFB7B2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          buttonText,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),

                        if (!buttonEnabled) ...[
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 72),
            ],
          ),
        ),
      ),
    );
  }
}