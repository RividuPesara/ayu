import 'package:flutter/material.dart';

class BottomNavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const BottomNavIcon({
    super.key,
    required this.icon,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF4B3425);
    const inactiveColor = Color(0xFFB9B2AB);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF1ECE7) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 24,
          color: selected ? activeColor : inactiveColor,
        ),
      ),
    );
  }
}