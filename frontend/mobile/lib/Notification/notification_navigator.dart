import 'package:flutter/material.dart';
import 'package:mobile_app/Community/communityFeedScreen.dart';
import 'package:mobile_app/Connect%20Doctor/docAppointmentScreen.dart';
import 'package:mobile_app/Mood%20Journal/moodSelectorScreen.dart';
import 'package:mobile_app/Tracker/trackerScreen.dart';
import 'package:mobile_app/companion-dashboard/compDashboard.dart';
import 'package:mobile_app/todoListScreen.dart';

// shared navigator key so notification tap handlers can navigate from outside the widget tree
final GlobalKey<NavigatorState> notificationNavigatorKey =
    GlobalKey<NavigatorState>();

// single source of truth for route string to screen its used by both the OS banner
Widget? screenForRoute(String route) {
  if (route == 'tracker') return const TrackerScreen();
  if (route == 'todo') return const ToDoList();
  if (route == 'mood_selector') return const MoodSelectorScreen();
  if (route == 'appointments') return const DoctorAppointmentScreen();
  if (route == 'mood_status') return const CompanionDashboard();
  if (route.startsWith('post:')) {
    return CommunityScreen(focusPostId: route.substring(5));
  }
  return null;
}

void navigateFromRoute(String? route) {
  if (route == null || route.isEmpty) return;

  final context = notificationNavigatorKey.currentContext;
  if (context == null) return;

  final screen = screenForRoute(route);
  if (screen != null) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}
