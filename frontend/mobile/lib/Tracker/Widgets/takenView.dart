import 'package:flutter/material.dart';

class TakenView extends StatelessWidget {
  final List<Map<String, String>> takenMedicines;

  const TakenView({
    super.key,
    required this.takenMedicines,
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
              color: Color(0xFF6B7D45),
            ),
          ),
          const SizedBox(height: 13),
          const Text(
            "Your routine is\non track.",
            style: TextStyle(
              fontSize: 35,
              fontWeight: FontWeight.w700,
              color: brown,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "Showing ${takenMedicines.length} medication${takenMedicines.length == 1 ? '' : 's'} taken today",
            style: const TextStyle(
              fontSize: 19,
              color: Color(0xFF8A847D),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          ...takenMedicines.map(
                (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.82),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFEDEA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              item["image"]!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return const Icon(
                                  Icons.medication_outlined,
                                  color: Color(0xFF7AA4B9),
                                  size: 28,
                                );
                              },
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E8D3D),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 18,
                                color: Colors.white,
                              ),
                              SizedBox(width: 5),
                              Text(
                                "TAKEN",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      item["name"]!,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: brown,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item["type"]!,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF6E6963),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 15,
                                    color: Color(0xFF6E6963),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "SCHEDULED FOR",
                                    style: TextStyle(
                                      fontSize: 15,
                                      letterSpacing: 1,
                                      color: Color(0xFF6E6963),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    item["time"]!,
                                    style: const TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF6B7D45),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Divider(
                      color: const Color(0xFFDCD8D3).withOpacity(0.3),
                      height: 1,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: const [
                        Text(
                          "MONTHLY ADHERENCE",
                          style: TextStyle(
                            fontSize: 15,
                            letterSpacing: 1,
                            color: Color(0xFF4B3425),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Spacer(),
                        Text(
                          "92%",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0E8D3D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: const LinearProgressIndicator(
                        value: 0.92,
                        minHeight: 5,
                        backgroundColor: Color(0xFFE4E0DB),
                        valueColor: AlwaysStoppedAnimation(Color(0xFF0E8D3D)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}