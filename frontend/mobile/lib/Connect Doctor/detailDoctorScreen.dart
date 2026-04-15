import 'package:flutter/material.dart';
import 'package:mobile_app/Connect%20Doctor/checkoutScreen.dart';

class DetailDoctorPage extends StatelessWidget {
  const DetailDoctorPage({super.key});

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF3F1EF);
    const lightText = Color(0xFF9B918C);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 50),

            // Back button
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Color(0xFF4B3425).withOpacity(0.8)),
                ),
                child: const Icon(
                  Icons.chevron_left,
                  color: Color(0xFF4B3425),
                ),
              ),
            ),

            const SizedBox(height: 25),

            // Title
            const Text(
              "Detail Doctor",
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Color(0xFF4B3425),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Get more information",
              style: TextStyle(
                color: lightText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 30),

            // Doctor card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8EBDD),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        "https://images.unsplash.com/photo-1594824476967-48c8b964273f",
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Dr. Jenny Wilson",
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4B3425),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Oncologist",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF4B3425),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Biography
            const Text(
              "Biography",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: lightText,
              ),
            ),
            const SizedBox(height: 10),
            RichText(
              text: const TextSpan(
                style: TextStyle(color: lightText, height: 1.5, fontSize: 16),
                children: [
                  TextSpan(
                    text:
                    "Dr. Jenny Wilson (Implantologist), is a Dentist in America, she has 20 years of experience. ",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Calendar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  "Calendar",
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF09121C),
                  ),
                ),
                Row(
                  children: [
                    Text("July", style: TextStyle(color: lightText)),
                    Icon(Icons.chevron_right, size: 18),
                  ],
                )
              ],
            ),

            const SizedBox(height: 16),

            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DateChip(day: "14", week: "Sun", selected: true),
                DateChip(day: "15", week: "Mon"),
                DateChip(day: "16", week: "Tue"),
                DateChip(day: "17", week: "Wed"),
                DateChip(day: "18", week: "Thu"),
              ],
            ),

            const SizedBox(height: 21),

            // Time
            const Text(
              "Time",
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF09121C),
              ),
            ),

            const SizedBox(height: 19),

            Wrap(
              spacing: 12,
              runSpacing: 14,
              children: const [
                TimeChip(text: "09.00 AM", selected: true),
                TimeChip(text: "09.30 AM"),
                TimeChip(text: "10.00 AM"),
                TimeChip(text: "10.30 AM"),
                TimeChip(text: "11.00 AM"),
                TimeChip(text: "03.00 PM"),
                TimeChip(text: "03.30 PM"),
              ],
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CheckoutPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4B3425),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  "Book Appointment",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 75),
          ],
        ),
      ),
    );
  }
}

class DateChip extends StatelessWidget {
  final String day;
  final String week;
  final bool selected;
  final bool disabled;

  const DateChip({
    super.key,
    required this.day,
    required this.week,
    this.selected = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFE0A500);

    return Container(
      width: 60,
      height: 70,
      decoration: BoxDecoration(
        color: selected
            ? yellow
            : disabled
            ? const Color(0xFFE8E7EA)
            : Colors.white,
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : Colors.black,
            ),
          ),
          Text(
            week,
            style: TextStyle(
              fontSize: 15,
              color: selected ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class TimeChip extends StatelessWidget {
  final String text;
  final bool selected;

  const TimeChip({
    super.key,
    required this.text,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFE5A900);

    return Container(
      width: 84,
      height: 36,
      decoration: BoxDecoration(
        color: selected ? yellow : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: selected ? Colors.white : Colors.black54,
        ),
      ),
    );
  }
}