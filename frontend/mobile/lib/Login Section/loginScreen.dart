import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/auth/auth_service.dart';
import 'package:mobile_app/Login%20Section/emailVerificationScreen.dart';
import 'package:mobile_app/Login%20Section/otpScreen.dart';
import 'package:mobile_app/Login%20Section/signUpScreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers to capture text input for email and password
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  String? _errorMessage;

  @override
  void dispose() {
    // Clean up controllers when the screen is removed to save memory
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Main logic for authenticating the user
  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Clear any previous error message before trying again
    _clearError();

    // Basic validation to ensure fields aren't empty before calling the service
    if (email.isEmpty || password.isEmpty) {
      _setError('Please enter both email and password.');
      return;
    }

    try {
      // Initiates the multi-step login process via the AuthService
      final result = await AuthService.instance.startLoginFlow(
        email: email,
        password: password,
      );

      // Ensures the app doesn't try to navigate if the user left the screen during the wait
      if (!mounted) {
        return;
      }

      // Route to Email Verification if the user hasn't clicked their activation link yet
      if (result.nextStep == AuthNextStep.emailVerification) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(email: result.email),
          ),
        );
        return;
      }

      // Route to OTP screen if MFA is required to complete the login
      final session = result.otpSession;
      if (session == null) {
        _showMessage('Unable to start OTP verification.');
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => OtpScreen(session: session)),
      );
    } catch (error) {
      _setError(_formatError(error));
    }
  }

  // Logic to trigger a Firebase password reset email
  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      _showMessage('Password reset email sent.');
    } catch (error) {
      _setError(_formatError(error));
    }
  }

  // Helper function to save an inline error message for the UI
  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
    });
  }

  // Helper function to clear the inline error message
  void _clearError() {
    if (!mounted) return;
    setState(() {
      _errorMessage = null;
    });
  }

  // Helper function to show a Snackbar message at the bottom of the screen
  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // Cleans up system error strings to make them more readable for users
  String _formatError(Object error) {
    if (error is FirebaseAuthException) {
      final code = error.code.toLowerCase();
      if (code.contains('invalid-email') ||
          error.message?.toLowerCase().contains('invalid email') == true) {
        return 'Please enter a valid email address.';
      }
      return 'Incorrect password. Please try again.';
    }

    if (error is StateError) {
      return error.message;
    }

    final message = error.toString();
    final lower = message.toLowerCase();
    if (lower.contains('invalid-email') || lower.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }
    return 'Incorrect password. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFA682DF),
      body: Stack(
        children: [
          // Top section displaying the header illustration
          Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/login.png',
              width: size.width,
              height: size.height * 0.45,
              fit: BoxFit.cover,
            ),
          ),

          // Login form container
          Positioned(
            bottom: -30,
            child: Container(
              width: size.width,
              height: size.height * 0.49,
              padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 32),
              decoration: const BoxDecoration(
                color: Color(0xFFF7F4F2),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(62),
                  topRight: Radius.circular(62),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE4E1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFB3B0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Color(0xFFD32F2F),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFD32F2F),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Text(
                    "Email Address",
                    style: GoogleFonts.urbanist(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4B3425),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 15,
                          spreadRadius: 1,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_outlined),
                        hintText: "princesskaguya@gmail.com",
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Password Field
                  Text(
                    "Password",
                    style: GoogleFonts.urbanist(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4B3425),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 15,
                          spreadRadius: 1,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleSignIn(),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        hintText: "Enter your password...",
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: const Color(0xFF4B3425),
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Sign In Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _handleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4B3425),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            "Sign In",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight(700),
                              color: Color(0xFFF7F4F2),
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, color: Color(0xFFF7F4F2)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Links
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(fontSize: 18),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SignUpScreen(),
                            ),
                          );
                        },
                        child: Text(
                          "Sign Up",
                          style: GoogleFonts.urbanist(
                            color: Color(0xFF7152FF),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 13),

                  // Navigation link for password recovery
                  Center(
                    child: GestureDetector(
                      onTap: _handleForgotPassword,
                      child: Text(
                        "Forgot Password",
                        style: TextStyle(
                          color: Color(0xFF7152FF),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
