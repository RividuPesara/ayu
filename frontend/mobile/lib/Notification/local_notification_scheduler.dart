import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../Tracker/tracker_service.dart';
import 'notification_service.dart';

// single entry point for all local notification scheduling
class LocalNotificationScheduler {
  LocalNotificationScheduler._();
  static final instance = LocalNotificationScheduler._();

  // medication reminders

  // prefix for the stored list of scheduled times per medication
  static const _medTimesPrefix = 'med_reminder_times_';

  // call when tracker screen loads or a medication is added/updated
  Future<void> scheduleMedicationReminders(List<MedicationItem> meds) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    for (final med in meds) {
      // cancel existing reminders first so edited or removed times dont linger
      await _cancelMedicationReminders(med.medicationId);

      final scheduledTimes = <String>[];
      for (final time in med.times) {
        final parts = time.split(':');
        if (parts.length != 2) continue;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;

        final fireAt = _nextOccurrence(hour, minute);
        final dedupeKey = 'med:${med.medicationId}:$time';

        await NotificationService.instance.scheduleLocal(
          uid: uid,
          dedupeKey: dedupeKey,
          title: 'Time to take ${med.name}',
          subtitle: med.type,
          type: 'medication',
          route: 'tracker',
          fireAt: fireAt,
          matchComponents: DateTimeComponents.time,
        );
        scheduledTimes.add(time);
      }

      // remember exactly which times we scheduled so we can cancel them later
      await _storeScheduledTimes(med.medicationId, scheduledTimes);
    }
  }

  // call when a medication is deleted
  Future<void> cancelMedicationReminders(String medicationId) async {
    await _cancelMedicationReminders(medicationId);
  }

  Future<void> _cancelMedicationReminders(String medicationId) async {
    final times = await _readScheduledTimes(medicationId);
    for (final time in times) {
      await NotificationService.instance.cancelLocal('med:$medicationId:$time');
    }
    await _clearScheduledTimes(medicationId);
  }

  Future<void> _storeScheduledTimes(String medicationId, List<String> times) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_medTimesPrefix$medicationId', times);
  }

  Future<List<String>> _readScheduledTimes(String medicationId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('$_medTimesPrefix$medicationId') ?? [];
  }

  Future<void> _clearScheduledTimes(String medicationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_medTimesPrefix$medicationId');
  }

  // daily mood check-in

  // call on app start and after timezone change
  // schedules the recurring 8pm reminder
  Future<void> scheduleMoodCheckIn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    const dedupeKey = 'mood:daily-checkin';
    final fireAt = _nextOccurrence(20, 0); // 8pm

    // cancel existing before rescheduling so time is always fresh
    await NotificationService.instance.cancelLocal(dedupeKey);

    await NotificationService.instance.scheduleLocal(
      uid: uid,
      dedupeKey: dedupeKey,
      title: 'How are you feeling today?',
      subtitle: 'Log your mood',
      type: 'mood',
      route: 'mood_selector',
      fireAt: fireAt,
      matchComponents: DateTimeComponents.time,
    );
  }

  // call when the daily pulse is recorded to suppress todays reminder
  // and re-arm for tomorrow
  Future<void> onPulseRecorded() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    const dedupeKey = 'mood:daily-checkin';
    await NotificationService.instance.cancelLocal(dedupeKey);

    // always schedule for tomorrow since today was already recorded
    final now = tz.TZDateTime.now(tz.local);
    final tomorrow8pm = tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, 20, 0);

    await NotificationService.instance.scheduleLocal(
      uid: uid,
      dedupeKey: dedupeKey,
      title: 'How are you feeling today?',
      subtitle: 'Log your mood',
      type: 'mood',
      route: 'mood_selector',
      fireAt: tomorrow8pm,
      matchComponents: DateTimeComponents.time,
    );
  }

  // task due reminders

  // call when a task is created, schedules 15 min before due time
  Future<void> scheduleTaskReminder({
    required String uid,
    required String taskId,
    required String title,
    required String dateKey,
    required String time,
  }) async {
    final parts = time.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    final dateParts = dateKey.split('-');
    if (dateParts.length != 3) return;
    final year = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final day = int.tryParse(dateParts[2]);
    if (year == null || month == null || day == null) return;

    final now = tz.TZDateTime.now(tz.local);
    final dueAt = tz.TZDateTime(tz.local, year, month, day, hour, minute);

    // if the due time itself already passed there is nothing to remind about
    if (dueAt.isBefore(now)) return;

    // remind 15 min early, but if the task is due sooner than that
    // fire right at the due time instead of skipping the reminder
    var fireAt = dueAt.subtract(const Duration(minutes: 15));
    if (fireAt.isBefore(now)) {
      fireAt = dueAt;
    }

    final dedupeKey = 'task:$taskId';
    await NotificationService.instance.scheduleLocal(
      uid: uid,
      dedupeKey: dedupeKey,
      title: '$title is due soon',
      subtitle: 'Due at $time',
      type: 'task',
      route: 'todo',
      fireAt: fireAt,
    );
  }

  // call when a task is marked done before the reminder fires
  Future<void> cancelTaskReminder(String taskId) async {
    await NotificationService.instance.cancelLocal('task:$taskId');
  }

  // helper

  // returns the next occurrence of hour:minute in device local time
  // if that time already passed today, returns tomorrow
  tz.TZDateTime _nextOccurrence(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
