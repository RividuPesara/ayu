import 'package:flutter/material.dart';
import 'package:mobile_app/core/auth/auth_service.dart';
import 'onboardingQuiz.dart';

class OtpScreen extends StatefulWidget {
  final AuthOtpSession session;
  final VoidCallback? onVerified;

  OtpScreen({required this.session, this.onVerified, super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final int otpLength = 6;

  late List<TextEditingController> controllers;
  late List<FocusNode> focusNodes;

  @override
  void initState() {
    super.initState();
    // Initialize a controller and focus node for each of the 6 OTP digits
    controllers = List.generate(otpLength, (index) => TextEditingController());
    focusNodes = List.generate(otpLength, (index) => FocusNode());
  }

  @override
  void dispose() {
    // Clean up all controllers and focus nodes when leaving the screen
    for (var c in controllers) {
      c.dispose();
    }
    for (var f in focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // Manages moving the cursor automatically between boxes as the user types
  void onChanged(String value, int index) {
    if (value.isNotEmpty) {
      if (index < otpLength - 1) {
        // Move to the next box if a digit was entered
        focusNodes[index + 1].requestFocus();
      } else {
        // Hide keyboard if the last digit was entered
        focusNodes[index].unfocus();
      }
    } else {
      if (index > 0) {
        // Move back to the previous box if the digit was deleted
        focusNodes[index - 1].requestFocus();
      }
    }
  }

  // Combines the text from all 6 individual boxes into a single OTP string
  String getOtp() {
    return controllers.map((c) => c.text).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2EF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // Header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Color(0xFF4B3425)),
                      ),
                      child: const Icon(Icons.arrow_back, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "OTP Setup",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4B3425),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 90),

              const Center(
                child: Text(
                  "Enter 6 digit OTP Code",
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF4B3425),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              const Center(
                child: Text(
                  "Scan your biometric fingerprint to make your\naccount more secure.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(height: 60),

              // OTP Input Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(otpLength, (index) => otpBox(index)),
              ),

              const SizedBox(height: 60),

              // Continue Button
              GestureDetector(
                onTap: () {
                  _handleVerify(context);
                },
                child: Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4B3425),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Center(
                    child: Text(
                      "Continue  →",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              const Center(
                child: Text.rich(
                  TextSpan(
                    text: "Didn't receive the OTP? ",
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    children: [
                      TextSpan(
                        text: "Re-send.",
                        style: TextStyle(
                          color: Color(0xFFFE814B),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // Sends the OTP to the backend and navigates to the next screen upon success
  Future<void> _handleVerify(BuildContext context) async {
    final otp = getOtp();
    try {
      // Calls the auth service to validate the entered code
      await AuthService.instance.verifyOtp(widget.session, otp);
      if (!mounted) {
        return;
      }

      // If a custom callback was provided, use it instead of default navigation
      if (widget.onVerified != null) {
        widget.onVerified!.call();
        return;
      }

      // Proceed to the onboarding quiz screen after successful verification
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Quiz()),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      // Show error message if the code is incorrect or expired
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  // OTP Box Widget
  Widget otpBox(int index) {
    return AnimatedBuilder(
      animation: focusNodes[index],
      builder: (context, child) {
        // Change UI appearance based on whether the box is currently active
        bool isFocused = focusNodes[index].hasFocus;

        return Container(
          width: 50,
          height: 56,
          decoration: BoxDecoration(
            color: isFocused ? const Color(0xFF7B6BA8) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: controllers[index],
            focusNode: focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            cursorColor: Colors.white,
            style: TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.bold,
              color: isFocused ? Colors.white : Color(0xFF4B3425),
            ),
            onTap: () {
              FocusScope.of(context).requestFocus(focusNodes[index]);
            },
            decoration: const InputDecoration(
              counterText: "",
              border: InputBorder.none,
            ),
            onChanged: (value) => onChanged(value, index),
          ),
        );
      },
    );
  }
}
