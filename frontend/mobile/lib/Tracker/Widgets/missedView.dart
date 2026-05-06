import 'package:flutter/material.dart';

class MissedView extends StatelessWidget {
  final List<Map<String, dynamic>> missedMedicines;
  final Function(int) onMarkTaken;

  const MissedView({
    super.key,
    required this.missedMedicines,
    required this.onMarkTaken,
  });

  @override
  Widget build(BuildContext context) {
    const brown = Color(0xFF4B3425);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "DAILY LOG",
            style: TextStyle(
              fontSize: 16,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7B8F58),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Reviewing\nMissed Tasks",
            style: TextStyle(
              fontSize: 35,
              fontWeight: FontWeight.w800,
              color: brown,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 22),
          ...List.generate(missedMedicines.length, (index) {
            final item = missedMedicines[index];

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == missedMedicines.length - 1 ? 0 : 12,
              ),
              child: _MissedCard(
                title: item["title"],
                subtitle: item["subtitle"],
                time: item["time"],
                imageColor: item["imageColor"],
                onTap: () => onMarkTaken(index),
              ),
            );
          }),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Feeling okay, Hanie?",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: brown,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "You've missed ${missedMedicines.length} medication${missedMedicines.length == 1 ? '' : 's'} today.\nConsistency is key for your recovery\njourney.",
                  style: const TextStyle(
                    fontSize: 19,
                    color: Color(0xFF8A847D),
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9BB068),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Set Reminders",
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissedCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final Color imageColor;
  final VoidCallback onTap;

  const _MissedCard({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.imageColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const brown = Color(0xFF4B3425);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: imageColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.medication, color: imageColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: brown,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "MISSED",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.red,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 17,
                    color: Color(0xFF45483C),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 15,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 19,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onTap,
                      child: const Text(
                        "Mark as Taken",
                        style: TextStyle(
                          fontSize: 17,
                          color: Color(0xFF4B3425),
                          fontWeight: FontWeight.w600,
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