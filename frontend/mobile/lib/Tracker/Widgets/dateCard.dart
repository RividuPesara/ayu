import 'package:flutter/material.dart';

class DateCard extends StatelessWidget {
  final String day;
  final String week;

  const DateCard(this.day, this.week, {super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: Container(
        width: 69,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE9E9E9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              week,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8F8F8F),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              day,
              style: const TextStyle(
                color: Color(0xFF7A7A7A),
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}