import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/Login%20Section/loginScreen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool isPasswordHidden = true;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFA682DF),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
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
                    buildLabel("First Name"),
                    buildTextField("Enter your First Name..."),

                    const SizedBox(height: 16),

                    buildLabel("Last Name"),
                    buildTextField("Enter your Last Name..."),

                    const SizedBox(height: 16),

                    buildLabel("Mobile Number"),
                    buildTextField("Enter your Mobile Number..."),

                    const SizedBox(height: 16),

                    buildLabel("Email Address"),
                    buildTextField(
                      "Enter your email...",
                      icon: Icons.email_outlined,
                    ),

                    const SizedBox(height: 16),

                    buildLabel("Password"),
                    buildPasswordField(),

                    const SizedBox(height: 20),

                    // Terms Text with clickable links
                    Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GoogleFonts.urbanist(
                            fontSize: 15,
                            color: const Color(0xFF4B4544),
                            fontWeight: FontWeight.normal,
                          ),
                          children: [
                            const TextSpan(text: "By continuing, you agree to\n"),
                            TextSpan(
                              text: "Terms of Use",
                              style: GoogleFonts.urbanist(
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
                            const TextSpan(text: " and "),
                            TextSpan(
                              text: "Privacy Policy",
                              style: GoogleFonts.urbanist(
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
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFAC836C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          "Sign Up",
                          style: GoogleFonts.urbanist(
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
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => LoginScreen()),
                            );
                          },
                          child: Text(
                            "Log In",
                            style: GoogleFonts.urbanist(
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

  Widget buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.urbanist(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF4B3425),
      ),
    );
  }

  Widget buildTextField(String hint, {IconData? icon}) {
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
          keyboardType: TextInputType.text,
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
          obscureText: isPasswordHidden,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline),
            hintText: "Enter your password...",
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