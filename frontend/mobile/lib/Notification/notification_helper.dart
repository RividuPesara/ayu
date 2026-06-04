import 'package:intl/intl.dart';

String getNotificationGroup(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  // Earlier This Day
  if (now.day == date.day && now.month == date.month && now.year == date.year) {
    return "Earlier This Day";
  }

  // Same Week
  if (difference.inDays < 7) {
    return DateFormat('EEEE').format(date);
  }

  // Last Week
  if (difference.inDays < 14) {
    return "Last Week";
  }

  // This Month
  if (now.month == date.month && now.year == date.year) {
    return "This Month";
  }

  // Month
  if (now.year == date.year) {
    return DateFormat('MMMM').format(date);
  }

  // Year
  return DateFormat('yyyy').format(date);
}
