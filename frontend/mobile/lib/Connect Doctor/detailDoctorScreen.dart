import 'package:flutter/material.dart';
import 'package:mobile_app/Connect%20Doctor/checkoutScreen.dart';
import 'package:mobile_app/Connect%20Doctor/appointment_service.dart';

class DetailDoctorPage extends StatefulWidget {
  const DetailDoctorPage({
    super.key,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.doctorUid,
    required this.doctorAvatarUrl,
  });

  final String doctorName;
  final String doctorSpecialty;
  final String doctorUid;
  final String doctorAvatarUrl;

  @override
  State<DetailDoctorPage> createState() => _DetailDoctorPageState();
}

class _DetailDoctorPageState extends State<DetailDoctorPage> {
  final AppointmentService _appointmentService = AppointmentService();
  List<AppointmentSlotDate> _slotDates = [];
  bool _isLoadingSlots = true;
  String? _slotError;
  AppointmentSlotDate? _selectedDate;
  AppointmentSlotTime? _selectedTime;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    try {
      final response = await _appointmentService.fetchSlots(
        doctorUid: widget.doctorUid,
      );
      if (!mounted) return;
      setState(() {
        _slotDates = response.dates;
        _isLoadingSlots = false;
      });
      _selectFirstAvailable();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _slotDates = [];
        _isLoadingSlots = false;
        _slotError = "Failed to load slots.";
      });
      _selectFirstAvailable();
    }
  }

  void _selectFirstAvailable() {
    if (_slotDates.isEmpty) {
      return;
    }

    final todayDate = _slotDates.first;
    final availableTimes = todayDate.times
        .where((time) => time.available)
        .toList();

    setState(() {
      _selectedDate = todayDate;
      _selectedTime = availableTimes.isNotEmpty ? availableTimes.first : null;
    });
  }

  List<AppointmentSlotDate> _buildFallbackSlots() {
    return [];
  }

  String _formatMonthLabel(String? dateKey) {
    if (dateKey == null || dateKey.isEmpty) {
      return "";
    }

    try {
      final date = DateTime.parse(dateKey);
      const monthNames = [
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December",
      ];
      return monthNames[date.month - 1];
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF3F1EF);
    const lightText = Color(0xFF9B918C);
    final dates = _slotDates.isNotEmpty ? _slotDates : _buildFallbackSlots();
    final selectedDate =
        _selectedDate ?? (dates.isNotEmpty ? dates.first : null);
    final selectedTimes = selectedDate?.times ?? [];
    final backendTodayKey = dates.isNotEmpty ? dates.first.dateKey : null;
    final monthLabel = _formatMonthLabel(selectedDate?.dateKey);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 50),

            // Back button
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Color(0xFF4B3425).withOpacity(0.8)),
                ),
                child: const Icon(Icons.chevron_left, color: Color(0xFF4B3425)),
              ),
            ),

            const SizedBox(height: 25),

            // Title
            const Text(
              "Detail Doctor",
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Color(0xFF4B3425),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Get more information",
              style: TextStyle(
                color: lightText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 30),

            // Doctor card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8EBDD),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        widget.doctorAvatarUrl.isNotEmpty
                            ? widget.doctorAvatarUrl
                            : "https://images.unsplash.com/photo-1594824476967-48c8b964273f",
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.person, color: Colors.brown);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.doctorName,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4B3425),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.doctorSpecialty,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF4B3425),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Biography
            const Text(
              "Biography",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: lightText,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.doctorSpecialty.isNotEmpty
                  ? "Specialty: ${widget.doctorSpecialty}"
                  : "Specialty not available",
              style: const TextStyle(
                color: lightText,
                height: 1.5,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 30),

            // Calendar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Calendar",
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF09121C),
                  ),
                ),
                Row(
                  children: [
                    Text(monthLabel, style: TextStyle(color: lightText)),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (int i = 0; i < dates.length && i < 5; i++)
                  GestureDetector(
                    onTap: () {
                      final date = dates[i];
                      if (!date.hasAvailability &&
                          date.dateKey != backendTodayKey) {
                        return;
                      }
                      setState(() {
                        _selectedDate = date;
                        final availableTimes = date.times
                            .where((t) => t.available)
                            .toList();
                        _selectedTime = availableTimes.isNotEmpty
                            ? availableTimes.first
                            : null;
                      });
                    },
                    child: DateChip(
                      day: dates[i].day,
                      week: dates[i].weekday,
                      selected: selectedDate?.dateKey == dates[i].dateKey,
                      disabled:
                          !dates[i].hasAvailability &&
                          dates[i].dateKey != backendTodayKey,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 21),

            // Time
            const Text(
              "Time",
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF09121C),
              ),
            ),

            const SizedBox(height: 19),

            Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                for (final time in selectedTimes)
                  GestureDetector(
                    onTap: () {
                      if (!time.available) {
                        return;
                      }
                      setState(() {
                        _selectedTime = time;
                      });
                    },
                    child: TimeChip(
                      text: time.displayLabel,
                      selected: _selectedTime?.time == time.time,
                      disabled: !time.available,
                    ),
                  ),
              ],
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (selectedDate == null || _selectedTime == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please select a date and time."),
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CheckoutPage(
                        doctorName: widget.doctorName,
                        doctorSpecialty: widget.doctorSpecialty,
                        doctorUid: widget.doctorUid,
                        dateKey: selectedDate.dateKey,
                        dateLabel:
                            "${selectedDate.day} ${selectedDate.weekday}",
                        timeValue: _selectedTime!.time,
                        timeLabel: _selectedTime!.displayLabel,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4B3425),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  "Book Appointment",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 75),
          ],
        ),
      ),
    );
  }
}

class DateChip extends StatelessWidget {
  final String day;
  final String week;
  final bool selected;
  final bool disabled;

  const DateChip({
    super.key,
    required this.day,
    required this.week,
    this.selected = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFE0A500);

    return Container(
      width: 60,
      height: 70,
      decoration: BoxDecoration(
        color: selected
            ? yellow
            : disabled
            ? const Color(0xFFE8E7EA)
            : Colors.white,
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : Colors.black,
            ),
          ),
          Text(
            week,
            style: TextStyle(
              fontSize: 15,
              color: selected ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class TimeChip extends StatelessWidget {
  final String text;
  final bool selected;
  final bool disabled;

  const TimeChip({
    super.key,
    required this.text,
    this.selected = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFE5A900);
    const disabledColor = Color(0xFFE8E7EA);
    const disabledText = Color(0xFF9B918C);

    return Container(
      width: 84,
      height: 36,
      decoration: BoxDecoration(
        color: selected
            ? yellow
            : disabled
            ? disabledColor
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: selected
              ? Colors.white
              : disabled
              ? disabledText
              : Colors.black54,
        ),
      ),
    );
  }
}
