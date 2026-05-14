import 'package:flutter/material.dart';
import 'package:mobile_app/main.dart';
import 'dashboard_cache.dart';
import 'package:intl/intl.dart';
import 'Chatbot/chatbotScreen.dart';
import 'Mood Journal/moodStatusScreen.dart';
import 'Community/communityFeedScreen.dart';
import 'Connect Doctor/docAppointmentScreen.dart';
import 'Article/articleScreen.dart';
import 'Article/articleRead.dart';
import 'Article/article_service.dart';
import 'Notification/notification.dart';
import 'editProfile.dart';
import 'Tracker/trackerScreen.dart';
import 'Tracker/tracker_service.dart';
import 'Tracker/Widgets/bottomNavIcons.dart';
import 'todoListScreen.dart';
import 'Todo List/task_service.dart';
import 'Companion/companionInviteScreen.dart';
import 'Donation/donationEntryScreen.dart';
import 'videoRecommendations.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with RouteAware {
  int _currentPage = 0;
  int _selectedIndex = 0;

  bool _isLoading = true;
  String _quote = '';
  String _fullName = '';
  String? _avatarUrl;
  bool _avatarLoadError = false;
  List<ScheduleItem> _todayMeds = [];
  List<TaskItem> _todayTasks = [];
  late Future<List<ArticleModel>> _recentArticlesFuture;

  void _readFromCache() {
    final cache = DashboardCache.instance;
    _fullName = cache.fullName;
    _avatarUrl = cache.avatarUrl;
    _quote = cache.quote;
    _todayMeds = List.from(cache.todayMeds);
    _todayTasks = List.from(cache.todayTasks);
    _isLoading = false;
  }

  @override
  void initState() {
    super.initState();
    _initNeedCards();
    _recentArticlesFuture = ArticleService.fetchPublished();
    final cache = DashboardCache.instance;
    if (cache.isReady) {
      _readFromCache();
      final needsProfileRefresh = _fullName.isEmpty;
      Future.wait([
        cache.refreshMeds(),
        cache.refreshTasks(),
        if (needsProfileRefresh) cache.refreshProfile(),
      ]).then((_) {
        if (mounted) {
          setState(() {
            _fullName = cache.fullName;
            _avatarUrl = cache.avatarUrl;
            _todayMeds = List.from(cache.todayMeds);
            _todayTasks = List.from(cache.todayTasks);
          });
        }
      }).catchError((_) {});
    } else {
      cache.preload().then((_) async {
        if (!mounted) return;
        setState(_readFromCache);
        await Future.wait([
          cache.refreshMeds(),
          cache.refreshTasks(),
          cache.refreshProfile(),
        ]);
        if (!mounted) return;
        setState(() {
          _todayMeds = List.from(cache.todayMeds);
          _todayTasks = List.from(cache.todayTasks);
          _fullName = cache.fullName;
          _avatarUrl = cache.avatarUrl;
        });
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _refreshTodayMeds();
    _refreshTodayTasks();
    final cache = DashboardCache.instance;
    setState(() {
      _fullName = cache.fullName;
      _avatarUrl = cache.avatarUrl;
      _avatarLoadError = false;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  String getTodayDate() {
    return DateFormat('EEE, dd MMM yyyy').format(DateTime.now());
  }

  double getProgress() {
    final visibleMeds = _todayMeds.where((m) => m.status != 'missed').toList();
    final total = visibleMeds.length + _todayTasks.length;
    if (total == 0) return 0.0;
    final done = visibleMeds.where((m) => m.status == 'taken').length +
        _todayTasks.where((t) => t.isDone).length;
    return done / total;
  }

  late List<Map<String, dynamic>> needCards;

  void _initNeedCards() {
    needCards = [
    {
      "title": "Chatbot",
      "image": "assets/dashboard/chatbot.png",
      "color": Color(0xff926247),
      "icon": Icons.favorite_outline,
      "onTap": (BuildContext context) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const Chatbot()),
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
            builder: (context) => const MoodStatusScreen(),
          ),
        );
      },
    },
    {
      "title": "To-Do List",
      "image": "assets/dashboard/to_do_list.png",
      "color": Color(0xffFFDB8F),
      "icon": Icons.description_outlined,
      "onTap": (BuildContext context) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ToDoList()),
        ).then((_) => _refreshTodayTasks());
      },
    },
    {
      "title": "Tracking\nSystem",
      "image": "assets/dashboard/tracking_system.png",
      "color": Color(0xffB4C48D),
      "icon": Icons.favorite_outline,
      "onTap": (BuildContext context) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TrackerScreen()),
        ).then((_) => _refreshTodayMeds());
      },
    },
    {
      "title": "Connect\nCompanion",
      "image": "assets/dashboard/connect_companion.png",
      "color": Color(0xff9BB068),
      "icon": Icons.people_outline,
      "onTap": (BuildContext context) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CompanionInviteScreen(),
          ),
        );
      },
    },
    {
      "title": "Donation\nRequest",
      "image": "assets/dashboard/donation_request.png",
      "color": Color(0xff7D944D),
      "icon": Icons.volunteer_activism_outlined,
      "onTap": (BuildContext context) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DonationEntryScreen(),
          ),
        );
      },
    },
    {
      "title": "Video\nRecommend",
      "image": "assets/dashboard/mood_journal.png",
      "color": Color(0xff5C7AA0),
      "icon": Icons.play_circle_outline,
      "onTap": (BuildContext context) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DailyRecommendationsScreen(),
          ),
        );
      },
    },
    {
      "title": "Community\nGroup Chat",
      "image": "assets/dashboard/community_chat.png",
      "color": Color(0xff7B6BA8),
      "icon": Icons.mood_bad_outlined,
      "onTap": (BuildContext context) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CommunityScreen()),
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xffF7F7F7),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xff7B6BA8)),
        ),
      );
    }

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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_month,
                                color: Color(0xff4B3425),
                              ),
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
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xff4B3425),
                                  width: 2,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.notifications_none),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 17),

                      // Profile
                      Row(
                        children: [
                          ClipOval(
                            child: _avatarUrl != null && !_avatarLoadError
                                ? Image.network(
                                    _avatarUrl!,
                                    width: 74,
                                    height: 74,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (mounted) setState(() => _avatarLoadError = true);
                                      });
                                      return Image.asset("assets/avatar.png", width: 74, height: 74, fit: BoxFit.cover);
                                    },
                                  )
                                : Image.asset("assets/avatar.png", width: 74, height: 74, fit: BoxFit.cover),
                          ),

                          const SizedBox(width: 10),

                          Text(
                            _fullName.isEmpty
                                ? 'Hi there!'
                                : 'Hi there, ${_fullName.split(' ').first}!',
                            style: const TextStyle(
                              fontSize: 35,
                              color: Color(0xff4B3425),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      // Quote
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: const Color(0xff7B6BA8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.description,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  "Quote of the day",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 3),

                            Text(
                              _quote.isEmpty ? 'Loading...' : _quote,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Your Plans For Today",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff4B3425),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TrackerScreen(),
                              ),
                            ),
                            child: const Text(
                              "See All",
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xff936949),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      LinearProgressIndicator(
                        value: getProgress(),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(20),
                      ),

                      const SizedBox(height: 15),

                      Builder(
                        builder: (_) {
                          final now = DateTime.now();
                          final nowStr =
                              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                          final visibleMeds = _todayMeds
                              .where((m) => m.status == 'pending')
                              .toList();
                          final visibleTasks = _todayTasks
                              .where((t) => !t.isDone && t.time.compareTo(nowStr) >= 0)
                              .toList();
                          if (visibleMeds.isEmpty && visibleTasks.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No plans for today.',
                                style: TextStyle(color: Color(0xff9B8A7E)),
                              ),
                            );
                          }
                          return Column(
                            children: [
                              ...visibleMeds.map<Widget>(_buildMedCard),
                              ...visibleTasks.map<Widget>(_buildTaskCard),
                            ],
                          );
                        },
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
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      FutureBuilder<List<ArticleModel>>(
                        future: _recentArticlesFuture,
                        builder: (context, snapshot) {
                          final articles = (snapshot.data ?? []).take(3).toList();
                          if (articles.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: articles.map((article) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 15),
                                  child: buildResourceCard(
                                    article.genre.isNotEmpty ? article.genre : "Article",
                                    article.title,
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ArticleRead(article: article),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
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
              MaterialPageRoute(builder: (context) => const TrackerScreen()),
            ).then((_) => _refreshTodayMeds());
          },
          backgroundColor: const Color(0xff7C63B8),
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, size: 30, color: Colors.white),
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
                  onTap: () => _onItemTapped(0),
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
                      MaterialPageRoute(builder: (context) => Chatbot()),
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
                      MaterialPageRoute(builder: (context) => TrackerScreen()),
                    ).then((_) => _refreshTodayMeds());
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
      Function(BuildContext) onTap,
      ) {
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
                Text(title, style: const TextStyle(color: Colors.white)),
              ],
            ),
            Expanded(child: Image.asset(image)),
          ],
        ),
      ),
    );
  }

  void _markTaken(ScheduleItem item) {
    if (item.status == 'taken') return;
    final previousStatus = item.status;
    final dateKey = DashboardCache.adjustedDayKey();
    final repo = TrackerRepository.instance;

    repo.optimisticallyMarkTaken(
      dateKey,
      item.medicationId,
      item.scheduledTime,
    );
    setState(() => _todayMeds = repo.scheduleFor(dateKey));

    markMedicationTaken(
      medicationId: item.medicationId,
      dateKey: dateKey,
      scheduledTime: item.scheduledTime,
    ).catchError((_) {
      repo.revertMarkTaken(
        dateKey,
        item.medicationId,
        item.scheduledTime,
        previousStatus,
      );
      if (mounted) setState(() => _todayMeds = repo.scheduleFor(dateKey));
    });
  }

  Widget _buildMedCard(ScheduleItem item) {
    final isTaken = item.status == 'taken';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
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
                  color: const Color(0xffF2F5EB),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  item.type == 'Injection'
                      ? Icons.vaccines_outlined
                      : Icons.medication_outlined,
                  color: const Color(0xff9BB068),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      decoration: isTaken
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  Text(item.scheduledTime),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: isTaken ? null : () => _markTaken(item),
            child: isTaken
                ? Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green,
                border: Border.all(
                  color: const Color(0xff4B3425),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 16,
              ),
            )
                : const Icon(Icons.circle_outlined, size: 24),
          ),
        ],
      ),
    );
  }

  void _refreshTodayMeds() {
    if (!mounted) return;
    final dateKey = DashboardCache.adjustedDayKey();
    setState(() => _todayMeds = TrackerRepository.instance.scheduleFor(dateKey));
  }

  void _refreshTodayTasks() {
    if (!mounted) return;
    final dateKey = DashboardCache.adjustedDayKey();
    setState(() => _todayTasks = TaskRepository.instance.tasksFor(dateKey));
  }

  void _toggleTodayTask(TaskItem task) {
    final dateKey = DashboardCache.adjustedDayKey();
    final repo = TaskRepository.instance;
    repo.optimisticallyToggle(dateKey, task.taskId);
    setState(() => _todayTasks = repo.tasksFor(dateKey));

    toggleTaskApi(task.taskId).catchError((_) {
      repo.revertToggle(dateKey, task.taskId);
      if (mounted) setState(() => _todayTasks = repo.tasksFor(dateKey));
      return task;
    });
  }

  Widget _buildTaskCard(TaskItem task) {
    final isDone = task.isDone;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDone ? Colors.grey.shade200 : Colors.white,
        borderRadius: BorderRadius.circular(15),
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
                  color: const Color(0xffFFF3D4),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xffFFDB8F),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Color(0xff9B8A7E)),
                      const SizedBox(width: 4),
                      Text(
                        task.time,
                        style: const TextStyle(color: Color(0xff9B8A7E), fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () => _toggleTodayTask(task),
            child: isDone
                ? Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                      border: Border.all(color: const Color(0xff4B3425), width: 2),
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  )
                : const Icon(Icons.circle_outlined, size: 24),
          ),
        ],
      ),
    );
  }

  Widget buildResourceCard(String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 5),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(radius: 35, backgroundColor: Colors.purple),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xffF7F4F2),
                borderRadius: BorderRadius.circular(100),
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
