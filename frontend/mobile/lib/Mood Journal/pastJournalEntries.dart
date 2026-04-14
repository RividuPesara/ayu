import 'package:flutter/material.dart';
import 'package:mobile_app/Mood Journal/journalEntryScreen.dart';

const Color screenBg = Color(0xFFF4F4F4);
const Color textDark = Color(0xFF4B3425);
const Color mutedText = Color(0xFFA39A93);

const Color greenCard = Color(0xFF9BB068);
const Color orangeCard = Color(0xFFFE814B);
const Color paleGreen = Color(0xFFF2F5EB);
const Color paleOrange = Color(0xFFFFE3D6);

class PastJournalEntriesScreen extends StatefulWidget {
  const PastJournalEntriesScreen({super.key});

  @override
  State<PastJournalEntriesScreen> createState() => _PastJournalEntriesScreenState();
}

class _PastJournalEntriesScreenState extends State<PastJournalEntriesScreen> {
  String selectedSort = 'Newest';

  void _showJournalDialog({
    required String title,
    required String mood,
    required String entry,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF9F7F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Journal Details',
            style: TextStyle(
              color: textDark,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Title',
                style: TextStyle(
                  color: mutedText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  color: textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Mood',
                style: TextStyle(
                  color: mutedText,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mood,
                style: const TextStyle(
                  color: textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Entry',
                style: TextStyle(
                  color: mutedText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry,
                style: const TextStyle(
                  color: textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topSectionHeight = screenHeight * 0.56;

    return Scaffold(
      backgroundColor: screenBg,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: double.infinity,
              height: topSectionHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    "assets/moodentries.png",
                    fit: BoxFit.cover,
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
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
                                      color: Colors.white.withOpacity(0.8),
                                      width: 1.1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.chevron_left,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Your Entries',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),

                          const Center(
                            child: Text(
                              '34/365',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 72,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Center(
                            child: Text(
                              'Journals this year. Keep it Up!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 175),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // White Curved Section
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipPath(
                clipper: TopArcClipper(),
                child: Container(
                  height: screenHeight * 0.55,
                  decoration: const BoxDecoration(
                    color: screenBg,
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 74, 16, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 7),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'All Journals',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: textDark,
                                ),
                              ),
                              _buildSortPill(),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Journal List
                          Expanded(
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: 2,
                              separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return JournalCard(
                                    cardColor: greenCard,
                                    tagBg: paleGreen,
                                    tagTextColor: greenCard,
                                    moodText: 'MOOD: HAPPY',
                                    title: "I’m grateful for my l...",
                                    subtitle:
                                    'Today, I just had a revelation. It...',
                                    moodIcon:
                                    Icons.sentiment_dissatisfied_rounded,
                                    onTap: () {
                                      _showJournalDialog(
                                        title: "I’m grateful for my life",
                                        mood: "HAPPY",
                                        entry:
                                        "Today, I just had a revelation. It made me appreciate the little things in life and feel more thankful for everything around me.",
                                      );
                                    },
                                  );
                                }

                                return JournalCard(
                                  cardColor: orangeCard,
                                  tagBg: paleOrange,
                                  tagTextColor: orangeCard,
                                  moodText: 'MOOD: SAD',
                                  title: "I’m grateful for m...",
                                  subtitle:
                                  'Today, I just had a revelation. It...',
                                  moodIcon:
                                  Icons.sentiment_dissatisfied_rounded,
                                  onTap: () {
                                    _showJournalDialog(
                                      title: "I’m grateful for myself",
                                      mood: "SAD",
                                      entry:
                                      "Today, I just had a revelation. It was a difficult day, but I am trying to understand my feelings and give myself some space to heal.",
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Center Plus Button
            Positioned(
              left: 0,
              right: 0,
              top: topSectionHeight - 118,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(50),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => NewJournalEntryPage()),
                      );
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: textDark,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortPill() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: textDark, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedSort,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: textDark,
            size: 18,
          ),
          borderRadius: BorderRadius.circular(14),
          style: const TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          items: const [
            DropdownMenuItem(
              value: 'Newest',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: textDark,
                  ),
                  SizedBox(width: 6),
                  Text('Newest'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'Oldest',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 17,
                    color: textDark,
                  ),
                  SizedBox(width: 6),
                  Text('Oldest'),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                selectedSort = value;
              });
            }
          },
        ),
      ),
    );
  }
}

class JournalCard extends StatelessWidget {
  final Color cardColor;
  final Color tagBg;
  final Color tagTextColor;
  final String moodText;
  final String title;
  final String subtitle;
  final IconData moodIcon;
  final VoidCallback onTap;

  const JournalCard({
    super.key,
    required this.cardColor,
    required this.tagBg,
    required this.tagTextColor,
    required this.moodText,
    required this.title,
    required this.subtitle,
    required this.moodIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F5F3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 170,
              width: 200,
              margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.topLeft,
              child: Icon(
                moodIcon,
                color: Colors.white,
                size: 22,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  moodText,
                  style: TextStyle(
                    color: tagTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: mutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopArcClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 50);
    path.quadraticBezierTo(size.width / 2, -12, size.width, 46);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}