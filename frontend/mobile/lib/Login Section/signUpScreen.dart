import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app/core/auth/auth_service.dart';
import 'package:mobile_app/Login%20Section/emailVerificationScreen.dart';
import 'package:mobile_app/Login%20Section/loginScreen.dart';
import 'package:mobile_app/Login%20Section/otpScreen.dart';
import 'package:mobile_app/core/theme/app_typography.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // Boolean to toggle the visibility of the password characters
  bool isPasswordHidden = true;
  // Controllers to capture user input from the various registration fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    // Release resources by disposing controllers when the screen is destroyed
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Handles the logic for creating a new user account
  Future<void> _handleSignUp() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Checks if the user left any required fields empty
    if (firstName.isEmpty || lastName.isEmpty) {
      _showMessage(context.t('signUp.errName'));
      return;
    }
    if (phone.isEmpty) {
      _showMessage(context.t('signUp.errMobile'));
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      _showMessage(context.t('signUp.errEmailPass'));
      return;
    }

    try {
      // Calls the authentication service to begin the signup process
      final result = await AuthService.instance.startSignupFlow(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        password: password,
      );

      if (!mounted) {
        return;
      }

      // Navigates to email verification if the account needs activation
      if (result.nextStep == AuthNextStep.emailVerification) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(email: result.email),
          ),
        );
        return;
      }

      // Navigates to the OTP screen if secondary verification is required
      final session = result.otpSession;
      if (session == null) {
        _showMessage(context.t('login.errOtpStart'));
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => OtpScreen(session: session)),
      );
    } catch (error) {
      // Shows the specific error message to the user if signup fails
      _showMessage('Sign up failed. ${_formatError(error)}');
    }
  }

  // Helper method to display a snackbar notification
  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // Cleans the error string for a user-friendly display
  String _formatError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFA682DF),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background illustration at the top
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Image.asset(
              "assets/login.png",
              height: size.height * 0.45,
              fit: BoxFit.contain,
            ),
          ),

          // Form Container
          Positioned(
            bottom: 0,
            child: Container(
              width: size.width,
              height: size.height * 0.66,
              padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 24),
              decoration: const BoxDecoration(
                color: Color(0xFFF7F4F2),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(55),
                  topRight: Radius.circular(55),
                ),
              ),

              // Scrollable Form
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildLabel(context.t('signUp.firstName')),
                    buildTextField(
                      context.t('signUp.firstNameHint'),
                      controller: _firstNameController,
                    ),

                    const SizedBox(height: 16),

                    buildLabel(context.t('signUp.lastName')),
                    buildTextField(
                      context.t('signUp.lastNameHint'),
                      controller: _lastNameController,
                    ),

                    const SizedBox(height: 16),

                    buildLabel(context.t('signUp.mobile')),
                    buildTextField(
                      context.t('signUp.mobileHint'),
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 16),

                    buildLabel(context.t('login.emailLabel')),
                    buildTextField(
                      context.t('signUp.emailHint'),
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),

                    const SizedBox(height: 16),

                    buildLabel(context.t('login.passwordLabel')),
                    buildPasswordField(),

                    const SizedBox(height: 20),

                    // Terms Text with clickable links
                    Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: urbanist(
                            fontSize: 15,
                            color: const Color(0xFF4B4544),
                            fontWeight: FontWeight.normal,
                          ),
                          children: [
                            TextSpan(
                              text: context.t('signUp.legalPrefix'),
                            ),
                            TextSpan(
                              text: context.t('signUp.termsOfUse'),
                              style: urbanist(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF4B4544),
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  // Terms of use
                                  debugPrint("Terms of Use clicked");
                                },
                            ),
                            TextSpan(text: context.t('signUp.and')),
                            TextSpan(
                              text: context.t('signUp.privacyPolicy'),
                              style: urbanist(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF4B4544),
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  // Privacy policy link
                                  debugPrint("Privacy Policy clicked");
                                },
                            ),
                            const TextSpan(text: "."),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Sign Up Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _handleSignUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFAC836C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          context.t('signUp.submit'),
                          style: urbanist(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.t('signUp.haveAccount'),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LoginScreen(),
                              ),
                            );
                          },
                          child: Text(
                            context.t('signUp.logIn'),
                            style: urbanist(
                              color: const Color(0xFF7152FF),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Reusable label widget for the input fields
  Widget buildLabel(String text) {
    return Text(
      text,
      style: urbanist(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF4B3425),
      ),
    );
  }

  Widget buildTextField(
    String hint, {
    IconData? icon,
    TextEditingController? controller,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType ?? TextInputType.text,
          decoration: InputDecoration(
            prefixIcon: icon != null ? Icon(icon) : null,
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  // Specialized password field with a toggle to show/hide text
  Widget buildPasswordField() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _passwordController,
          obscureText: isPasswordHidden,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline),
            hintText: context.t('login.passwordHint'),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: IconButton(
              icon: Icon(
                isPasswordHidden ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                setState(() {
                  isPasswordHidden = !isPasswordHidden;
                });
              },
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}
