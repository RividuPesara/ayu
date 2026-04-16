import 'package:flutter/material.dart';

class DailyRecommendationsScreen extends StatelessWidget {
  const DailyRecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = List.generate(
      5,
          (index) => RecommendationItem(
        image:
        '',
        title: '',
        views: '',
        date: '',
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F4F2),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF6B4F3F),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        size: 32,
                        color: Color(0xFF6B4F3F),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Daily Recommendations',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4B3425),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),
            Container(height: 1, color: const Color(0xFFD9D3CF)),

            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return RecommendationCard(item: items[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecommendationItem {
  final String image;
  final String title;
  final String views;
  final String date;

  RecommendationItem({
    required this.image,
    required this.title,
    required this.views,
    required this.date,
  });
}

class RecommendationCard extends StatelessWidget {
  final RecommendationItem item;

  const RecommendationCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network(
            item.image,
            width: double.infinity,
            height: 250,
            fit: BoxFit.cover,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
            child: Text(
              item.title,
              style: const TextStyle(
                fontSize: 18,
                height: 1.25,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F160F),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Row(
              children: [
                Text(
                  item.views,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6C6C6C),
                  ),
                ),
                const SizedBox(width: 11),
                Text(
                  item.date,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6C6C6C),
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