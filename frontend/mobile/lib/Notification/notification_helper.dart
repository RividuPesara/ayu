import 'package:intl/intl.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';

String getNotificationGroup(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  // Earlier This Day
  if (now.day == date.day && now.month == date.month && now.year == date.year) {
    return AppLocalizations.tr('notif.earlierToday');
  }

  // Same Week
  if (difference.inDays < 7) {
    return DateFormat('EEEE').format(date);
  }

  // Last Week
  if (difference.inDays < 14) {
    return AppLocalizations.tr('notif.lastWeek');
  }

  // This Month
  if (now.month == date.month && now.year == date.year) {
    return AppLocalizations.tr('notif.thisMonth');
  }

  // Month
  if (now.year == date.year) {
    return DateFormat('MMMM').format(date);
  }

  // Year
  return DateFormat('yyyy').format(date);
}
