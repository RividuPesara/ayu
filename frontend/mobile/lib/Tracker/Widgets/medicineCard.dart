import 'package:flutter/material.dart';

class MedicineCard extends StatelessWidget {
  final String name;
  final String type;
  final String time;
  final String tag;
  final String? imagePath;
  final bool isTaken;
  final bool isMissed;
  final VoidCallback onTagTap;

  const MedicineCard({
    super.key,
    required this.name,
    required this.type,
    required this.time,
    required this.tag,
    this.imagePath,
    required this.isTaken,
    this.isMissed = false,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    const brown = Color(0xFF4B3425);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 33,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 74,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F1EE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imagePath != null && imagePath!.isNotEmpty
                  ? Image.asset(
                      imagePath!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return const Icon(
                          Icons.medication_outlined,
                          color: Color(0xFFA8BA78),
                          size: 32,
                        );
                      },
                    )
                  : const Center(
                      child: Icon(
                        Icons.medication_outlined,
                        color: Color(0xFFA8BA78),
                        size: 32,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: brown,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.medication_liquid_outlined,
                      size: 18,
                      color: Color(0xFFA6A09B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      type,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF434655),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 15),
                    const Icon(
                      Icons.access_time,
                      size: 18,
                      color: Color(0xFFA6A09B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF434655),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: isMissed ? null : onTagTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isTaken
                              ? const Color(0xFF1FA15A)
                              : isMissed
                              ? const Color(0xFFD94F4F)
                              : const Color(0xFFA8BA78),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
