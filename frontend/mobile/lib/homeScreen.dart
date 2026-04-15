import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/Chatbot/chatbotScreen.dart';
import 'package:mobile_app/signInScreen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFEDE7F6),
      body: Stack(
        children: [
          Positioned(
            top: -15,
            left: -50,
            right: -50,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.1), // 30% dark overlay
                BlendMode.darken,
              ),
              child: Image.asset(
                'assets/cat.png',
                height: 820,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Bottom White Container
          Positioned(
            bottom: -10,
            left: 0,
            right: 0,
            child: PhysicalShape(
              clipper: TopArcClipper(),
              color: Colors.white,
              elevation: 4,
              shadowColor: Colors.black26,
              child: Container(
                height: height * 0.48,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 44,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/logo.png', height: 110),

                    const SizedBox(height: 10),

                    // Title
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.urbanist(
                          fontSize: 49,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4B3425),
                        ),
                        children: [
                          TextSpan(text: "Welcome to "),
                          TextSpan(
                            text: "Ayu!",
                            style: TextStyle(color: Color(0xFFA18FFF)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Subtitle
                    Text(
                      "So glad you're here! Ayu is ready to help you every step of the way",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.urbanist(
                        fontSize: 22,
                        color: Color(0xFF4B3425),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Open Ayu chatbot (backend URL is set in Chatbot/chatbot_service.dart)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const Chatbot(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF64548E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Chat with Ayu',
                          style: GoogleFonts.urbanist(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Sign In
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SignInScreen(),
                          ),
                        );
                      },
                      child: Text.rich(
                        TextSpan(
                          text: "Already have an account? ",
                          style: GoogleFonts.urbanist(
                            fontSize: 19,
                            color: Color(0xFF4B3425),
                          ),
                          children: [
                            TextSpan(
                              text: "Sign In",
                              style: TextStyle(
                                color: Color(0xFFA18FFF),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
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
    path.moveTo(0, 80);
    path.quadraticBezierTo(size.width / 2, 0, size.width, 80);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
