import 'package:flutter/material.dart';
import 'article_service.dart';

class ArticleRead extends StatelessWidget {
  final ArticleModel article;

  const ArticleRead({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            SizedBox(
              width: double.infinity,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 70, 20, 30),
                decoration: const BoxDecoration(
                  color: Color(0xff4B3425),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: const BoxDecoration(
                              color: Color(0xff4B3425),
                              shape: BoxShape.circle,
                              border: Border.fromBorderSide(
                                BorderSide(color: Colors.white, width: 2.0),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Articles",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xff4B3425),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xffF7F4F2), width: 1),
                          ),
                          child: Text(
                            article.genre.isNotEmpty
                                ? article.genre.toUpperCase()
                                : "ARTICLE",
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xffF7F4F2),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    Text(
                      article.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text(
                      "By ${article.author.isNotEmpty ? article.author : 'Unknown'}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Introduction",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Color(0xff4B3425),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildContent(article.content, article.contentImages),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(String content, List<ContentImage> images) {
    if (images.isEmpty) {
      return Text(
        content,
        style: const TextStyle(
          height: 1.6,
          fontSize: 20,
          color: Color(0xff908A85),
          fontWeight: FontWeight.w400,
        ),
      );
    }

    final parts = content.split(RegExp(r'!\[[^\]]*\]\([^)]*\)'));
    final tagIds = RegExp(r'!\[([^\]]*)\]\([^)]*\)')
        .allMatches(content)
        .map((m) => m.group(1) ?? '')
        .toList();

    final widgets = <Widget>[];
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].trim().isNotEmpty) {
        widgets.add(Text(
          parts[i].trim(),
          style: const TextStyle(
            height: 1.6,
            fontSize: 20,
            color: Color(0xff908A85),
            fontWeight: FontWeight.w400,
          ),
        ));
        widgets.add(const SizedBox(height: 16));
      }
      if (i < tagIds.length) {
        final img = images.where((ci) => ci.id == tagIds[i]).firstOrNull;
        if (img != null && img.dataUrl.isNotEmpty) {
          widgets.add(ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              img.dataUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, e, stack) => const SizedBox.shrink(),
            ),
          ));
          widgets.add(const SizedBox(height: 16));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
