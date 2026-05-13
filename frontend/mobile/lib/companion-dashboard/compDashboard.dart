import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../dashboard_cache.dart';
import '../Notification/notification.dart';
import '../editProfile.dart';
import '../Article/articleScreen.dart';
import '../Tracker/Widgets/bottomNavIcons.dart';
import 'companion_service.dart';
import '../Mood Journal/pastJournalEntries.dart';
import 'companion_tracker_screen.dart';
import '../Connect Doctor/mySessions.dart';
import 'companion_todos_screen.dart';
import '../Tracker/tracker_service.dart';

class CompanionDashboard extends StatefulWidget {
  const CompanionDashboard({super.key});

  @override
  State<CompanionDashboard> createState() => _CompanionDashboardState();
}

class _CompanionDashboardState extends State<CompanionDashboard> {
  int _currentPage = 0;
  int _selectedIndex = 0;

  bool _isLoading = true;

  String _companionName = '';
  String? _companionAvatar;
  String _quote = '';

  String _patientName = '';
  String? _patientAvatar;

  CompanionPrivacy _privacy = const CompanionPrivacy();
  List<ScheduleItem> _patientMeds = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = CompanionDashboardService.instance;

    final results = await Future.wait([
      svc.loadOwnProfile(),
      svc.fetchStatus(),
      svc.fetchPrivacy(),
    ]);

    final profile = results[0] as ({String fullName, String? avatarUrl});
    final status = results[1] as CompanionStatus;
    final privacy = results[2] as CompanionPrivacy;

    List<ScheduleItem> meds = [];
    if (privacy.tracking) {
      try {
        final dateKey = DashboardCache.adjustedDayKey();
        meds = await TrackerRepository.instance.fetchSchedule(dateKey);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _companionName = profile.fullName;
      _companionAvatar = profile.avatarUrl;
      _quote = CompanionDashboardService.pickDailyQuote();
      _patientName = status.patientName ?? '';
      _patientAvatar = status.patientAvatar;
      _privacy = privacy;
      _patientMeds = meds;
      _isLoading = false;
    });
  }

  String getTodayDate() {
    return DateFormat('EEE, dd MMM yyyy').format(DateTime.now());
  }

  double getProgress() {
    final visible = _patientMeds.where((m) => m.status != 'missed').toList();
    if (visible.isEmpty) return 0.0;
    return visible.where((m) => m.status == 'taken').length / visible.length;
  }

  List<Map<String, dynamic>> get _featureCards {
    final cards = <Map<String, dynamic>>[];
    if (_privacy.moodJournal) {
      cards.add({
        'title': 'Mood\nJournal',
        'image': 'assets/dashboard/mood_journal.png',
        'color': const Color(0xffFFCE5C),
        'icon': Icons.favorite_outline,
        'screen': const PastJournalEntriesScreen(isReadOnly: true),
      });
    }
    if (_privacy.tracking) {
      cards.add({
        'title': 'Tracking\nSystem',
        'image': 'assets/dashboard/tracking_system.png',
        'color': const Color(0xffB4C48D),
        'icon': Icons.medication_outlined,
        'screen': const CompanionTrackerScreen(),
      });
    }
    if (_privacy.doctorAppointments) {
      cards.add({
        'title': 'Doctor\nAppointments',
        'image': 'assets/dashboard/connect_doctor.png',
        'color': const Color(0xffCBC2FF),
        'icon': Icons.calendar_today_outlined,
        'screen': const MyAppointmentScreen(isReadOnly: true),
      });
    }
    if (_privacy.todoList) {
      cards.add({
        'title': 'To-Do\nList',
        'image': 'assets/dashboard/to_do_list.png',
        'color': const Color(0xffFFDB8F),
        'icon': Icons.description_outlined,
        'screen': const CompanionTodosScreen(),
      });
    }
    return cards;
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

    final patientFirst = _patientName.split(' ').first;
    final cards = _featureCards;

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

                      // Top bar
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
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const Notifications(),
                              ),
                            ),
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

                      // Companion's own profile greeting
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 37,
                            backgroundImage: _companionAvatar != null
                                ? NetworkImage(_companionAvatar!)
                            as ImageProvider
                                : const AssetImage('assets/avatar.png'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _companionName.isEmpty
                                  ? 'Hi there!'
                                  : 'Hi there, ${_companionName.split(' ').first}!',
                              style: const TextStyle(
                                fontSize: 32,
                                color: Color(0xff4B3425),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Supporting banner
                      if (_patientName.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xffEDE8F8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundImage: _patientAvatar != null
                                    ? NetworkImage(_patientAvatar!)
                                as ImageProvider
                                    : const AssetImage('assets/avatar.png'),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Supporting $_patientName',
                                style: const TextStyle(
                                  color: Color(0xff7B6BA8),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
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
                            const Row(
                              children: [
                                Icon(
                                  Icons.description,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Quote of the day',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _quote,
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

                      // Feature cards
                      if (cards.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                color: Color(0xff9B8A7E),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'The patient has not shared any information yet.',
                                  style: TextStyle(color: Color(0xff9B8A7E)),
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        Text(
                          patientFirst.isNotEmpty
                              ? "Everything $patientFirst Needs"
                              : 'Everything They Need',
                          style: const TextStyle(
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
                                _currentPage = index % cards.length;
                              });
                            },
                            itemBuilder: (context, index) {
                              final item = cards[index % cards.length];
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: _buildFeatureCard(item),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            cards.length,
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
                      ],

                      const SizedBox(height: 25),

                      // Patient's plans for today
                      if (_privacy.tracking) ...[
                        Text(
                          patientFirst.isNotEmpty
                              ? "${patientFirst}'s Plans For Today"
                              : "Plans For Today",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff4B3425),
                          ),
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
                            final visible = _patientMeds
                                .where((m) => m.status != 'missed')
                                .toList();
                            if (visible.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'No medications scheduled for today.',
                                  style: TextStyle(color: Color(0xff9B8A7E)),
                                ),
                              );
                            }
                            return Column(
                              children: visible
                                  .map<Widget>((item) => _buildMedCard(item))
                                  .toList(),
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(34),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xff2F2146),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 18),
                GestureDetector(
                  onTap: () => setState(() => _selectedIndex = 0),
                  child: BottomNavIcon(
                    icon: Icons.home_outlined,
                    selected: _selectedIndex == 0,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() => _selectedIndex = 1);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ArticleScreen()),
                    );
                  },
                  child: BottomNavIcon(
                    icon: Icons.article_outlined,
                    selected: _selectedIndex == 1,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() => _selectedIndex = 2);
                    if (_privacy.tracking) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CompanionTrackerScreen(),
                        ),
                      );
                    }
                  },
                  child: BottomNavIcon(
                    icon: Icons.bar_chart_rounded,
                    selected: _selectedIndex == 2,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() => _selectedIndex = 3);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EditProfileScreen()),
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

  Widget _buildFeatureCard(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => item['screen'] as Widget),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: item['color'] as Color,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(item['icon'] as IconData, color: Colors.white),
                const SizedBox(width: 7),
                Text(
                  item['title'] as String,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            Expanded(child: Image.asset(item['image'] as String)),
          ],
        ),
      ),
    );
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
          // Read-only status indicator
          isTaken
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
            child: const Icon(Icons.check, color: Colors.white, size: 16),
          )
              : const Icon(
            Icons.circle_outlined,
            size: 24,
            color: Color(0xffCCCCCC),
          ),
        ],
      ),
    );
  }
}
