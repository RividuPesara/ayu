import 'package:flutter/material.dart';
import 'package:mobile_app/Mood Journal/pastJournalEntries.dart';
import 'package:mobile_app/Mood Journal/journalEntryScreen.dart';

class MoodStatusScreen extends StatelessWidget {
  const MoodStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color bgYellow = Color(0xFFF1C24C);
    const Color brown = Color(0xFF4B3326);
    const Color lightGreen = Color(0xFFA8D85A);
    const Color whiteSection = Color(0xFFF4F4F4);

    return Scaffold(
      backgroundColor: bgYellow,
      body: SizedBox.expand(
        child: Stack(
          children: [
            // top background image
            Positioned.fill(
              child: Column(
                children: [
                  Expanded(
                    child: Image.asset(
                      "assets/moodjournal.png",
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ],
              ),
            ),

            // bottom white curved section
            Positioned(
              left: 0,
              right: 0,
              bottom: -80,
              child: ClipPath(
                clipper: TopArcClipper(),
                child: Container(
                  height: 650,
                  color: whiteSection,
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),

                    // header
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black87,
                                width: 1,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.chevron_left,
                                size: 32,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Mood Journal',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 100),

                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: lightGreen,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text(
                          'NORMAL',
                          style: TextStyle(
                            fontSize: 32,
                            fontFamily: 'Urbanist',
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Center(
                      child: Text(
                        'Congratulations! You are\nmentally okay.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 27,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    const SizedBox(height: 62),

                    // plus button
                    Center(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => NewJournalEntryPage()),
                            );
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: Ink(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: brown,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 35,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 26),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Mental Score History',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: brown,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => PastJournalEntriesScreen()),
                            );
                          },
                          child: const Text(
                            'View All',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: brown,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: const [
                          MoodHistoryCard(
                            day: '12',
                            text: 'Anxious, Depressed',
                          ),
                          SizedBox(height: 12),
                          MoodHistoryCard(
                            day: '11',
                            text: 'Very Happy',
                          ),
                          SizedBox(height: 12),
                          MoodHistoryCard(
                            day: '11',
                            text: 'Very Happy',
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
      ),
    );
  }
}

class MoodHistoryCard extends StatelessWidget {
  final String day;
  final String text;

  const MoodHistoryCard({
    super.key,
    required this.day,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: const Color(0xFFEFEAE7),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4F2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'SEP',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: Color(0xFFA49C96),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  day,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5A4A41),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4D3D35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TopArcClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 90);
    path.quadraticBezierTo(size.width / 2, 0, size.width, 80);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}