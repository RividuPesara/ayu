import 'package:flutter/material.dart';
import 'chatbotScreen.dart';


class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class HistoryItem {
  String message;
  String date;
  List<Map<String, dynamic>> messages;

  HistoryItem({
    required this.message,
    required this.date,
    required this.messages,
  });
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryItem> history = [
    HistoryItem(
      message: "Give me the name of the most famous Songwriters",
      date: "08 August 2024 | 03:23 AM",
      messages: [
        {
          "isUser": true,
          "message": "Give me the name of the most famous Songwriters"
        },
        {
          "isUser": false,
          "message": "John Lennon, Bob Dylan, Paul McCartney"
        },
      ],
    ),
  ];

  late List<HistoryItem> filteredHistory;

  bool isSearching = false;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredHistory = List.from(history);
  }

  void searchHistory(String query) {
    setState(() {
      filteredHistory = history
          .where((item) =>
          item.message.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void deleteAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              "assets/delete.png",
              height: 400,
            ),
            const SizedBox(height: 15),
            const Text(
              "Delete all the Conversation?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w500,
                color: Color(0xff4A3324),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xffCBC2FF),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Cancel",
                    style: TextStyle(
                      color: Color(0xff64548E),
                      fontSize: 19,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.close,
                    color: Color(0xff64548E),
                    size: 24,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  history.clear();
                  filteredHistory.clear();
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff64548E),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Delete",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.delete_outline_sharp,
                    color: Colors.white,
                    size: 24,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  void toggleSearch() {
    setState(() {
      isSearching = !isSearching;
      searchController.clear();
      filteredHistory = List.from(history);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F4F2),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: Color(0xffF7F4F2),
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(
                              color: Color(0xff4B3425), width: 2.0),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Color(0xff4B3425),
                        size: 25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: isSearching
                        ? TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: "Search...",
                        hintStyle: TextStyle(
                          fontSize: 22,
                        ),
                        border: InputBorder.none,
                      ),
                      onChanged: searchHistory,
                    )
                        : const Text(
                      "History",
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff4B3425),
                      ),
                    ),
                  ),

                  GestureDetector(
                    onTap: toggleSearch,
                    child: Icon(
                      isSearching ? Icons.close : Icons.search,
                      size: 35,
                    ),
                  ),

                  const SizedBox(width: 15),

                  GestureDetector(
                    onTap: deleteAll,
                    child: const Icon(
                      Icons.delete_outline_sharp,
                      size: 35,
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: filteredHistory.isEmpty
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    "assets/not_found.png",
                    height: 120,
                  ),
                  SizedBox(height: 50),
                  Text(
                    "Not Found",
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "We're sorry, no message\nmatches your search",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                    ),
                  ),
                ],
              )
                  : ListView.builder(
                itemCount: filteredHistory.length,
                itemBuilder: (context, index) {
                  return Dismissible(
                    key: Key(filteredHistory[index].message),
                    background: Container(
                      color: Color(0xffFF6666),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(
                        Icons.delete_outline_sharp,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    onDismissed: (_) {
                      setState(() {
                        history.remove(filteredHistory[index]);
                        filteredHistory.removeAt(index);
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 5),
                                Text(
                                  filteredHistory[index].message,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  filteredHistory[index].date,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xff6E6E6E),
                                  ),
                                ),
                                const SizedBox(height: 5),
                              ],
                            ),
                          ),
                          const SizedBox(width: 15),

                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Chatbot(
                                    previousMessages:
                                    filteredHistory[index].messages,
                                  ),
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.arrow_forward_ios,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}