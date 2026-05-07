import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),

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
                    "Make a Request",
                    style: TextStyle(
                      fontSize: 24,
                      fontFamily: 'Urbanist',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B3425),
                    ),
                  ),
                ],
              ),

              // Lottie Image
              Expanded(
                child: Center(
                  child: Lottie.asset(
                    "assets/comingsoon.json",
                    width: 420,
                    height: 520,
                    fit: BoxFit.contain,
                    repeat: true,
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