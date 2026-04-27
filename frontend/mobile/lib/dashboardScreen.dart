import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'Chatbot/chatbotScreen.dart';
import 'Mood Journal/pastJournalEntries.dart';
import 'Community/communityFeedScreen.dart';
import 'Connect Doctor/docAppointmentScreen.dart';
import 'Article/articleScreen.dart';
import 'Article/articleRead.dart';
import 'Notification/notification.dart';
import 'editProfile.dart';
import 'Tracker/trackerScreen.dart';
import 'Tracker/Widgets/bottomNavIcons.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {

  final PageController _pageController = PageController();
  int _currentPage = 0;
  int _selectedIndex = 0;

  void _onItemTapped(int index){
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Map<String, dynamic>> todoList = [
    {
      "icon": Icons.access_time_outlined,
      "title": "Meditation",
      "time": "10 mins",
      "done": false
    },
  ];

  String getTodayDate() {
    return DateFormat('EEE, dd MMM yyyy').format(DateTime.now());
  }

  double getProgress() {
    int completed =
        todoList.where((element) => element["done"] == true).length;
    return completed / todoList.length;
  }

  List<Map<String, dynamic>> needCards = [
    {
      "title": "Chatbot",
      "image": "assets/dashboard/chatbot.png",
      "color": Color(0xff926247),
      "icon": Icons.favorite_outline,
      "onTap": (BuildContext context) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const Chatbot(),
          ),
        );
      },
    },
    {
      "title": "Mood\nJournal",
      "image": "assets/dashboard/mood_journal.png",
      "color": Color(0xffFFCE5C),
      "icon": Icons.favorite_outline,
      "onTap": (BuildContext context) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PastJournalEntriesScreen(),
          ),
        );
      },
    },
    /*
    {
      "title": "To-Do List",
      "image": "assets/dashboard/to_do_list.png",
      "color": Color(0xffFFDB8F),
      "icon": Icons.description_outlined,
      "onTap": () {},
    },
     */
    {
      "title": "Tracking\nSystem",
      "image": "assets/dashboard/tracking_system.png",
      "color": Color(0xffB4C48D),
      "icon": Icons.favorite_outline,
      "onTap": (BuildContext context) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TrackerScreen(),
          ),
        );
      },
    },
    /*
    {
      "title": "Connect\nCompanion",
      "image": "assets/dashboard/connect_companion.png",
      "color": Color(0xff9BB068),
      "icon": Icons.mood_bad_outlined,
      "onTap": () {},
    },

    {
      "title": "Donation\nRequest",
      "image": "assets/dashboard/donation_request.png",
      "color": Color(0xff7D944D),
      "icon": Icons.description_outlined,
      "onTap": (BuildContext context) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const Donation(),
          ),
        );
      },
    },
     */
    {
      "title": "Community\nGroup Chat",
      "image": "assets/dashboard/community_chat.png",
      "color": Color(0xff7B6BA8),
      "icon": Icons.mood_bad_outlined,
      "onTap": (BuildContext context) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CommunityScreen(),
          ),
        );
      },
    },
    {
      "title": "Connect With\na Doctor",
      "image": "assets/dashboard/connect_doctor.png",
      "color": Color(0xffCBC2FF),
      "icon": Icons.mood_bad_outlined,
      "onTap": (BuildContext context) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DoctorAppointmentScreen(),
          ),
        );
      },
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F7F7),

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      const SizedBox(height: 15),

                      // Top Section
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [

                          Row(
                            children: [
                              const Icon(Icons.calendar_month,
                                  color: Color(0xff4B3425)),
                              const SizedBox(width: 8),
                              Text(
                                getTodayDate(),
                                style: const TextStyle(
                                  color: Color(0xff4B3425),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),

                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const Notifications(),
                                ),
                              );
                            },
                            child: Container(
                              padding:
                              const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color:
                                  const Color(0xff4B3425),
                                  width: 2,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                  Icons.notifications_none),
                            ),
                          )
                        ],
                      ),

                      const SizedBox(height: 17),

                      // Profile
                      Row(
                        children: const [

                          CircleAvatar(
                            radius: 37,
                            backgroundImage:
                            AssetImage("assets/avatar.png"),
                          ),

                          SizedBox(width: 10),

                          Text(
                            "Hi, Shinomiya!",
                            style: TextStyle(
                                fontSize: 35,
                                color: Color(0xff4B3425),
                                fontWeight:
                                FontWeight.w600),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      // Quote
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius:
                          BorderRadius.circular(30),
                          color: const Color(0xff7B6BA8),
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: const [

                            Row(
                              children: [
                                Icon(Icons.description,
                                    color: Colors.white,
                                    size: 18),
                                SizedBox(width: 5),
                                Text(
                                  "Quote of the day",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight:
                                    FontWeight.w600,
                                  ),
                                )
                              ],
                            ),

                            SizedBox(height: 3),

                            Text(
                              "Peace comes from within. Do not seek it without",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight:
                                  FontWeight.bold,
                                  fontSize: 20),
                            )

                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      // Everything you need
                      const Text(
                        "Everything You Need",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Color(0xff4B3425),
                        ),
                      ),

                      const SizedBox(height: 15),

                      SizedBox(
                        height: 220,
                        child: PageView.builder(
                          controller: PageController(
                            viewportFraction: 0.5,
                            initialPage: 0,
                          ),
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index % needCards.length;
                            });
                          },
                          itemBuilder: (context, index) {
                            final item = needCards[index % needCards.length];

                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: buildNeedCard(
                                item["title"],
                                item["image"],
                                item["color"],
                                item["icon"],
                                item["onTap"] as Function(BuildContext),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          needCards.length,
                              (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentPage == index ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? Colors.purple
                                  : Colors.grey,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      // Plans
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [

                          const Text(
                            "Your Plans For Today",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff4B3425),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      LinearProgressIndicator(
                        value: getProgress(),
                        minHeight: 6,
                        borderRadius:
                        BorderRadius.circular(20),
                      ),

                      const SizedBox(height: 15),

                      Column(
                        children: List.generate(
                          todoList.length,
                              (index) =>
                              buildTodoCard(index),
                        ),
                      ),

                      const SizedBox(height: 25),

                      // Mindful Resources
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [

                          const Text(
                            "Mindful Resources",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 20,
                              color: Color(0xff4B3425),
                            ),
                          ),

                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ArticleScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              "See All",
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xff936949),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        ],
                      ),

                      const SizedBox(height: 15),

                      SingleChildScrollView(
                        scrollDirection:
                        Axis.horizontal,
                        child: Row(
                          children: [

                            buildResourceCard(
                              "Mental Health Basics",
                              "Learn the essentials of mental health",
                                  () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ArticleRead(title: "Mental Health Basics", content: "Learn the essentials of mental health"),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(width: 15),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation
      floatingActionButton: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0xff2F2146),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TrackerScreen(),
              ),
            );
          },
          backgroundColor: const Color(0xff7C63B8),
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(
            Icons.add,
            size: 30,
            color: Colors.white,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xffFFFFFF),
              borderRadius: BorderRadius.circular(34),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff2F2146),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 18),

                GestureDetector(
                  onTap: () {
                    _onItemTapped(0);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Dashboard(),
                      ),
                    );
                  },
                  child: BottomNavIcon(
                    icon: Icons.home_outlined,
                    selected: _selectedIndex == 0,
                  ),
                ),

                const Spacer(),

                GestureDetector(
                  onTap: () {
                    _onItemTapped(1);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Chatbot(),
                      ),
                    );
                  },
                  child: BottomNavIcon(
                    icon: Icons.chat_bubble_outline,
                    selected: _selectedIndex == 1,
                  ),
                ),

                const Spacer(),
                const SizedBox(width: 70),
                const Spacer(),

                GestureDetector(
                  onTap: () {
                    _onItemTapped(2);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TrackerScreen(),
                      ),
                    );
                  },
                  child: BottomNavIcon(
                    icon: Icons.bar_chart_rounded,
                    selected: _selectedIndex == 2,
                  ),
                ),

                const Spacer(),

                GestureDetector(
                  onTap: () {
                    _onItemTapped(3);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(),
                      ),
                    );
                  },
                  child: BottomNavIcon(
                    icon: Icons.person_outline,
                    selected: _selectedIndex == 3,
                  ),
                ),

                const SizedBox(width: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildNeedCard(
      String title,
      String image,
      Color color,
      IconData icon,
      Function(BuildContext) onTap) {

    return GestureDetector(
      onTap: () => onTap(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 7),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white)),
              ],
            ),
            Expanded(
              child: Image.asset(image),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTodoCard(int index) {
    var task = todoList[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color:
                  const Color(0xffF2F5EB),
                  borderRadius:
                  BorderRadius.circular(
                      25),
                ),
                child: Icon(
                  task["icon"]
                  as IconData?,
                  color:
                  const Color(0xff9BB068),
                ),
              ),

              const SizedBox(width: 12),

              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(task["title"]),
                  Text(task["time"]),
                ],
              ),
            ],
          ),

          GestureDetector(
            onTap: () {
              setState(() {
                task["done"] = !(task["done"] ?? false);
              });
            },
            child: task["done"] == true
                ? Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green,
                border: Border.all(
                  color: Color(0xff4B3425),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 16,
              ),
            )
                : const Icon(
              Icons.circle_outlined,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildResourceCard(
      String title,
      String subtitle,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 5),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
                radius: 35,
                backgroundColor: Colors.purple
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6
              ),
              decoration: BoxDecoration(
                  color: const Color(0xffF7F4F2),
                  borderRadius: BorderRadius.circular(100)
              ),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xff926247),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 7),

            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xff4B3425),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}