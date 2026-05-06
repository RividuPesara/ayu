import 'package:flutter/material.dart';

class CalendarItem extends StatelessWidget {
  final Widget child;

  const CalendarItem({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: double.infinity,
      child: Center(child: child),
    );
  }
}