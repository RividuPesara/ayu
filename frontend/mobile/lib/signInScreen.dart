import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile_app/Login%20Section/loginScreen.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  void _openTerms() {

  }

  void _openPrivacy() {

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDE7F6),
      body: Stack(
        children: [
          Positioned(
            top: -30,
            left: -20,
            right: -20,
            child: Image.asset(
              'assets/signin.jpeg',
              height: MediaQuery.of(context).size.height * 0.72,
              fit: BoxFit.contain,
            ),
          ),

          Positioned(
            bottom: -50,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: TopArcClipper(),
              child: Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.50,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      spreadRadius: 0, // soft shadow
                      offset: Offset(0, -10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.urbanist(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4B3425),
                        ),
                        children: [
                          const TextSpan(
                              text: "\nLet's get you started! How would you like to "),
                          const TextSpan(
                            text: "sign in",
                            style: TextStyle(color: Color(0xFF9BB068)),
                          ),
                          const TextSpan(text: "?"),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Google Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4B3425),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () {},
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset(
                              'assets/google.svg',
                              height: 20,
                              width: 20,
                              fit: BoxFit.contain,
                              colorFilter: const ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "Continue with Google",
                              style: GoogleFonts.urbanist(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 17),

                    // Email Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFF7F4F2),
                          side: const BorderSide(color: Color(0xFFF7F4F2)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => LoginScreen()),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset(
                              'assets/email.svg',
                              height: 20,
                              width: 20,
                              fit: BoxFit.contain,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFF4B3425),
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "Continue with Email",
                              style: GoogleFonts.urbanist(
                                fontSize: 18,
                                color: Color(0xFF4B3425),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 45),

                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.urbanist(
                          fontSize: 20,
                          color: Color(0xFF4B3425),
                        ),
                        children: [
                          const TextSpan(text: "By continuing, you agree to\nour "),
                          TextSpan(
                            text: "Terms of Service",
                            style: const TextStyle(
                              color: Color(0xFF7152FF),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()..onTap = _openTerms,
                          ),
                          const TextSpan(text: " and "),
                          TextSpan(
                            text: "Privacy Policy",
                            style: const TextStyle(
                              color: Color(0xFF7152FF),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()..onTap = _openPrivacy,
                          ),
                        ],
                      ),
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
}

class TopArcClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 60);
    path.quadraticBezierTo(
      size.width / 2, 0,
      size.width, 60,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}