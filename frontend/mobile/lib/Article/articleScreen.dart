import 'package:flutter/material.dart';
import 'articleRead.dart';
import 'article_service.dart';

class ArticleScreen extends StatefulWidget {
  const ArticleScreen({super.key});

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  TextEditingController searchController = TextEditingController();
  String selectedCategory = "All";
  late Future<List<ArticleModel>> _articlesFuture;

  @override
  void initState() {
    super.initState();
    _articlesFuture = ArticleService.fetchPublished();
  }

  List<ArticleModel> _filtered(List<ArticleModel> all) {
    return all.where((a) {
      final matchesSearch =
          a.title.toLowerCase().contains(searchController.text.toLowerCase());
      final matchesCategory =
          selectedCategory == "All" || a.genre == selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Widget categoryItem(
      IconData icon, String title, Color color, String category, double size, double fontSize, Color fontColor) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCategory = category;
        });
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: size),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: fontSize,
              color: fontColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 70, 20, 30), // left, top, right, bottom
              decoration: const BoxDecoration(
                color: Color(0xff5A6B38),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: Color(0xff5A6B38),
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(
                              color: Colors.white,
                              width: 2.0
                          ),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "Our Articles",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 37,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Search
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(70),
                    ),
                    child: TextField(
                      controller: searchController,
                      onChanged: (value) => setState(() {}),
                      decoration: const InputDecoration(
                        suffixIcon: Icon(
                          Icons.search,
                          color: Color(0xff4B3425),
                        ),
                        border: InputBorder.none,
                        hintText: "Search our 1242 articles",
                        hintStyle: TextStyle(
                          color: Color(0xff706A66),
                          fontSize: 19,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Suggested Topics
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Suggested Topics",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff53412A),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedCategory = "All";
                      });
                    },
                    child: Text(
                      "See All",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff946B49),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  categoryItem(
                      Icons.spa, "Stress", Color(0xff926448), "Stress", 32, 22, Color(0xff6D6661)),
                  const SizedBox(width: 15),
                  categoryItem(
                      Icons.favorite, "Health", Color(0xffFA834C), "Health", 32, 22, Color(0xff6D6661)),
                  const SizedBox(width: 15),
                  categoryItem(
                      Icons.star, "Status", Color(0xffFBCD5C), "Status", 32, 22, Color(0xff6D6661)),
                  const SizedBox(width: 15),
                  categoryItem(
                      Icons.school, "Edu", Color(0xffBCA290), "Edu", 32, 22, Color(0xff6D6661)),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // All Articles
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "All Articles",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff53412A),
                ),
              ),
            ),

            const SizedBox(height: 30),

            FutureBuilder<List<ArticleModel>>(
              future: _articlesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text("Failed to load articles.")),
                  );
                }

                final articles = _filtered(snapshot.data!);

                if (articles.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text("No articles found.")),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: articles.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: .85,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                    ),
                    itemBuilder: (context, index) {
                      final article = articles[index];

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ArticleRead(article: article),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 5),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  children: [
                                    article.thumbnail.isNotEmpty
                                        ? Image.network(
                                            article.thumbnail,
                                            height: 150,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, e) =>
                                                _placeholder(),
                                          )
                                        : _placeholder(),
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xffE5EAD7),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          article.genre,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xff99AF66),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  article.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xff4B3425),
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 150,
      width: double.infinity,
      color: const Color(0xffE5EAD7),
      child: const Icon(Icons.article, color: Color(0xff99AF66), size: 40),
    );
  }
}