import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobile_app/homeScreen.dart';
import 'package:mobile_app/Login Section/onboardingQuiz.dart';
import 'package:mobile_app/Mood Journal/moodSelectorScreen.dart';
import 'package:mobile_app/dashboard_cache.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance
        .authStateChanges()
        .first
        .then((user) {
      if (user != null) DashboardCache.instance.preload();
    });
    Future.delayed(const Duration(seconds: 6), _route);
  }

  Future<void> _route() async {
    if (!mounted) return;

    if (const bool.fromEnvironment('DEV_BYPASS')) {
      _go(const MoodSelectorScreen());
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _go(const WelcomeScreen());
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final profile = doc.data()?['patientProfile'];
    final quizDone =
        profile is Map && (profile['interests'] as List?)?.isNotEmpty == true;

    if (!quizDone) {
      _go(const Quiz());
      return;
    }

    _go(const MoodSelectorScreen());
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDE7F6),
      body: Center(
        child: Lottie.asset(
          'assets/splash.json',
          width: 700,
          height: 700,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
