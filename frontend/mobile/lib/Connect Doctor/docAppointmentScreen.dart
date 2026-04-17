import 'package:flutter/material.dart';
import 'package:mobile_app/Connect%20Doctor/detailDoctorScreen.dart';
import 'package:mobile_app/Connect Doctor/mySessions.dart';

class DoctorAppointmentScreen extends StatefulWidget {
  const DoctorAppointmentScreen({super.key});

  State<DoctorAppointmentScreen> createState() =>
      _DoctorAppointmentScreenState();
}

class _DoctorAppointmentScreenState extends State<DoctorAppointmentScreen> {
  String selectedCategory = "All";

  final List<Map<String, String>> doctors = [
    {"name": "Mr. Carlos Mendez", "specialty": "Cardiologist"},
    {"name": "Dr. Emily Watson", "specialty": "Oncologist"},
    {"name": "Dr. Sarah Lee", "specialty": "Psychologist"},
    {"name": "Dr. James Miller", "specialty": "Oncologist"},
  ];

  List<Map<String, String>> get filteredDoctors {
    if (selectedCategory == "All") return doctors;
    return doctors
        .where((doctor) => doctor["specialty"] == selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    const Color purple = Color(0xFF64548E);
    const Color background = Color(0xFFF3F1EF);
    const Color textDark = Color(0xFF4A3728);

    return Scaffold(
      backgroundColor: background,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
            decoration: const BoxDecoration(
              color: purple,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 42,
                    height: 95,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const Text(
                  "Doctor Appointment",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    children: const [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: "Search a Doctor...",
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                              color: Color(0xFF8C8C8C),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.search,
                        color: Color(0xFF5A432D),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Categories",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedCategory = "Oncologist";
                          });
                        },
                        child: _buildCategoryItem(
                        color: const Color(0xFF9C8CFF),
                        icon: Icons.hourglass_empty,
                        label: "Oncologist",
                      ),
                      ),
                      const SizedBox(width: 18),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedCategory = "Psychologist";
                          });
                        },
                        child: _buildCategoryItem(
                        color: const Color(0xFFFF914D),
                        icon: Icons.medical_services_outlined,
                        label: "Psychologist",
                      ),
                      ),
                      const SizedBox(width: 18),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedCategory = "Counsellor";
                          });
                        },
                        child:
                      _buildCategoryItem(
                        color: const Color(0xFFF7C95C),
                        icon: Icons.lightbulb_outline,
                        label: "Counsellor",
                      ),
                      ),

                      const SizedBox(width: 45),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyAppointmentScreen(),
                            ),
                          );
                        },
                        child: _buildCategoryItem(
                          color: const Color(0xFF74C144),
                          icon: Icons.event_note,
                          label: "My Sessions",
                        ),
                      ),
                    ],
                  ),

                  Expanded(
                    child: ListView(
                      children: [
                        if (filteredDoctors.isEmpty)
                          const Center(
                            child: Text(
                              "No doctors found",
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF4B3425),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        else
                          ...filteredDoctors.map(
                                (doctor) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildDoctorCard(
                                context,
                                name: doctor["name"]!,
                                specialty: doctor["specialty"]!,
                              ),
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildCategoryItem({
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF4B3425),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  static Widget _buildDoctorCard(
      BuildContext context, {
        required String name,
        required String specialty,
      }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const DetailDoctorPage(),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFBFB),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4B3425).withOpacity(0.05),
              offset: const Offset(0, 8),
              blurRadius: 26,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFF8EBDD),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  "https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?auto=format&fit=crop&w=300&q=80",
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4B3425),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  specialty,
                  style: const TextStyle(
                    fontSize: 19,
                    color: Color(0xFF4B3425),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}