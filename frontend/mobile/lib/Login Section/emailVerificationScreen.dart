import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/auth/auth_service.dart';
import 'package:mobile_app/Login%20Section/otpScreen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({required this.email, super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  // Tracks if the app is currently communicating with the server
  bool _isLoading = false;

  // Handles the logic when the user clicks 'Continue' after verifying their email
  Future<void> _handleContinue() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Refresh the user data and check if the email link was clicked
      final verified = await AuthService.instance.reloadAndCheckEmailVerified();
      if (!verified) {
        _showMessage('Email is not verified yet. Please check your inbox.');
        return;
      }

      // If verified, start the SMS verification process
      final session = await AuthService.instance
          .startPhoneEnrollmentForCurrentUser();

      // Safety check to ensure the screen is still active before navigating
      if (!mounted) {
        return;
      }

      // Move the user to the OTP entry screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => OtpScreen(session: session)),
      );
    } catch (error) {
      // Display any errors that occurred during the process
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      // Reset the loading state once the operation is finished
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Triggers a new verification email to be sent to the user's address
  Future<void> _handleResend() async {
    try {
      await AuthService.instance.resendEmailVerification();
      _showMessage('Verification email sent again.');
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  // Helper method to show a quick feedback message at the bottom of the screen
  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2EF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button to return to the previous screen
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF4B3425)),
                  ),
                  child: const Icon(Icons.arrow_back, size: 18),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Verify your email',
                style: GoogleFonts.urbanist(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF4B3425),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a verification link to:',
                style: GoogleFonts.urbanist(
                  fontSize: 16,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              // Back button to return to the previous screen
              Text(
                widget.email,
                style: GoogleFonts.urbanist(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4B3425),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'After you verify, press Continue to set up OTP.',
                style: GoogleFonts.urbanist(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 30),
              // Main action button to proceed to the next stage of signup
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4B3425),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Continue',
                          style: GoogleFonts.urbanist(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              // Secondary button for users who didn't receive the email
              Center(
                child: TextButton(
                  onPressed: _handleResend,
                  child: Text(
                    'Resend email',
                    style: GoogleFonts.urbanist(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF7152FF),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
