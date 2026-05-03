import 'package:flutter/material.dart';
import 'package:mobile_app/Companion/invitationSentScreen.dart';

class CompanionInviteScreen extends StatelessWidget {
  const CompanionInviteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF5F1EF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 23),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF6B5A4A),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 28,
                          color: Color(0xFF4B3425),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Companion',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2B211C),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isKeyboardOpen ? 10 : 75),

                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: isKeyboardOpen ? 130 : 260,
                    child: Image.asset(
                      'assets/companioncats.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                SizedBox(height: isKeyboardOpen ? 19 : 66),

                const Text(
                  'Build your circle',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F1A17),
                    height: 1.1,
                  ),
                ),

                const SizedBox(height: 13),

                const Text(
                  'Experience the journey together. Pair\n'
                      'with your partner to share insights and\n'
                      'stay connected effortlessly.',
                  style: TextStyle(
                    fontSize: 21,
                    height: 1.45,
                    color: Color(0xFF6F6660),
                    fontWeight: FontWeight.w500,
                  ),
                ),

                SizedBox(height: isKeyboardOpen ? 18 : 40),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "PARTNER'S EMAIL",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5F5650),
                          letterSpacing: 0.4,
                        ),
                      ),

                      const SizedBox(height: 19),

                      TextField(
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'name@example.com',
                          hintStyle: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF5F5650),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F3EE),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 33),

                      SizedBox(
                        width: double.infinity,
                        height: 53,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InvitationSentScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4B3425),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
                            'Send Invite',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}