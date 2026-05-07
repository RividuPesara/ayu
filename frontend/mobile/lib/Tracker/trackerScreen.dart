import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_app/editProfile.dart';
import '../Tracker/Widgets/bottomNavIcons.dart';
import '../Tracker/Widgets/calendarItem.dart';
import '../Tracker/Widgets/dateCard.dart';
import '../Tracker/Widgets/emptyMedicationView.dart';
import '../Tracker/Widgets/filterCategory.dart';
import '../Tracker/Widgets/medicineCard.dart';
import '../Tracker/Widgets/missedView.dart';
import '../Tracker/Widgets/selectedDateCard.dart';
import '../Tracker/Widgets/takenView.dart';
import '../Tracker/tracker_service.dart';
import 'package:lottie/lottie.dart';
import '../Chatbot/chatbotScreen.dart';

const List<Color> _missedCardColors = [
  Color(0xFF8A4C86),
  Color(0xFF49AFC3),
  Color(0xFFE07A3A),
  Color(0xFF5B8DB8),
  Color(0xFF7AAB6D),
];

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  int selectedFilter = 0;
  DateTime selectedDate = DateTime.now();
  List<ScheduleItem> _scheduleItems = [];
  bool _isLoading = true;
  Timer? _missedTimer;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
    _missedTimer = Timer.periodic(
      const Duration(seconds: 30),
          (_) => _recomputeMissedStatuses(),
    );
  }

  @override
  void dispose() {
    _missedTimer?.cancel();
    super.dispose();
  }

  List<ScheduleItem> get _takenMedicines =>
      _scheduleItems.where((s) => s.status == 'taken').toList();

  List<ScheduleItem> get _missedMedicines =>
      _scheduleItems.where((s) => s.status == 'missed').toList();

  bool get _isPastDate {
    final today = DateTime.now();
    return selectedDate.isBefore(DateTime(today.year, today.month, today.day));
  }

  double get _adherenceRate {
    if (_scheduleItems.isEmpty) return 0.0;
    return _takenMedicines.length / _scheduleItems.length;
  }

  String _toDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _recomputeMissedStatuses() {
    final today = DateTime.now();
    final todayKey = _toDateKey(today);
    if (_toDateKey(selectedDate) != todayKey) return;

    final currentTime =
        '${today.hour.toString().padLeft(2, '0')}:${today.minute.toString().padLeft(2, '0')}';

    bool changed = false;
    for (final item in _scheduleItems) {
      if (item.status == 'pending' &&
          item.scheduledTime.compareTo(currentTime) < 0) {
        item.status = 'missed';
        changed = true;
      }
    }

    if (changed && mounted) setState(() {});
  }

  Future<void> _loadSchedule() async {
    final dateKey = _toDateKey(selectedDate);
    final repo = TrackerRepository.instance;

    await repo.loadCachedSchedule(dateKey);
    if (mounted) {
      setState(() {
        _scheduleItems = repo.scheduleFor(dateKey);
      });
    }

    if (!repo.hasFreshCache(dateKey)) {
      if (mounted) setState(() => _isLoading = true);
      try {
        final items = await repo.fetchSchedule(dateKey);
        if (mounted) {
          setState(() {
            _scheduleItems = items;
            _isLoading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<DateTime> get visibleDates => List.generate(
    5,
        (index) => selectedDate.subtract(Duration(days: 3 - index)),
  );

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _monthLabel(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  String get formattedHeaderDate {
    final today = DateTime.now();

    if (_isSameDate(selectedDate, today)) {
      return "Today, ${_monthLabel(selectedDate.month)} ${selectedDate.day}";
    }

    final day = selectedDate.day.toString().padLeft(2, '0');
    final month = selectedDate.month.toString().padLeft(2, '0');
    final year = selectedDate.year.toString();

    return "You are viewing $day/$month/$year";
  }

  String weekLabel(DateTime date) {
    const labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return labels[date.weekday - 1];
  }

  Future<void> _openCalendarPicker() async {
    const bgColor = Color(0xFFF7F4F2);
    const brown = Color(0xFF4B3425);
    const green = Color(0xFFA8BA78);

    DateTime tempDate = selectedDate;

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: green,
                      onPrimary: Colors.white,
                      onSurface: brown,
                      surface: bgColor,
                    ),
                    datePickerTheme: const DatePickerThemeData(
                      headerHeadlineStyle: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                      weekdayStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      dayStyle: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(foregroundColor: brown),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CalendarDatePicker(
                        initialDate: tempDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                        currentDate: selectedDate,
                        onDateChanged: (date) {
                          setDialogState(() {
                            tempDate = date;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: brown,
                                side: BorderSide(color: brown.withOpacity(0.2)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text("Cancel"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context, tempDate),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text("Done"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        _scheduleItems = [];
        _isLoading = true;
      });
      _loadSchedule();
    }
  }

  void _markMedicineAsTaken(int index) {
    if (index >= _scheduleItems.length) return;
    final item = _scheduleItems[index];
    if (item.status == 'taken') return;

    final previousStatus = item.status;
    final dateKey = _toDateKey(selectedDate);
    final repo = TrackerRepository.instance;

    repo.optimisticallyMarkTaken(
      dateKey,
      item.medicationId,
      item.scheduledTime,
    );
    setState(() => _scheduleItems = repo.scheduleFor(dateKey));

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
      if (mounted) setState(() => _scheduleItems = repo.scheduleFor(dateKey));
    });
  }

  void _markMissedAsTaken(int index) {
    final missed = _missedMedicines;
    if (index >= missed.length) return;
    final item = missed[index];

    final previousStatus = item.status;
    final dateKey = _toDateKey(selectedDate);
    final repo = TrackerRepository.instance;

    repo.optimisticallyMarkTaken(
      dateKey,
      item.medicationId,
      item.scheduledTime,
    );
    setState(() => _scheduleItems = repo.scheduleFor(dateKey));

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
      if (mounted) setState(() => _scheduleItems = repo.scheduleFor(dateKey));
    });
  }

  Future<void> _deleteMedicationItem(int index) async {
    final dateKey = _toDateKey(selectedDate);
    final repo = TrackerRepository.instance;
    final item = _scheduleItems[index];
    final medicationId = item.medicationId;
    final backupItems = List<ScheduleItem>.from(_scheduleItems);

    setState(() {
      _scheduleItems.removeWhere((item) => item.medicationId == medicationId);
    });

    await repo.removeItemsForMedication(dateKey, medicationId);

    try {
      await deleteMedication(medicationId: medicationId);
    } catch (error) {
      await repo.setScheduleForDate(dateKey, backupItems);
      if (mounted) {
        setState(() => _scheduleItems = backupItems);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to delete ${item.name}. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF3F1EF);
    const brown = Color(0xFF4B3425);
    const green = Color(0xFFA8BA78);

    final takenMedicines = _takenMedicines;
    final missedMedicines = _missedMedicines;

    final allCount = _scheduleItems.length;
    final takenCount = takenMedicines.length;
    final missedCount = missedMedicines.length;

    final takenForWidget = takenMedicines
        .map(
          (item) => <String, String>{
        'name': item.name,
        'type': item.type,
        'time': item.scheduledTime,
        'tag': 'Taken',
        'image': '',
      },
    )
        .toList();

    final missedForWidget = missedMedicines
        .asMap()
        .entries
        .map(
          (e) => <String, dynamic>{
        'title': e.value.name,
        'subtitle': e.value.type,
        'time': e.value.scheduledTime,
        'imageColor': _missedCardColors[e.key % _missedCardColors.length],
      },
    )
        .toList();

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: brown.withOpacity(0.25)),
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        size: 32,
                        color: brown,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Your Tracker",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: brown,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formattedHeaderDate,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: brown,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _openCalendarPicker,
                    child: Container(
                      width: 45,
                      height: 45,
                      decoration: const BoxDecoration(
                        color: green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
              if (selectedFilter == 0) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 115,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: visibleDates.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final date = visibleDates[index];
                      final isSelected =
                          date.year == selectedDate.year &&
                              date.month == selectedDate.month &&
                              date.day == selectedDate.day;

                      return CalendarItem(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedDate = date;
                              _scheduleItems = [];
                              _isLoading = true;
                            });
                            _loadSchedule();
                          },
                          child: isSelected
                              ? SelectedDateCard("${date.day}", weekLabel(date))
                              : DateCard("${date.day}", weekLabel(date)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ] else
                const SizedBox(height: 26),
              if (_scheduleItems.isNotEmpty) ...[
                Row(
                  children: [
                    FilterCategoryWidget(
                      label: "All $allCount",
                      selected: selectedFilter == 0,
                      onTap: () => setState(() => selectedFilter = 0),
                    ),
                    const SizedBox(width: 9),
                    FilterCategoryWidget(
                      label: "Taken $takenCount",
                      selected: selectedFilter == 1,
                      onTap: () => setState(() => selectedFilter = 1),
                    ),
                    const SizedBox(width: 9),
                    FilterCategoryWidget(
                      label: "Missed $missedCount",
                      selected: selectedFilter == 2,
                      onTap: () => setState(() => selectedFilter = 2),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
              ],
              Expanded(
                child: _isLoading && _scheduleItems.isEmpty
                    ? const Center(
                  child: CircularProgressIndicator(
                    color: green,
                    strokeWidth: 2.5,
                  ),
                )
                    : selectedFilter == 1
                    ? TakenView(
                  takenMedicines: takenForWidget,
                  adherenceRate: _adherenceRate,
                )
                    : selectedFilter == 2
                    ? MissedView(
                  missedMedicines: missedForWidget,
                  onMarkTaken: _markMissedAsTaken,
                )
                    : _scheduleItems.isEmpty
                    ? EmptyMedicationView(
                  onAddMedication: _isPastDate
                      ? null
                      : _showAddMedicationDialog,
                )
                    : ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    const Text(
                      "TODAY'S SCHEDULE",
                      style: TextStyle(
                        fontSize: 17,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF45483C),
                      ),
                    ),
                    const SizedBox(height: 15),
                    ...List.generate(_scheduleItems.length, (index) {
                      final item = _scheduleItems[index];
                      final isTaken = item.status == 'taken';
                      final isMissed = item.status == 'missed';

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == _scheduleItems.length - 1
                              ? 0
                              : 12,
                        ),
                        child: Dismissible(
                          key: ValueKey(
                            '${item.medicationId}-${item.scheduledTime}',
                          ),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFD94F4F),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          confirmDismiss: (_) async {
                            return true;
                          },
                          onDismissed: (_) =>
                              _deleteMedicationItem(index),
                          child: MedicineCard(
                            name: item.name,
                            type: item.type,
                            time: item.scheduledTime,
                            tag: isTaken
                                ? 'Taken'
                                : isMissed
                                ? 'Missed'
                                : 'Take',
                            imagePath: null,
                            isTaken: isTaken,
                            isMissed: isMissed,
                            onTagTap: () => _markMedicineAsTaken(index),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _isPastDate
          ? null
          : Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x332F2146),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showAddMedicationDialog,
          backgroundColor: const Color(0xFF7C63B8),
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(
            Icons.add,
            size: 30, // slightly bigger like UI
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
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(34),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x332F2146),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 18),

                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const BottomNavIcon(
                    icon: Icons.home_outlined,
                    selected: false,
                  ),
                ),

                const Spacer(),

                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Chatbot()),
                    );
                  },
                  child: const BottomNavIcon(
                    icon: Icons.chat_bubble_outline,
                    selected: false,
                  ),
                ),

                const Spacer(),
                const SizedBox(width: 70),

                const Spacer(),

                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1ECE7),
                      shape: BoxShape.circle,
                    ),
                    child: const BottomNavIcon(
                      icon: Icons.bar_chart_rounded,
                      selected: true,
                    ),
                  ),
                ),

                const Spacer(),

                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(),
                      ),
                    );
                  },
                  child: const BottomNavIcon(
                    icon: Icons.person_outline,
                    selected: false,
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

  Future<void> _showMedicationAddedDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: const Color(0xFFF7F4F2),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 160,
                  width: 160,
                  child: Lottie.asset('assets/thumb.json', repeat: true),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your medication successfully added',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4B3425),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Future.microtask(() => _showAddMedicationDialog());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA8BA78),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Add another',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4B3425),
                      side: BorderSide(
                        color: const Color(0xFF4B3425).withOpacity(0.2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Back to tracker',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddMedicationDialog() async {
    final nameController = TextEditingController();
    String selectedType = "Capsule";
    DateTime? repeatUntilDate;
    final List<TimeOfDay> selectedTimes = [];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickRepeatUntilDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: repeatUntilDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(2028),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFFA8BA78),
                        onPrimary: Colors.white,
                        onSurface: Color(0xFF4B3425),
                      ),
                      textTheme: Theme.of(context).textTheme.copyWith(
                        headlineSmall: const TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B3425),
                        ),
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: -20,
                          ),
                          foregroundColor: const Color(0xFF4B3425),
                          textStyle: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B3425),
                          ),
                        ),
                      ),
                      datePickerTheme: const DatePickerThemeData(
                        headerHeadlineStyle: TextStyle(
                          fontSize: 32, // Today's date
                          fontWeight: FontWeight.w500,
                        ),
                        headerHelpStyle: TextStyle(
                          fontSize: 22, // Select date
                          fontWeight: FontWeight.w500,
                        ),
                        weekdayStyle: TextStyle(
                          fontSize: 21, // S M T W
                          fontWeight: FontWeight.w600,
                        ),
                        dayStyle: TextStyle(
                          fontSize: 21, // numbers inside calendar
                        ),
                        yearStyle: TextStyle(fontSize: 23),
                      ),
                    ),
                    child: child!,
                  );
                },
              );

              if (picked != null) {
                setDialogState(() {
                  repeatUntilDate = picked;
                });
              }
            }

            Future<void> pickTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFFA8BA78),
                        onPrimary: Colors.white,
                        onSurface: Color(0xFF4B3425),
                      ),
                      timePickerTheme: const TimePickerThemeData(
                        helpTextStyle: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B3425),
                        ),
                        hourMinuteTextStyle: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B3425),
                        ),
                        dayPeriodTextStyle: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B3425),
                        ),
                        dialTextStyle: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4B3425),
                        ),
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          foregroundColor: const Color(0xFF4B3425),
                          textStyle: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    child: child!,
                  );
                },
              );

              if (picked != null) {
                setDialogState(() {
                  selectedTimes.add(picked);
                });
              }
            }

            String formatTime(TimeOfDay time) {
              final hour = time.hour.toString().padLeft(2, '0');
              final minute = time.minute.toString().padLeft(2, '0');
              return "$hour:$minute";
            }

            String formatDate(DateTime date) {
              final day = date.day.toString().padLeft(2, '0');
              final month = date.month.toString().padLeft(2, '0');
              final year = date.year.toString();
              return "$day/$month/$year";
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: const Color(0xFFF7F4F2),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Add Medication",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4B3425),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        "Name of medicine",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B3425),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: "Enter medicine name",
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Type",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B3425),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedType,
                            items: const [
                              DropdownMenuItem(
                                value: "Capsule",
                                child: Text("Capsule"),
                              ),
                              DropdownMenuItem(
                                value: "Injection",
                                child: Text("Injection"),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() {
                                  selectedType = value;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Times",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B3425),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...List.generate(selectedTimes.length, (index) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8E6E3),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formatTime(selectedTimes[index]),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4B3425),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        selectedTimes.removeAt(index);
                                      });
                                    },
                                    child: const Icon(
                                      Icons.close,
                                      size: 18,
                                      color: Color(0xFF4B3425),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          GestureDetector(
                            onTap: pickTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFA8BA78),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "Add Time",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        "Repeat until",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B3425),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: pickRepeatUntilDate,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  repeatUntilDate == null
                                      ? "Choose date"
                                      : formatDate(repeatUntilDate!),
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: repeatUntilDate == null
                                        ? const Color(0xFF8A847D)
                                        : const Color(0xFF4B3425),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.calendar_month_rounded,
                                color: Color(0xFF4B3425),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4B3425),
                                side: BorderSide(
                                  color: const Color(
                                    0xFF4B3425,
                                  ).withOpacity(0.2),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4B3425),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final medicineName = nameController.text.trim();

                                if (medicineName.isEmpty ||
                                    selectedTimes.isEmpty ||
                                    repeatUntilDate == null) {
                                  return;
                                }

                                final ru = repeatUntilDate!;
                                final repeatUntilStr =
                                    '${ru.year}-${ru.month.toString().padLeft(2, '0')}-${ru.day.toString().padLeft(2, '0')}';

                                final times = selectedTimes
                                    .map(
                                      (t) =>
                                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                                )
                                    .toList();

                                final dateKey = _toDateKey(selectedDate);
                                final tempId =
                                    'local_${DateTime.now().millisecondsSinceEpoch}';
                                final repo = TrackerRepository.instance;

                                final todayStr = _toDateKey(DateTime.now());
                                if (dateKey.compareTo(todayStr) >= 0 &&
                                    dateKey.compareTo(repeatUntilStr) <= 0) {
                                  repo.insertOptimisticItems(
                                    dateKey,
                                    tempId,
                                    medicineName,
                                    selectedType,
                                    times,
                                  );
                                  setState(() {
                                    _scheduleItems = repo.scheduleFor(dateKey);
                                    selectedFilter = 0;
                                  });
                                }

                                Navigator.pop(context);
                                Future.microtask(
                                      () => _showMedicationAddedDialog(),
                                );

                                createMedication(
                                  name: medicineName,
                                  type: selectedType,
                                  times: times,
                                  repeatUntil: repeatUntilStr,
                                )
                                    .then((med) {
                                  repo.replaceOptimisticItems(
                                    dateKey,
                                    tempId,
                                    med,
                                  );
                                  repo.invalidateDate(dateKey);
                                  repo.fetchSchedule(dateKey).then((items) {
                                    if (mounted) {
                                      setState(
                                            () => _scheduleItems = items,
                                      );
                                    }
                                  });
                                })
                                    .catchError((_) {
                                  repo.removeOptimisticItems(
                                    dateKey,
                                    tempId,
                                  );
                                  if (mounted) {
                                    setState(
                                          () => _scheduleItems = repo
                                          .scheduleFor(dateKey),
                                    );
                                  }
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFA8BA78),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text(
                                "Add",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
