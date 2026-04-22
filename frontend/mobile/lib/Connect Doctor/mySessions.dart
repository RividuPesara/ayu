import 'package:flutter/material.dart';
import 'package:mobile_app/Connect Doctor/currentAppointments.dart';
import 'package:mobile_app/Connect%20Doctor/appointment_service.dart';

class MyAppointmentScreen extends StatefulWidget {
  const MyAppointmentScreen({super.key});

  @override
  State<MyAppointmentScreen> createState() => _MyAppointmentScreenState();
}

class _MyAppointmentScreenState extends State<MyAppointmentScreen> {
  bool isUpcomingSelected = true;
  final AppointmentService _appointmentService = AppointmentService();
  bool _isLoading = true;
  String? _errorMessage;
  List<MobileAppointment> _appointments = [];

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    try {
      final results = await _appointmentService.listMyAppointments();
      if (!mounted) return;
      setState(() {
        _appointments = results;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color purple = Color(0xFF64548E);
    const Color lightPurple = Color(0xFF8A78B8);
    const Color background = Color(0xFFF3F1EF);
    const Color brownText = Color(0xFF5A3D2B);
    const Color subtitleText = Color(0xFF6C6C6C);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    bool isPastLate(MobileAppointment appointment) {
      if (appointment.status != "overdue") return false;
      final dateKey = appointment.dateKey;
      try {
        final date = DateTime.parse(dateKey);
        return date.isBefore(today);
      } catch (_) {
        return false;
      }
    }

    final upcomingAppointments = _appointments
        .where(
          (appointment) =>
              appointment.status == "upcoming" ||
              (appointment.status == "overdue" && !isPastLate(appointment)),
        )
        .toList();
    final pastAppointments = _appointments
        .where(
          (appointment) =>
              appointment.status == "done" || isPastLate(appointment),
        )
        .toList();
    final visibleAppointments = isUpcomingSelected
        ? upcomingAppointments
        : pastAppointments;

    return Scaffold(
      backgroundColor: background,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
            decoration: const BoxDecoration(
              color: purple,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 42,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.3),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  "My Appointments",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 59,
                  decoration: BoxDecoration(
                    color: lightPurple,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              isUpcomingSelected = true;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: isUpcomingSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Center(
                              child: Text(
                                "Upcoming",
                                style: TextStyle(
                                  color: isUpcomingSelected
                                      ? purple
                                      : Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              isUpcomingSelected = false;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: !isUpcomingSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Center(
                              child: Text(
                                "Past",
                                style: TextStyle(
                                  color: !isUpcomingSelected
                                      ? purple
                                      : Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF64548E)),
                  )
                : visibleAppointments.isEmpty
                ? Center(
                    child: Text(
                      _errorMessage ?? "No appointments yet",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF4B3425),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                    itemCount: visibleAppointments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 19),
                    itemBuilder: (context, index) {
                      final appointment = visibleAppointments[index];
                      final isOverdue = appointment.status == "overdue";
                      final isDone = appointment.status == "done";
                      final badgeLabel = isUpcomingSelected
                          ? (isOverdue ? "Late" : "Upcoming")
                          : (isDone ? "Done" : "Late");
                      final badgeColor = isUpcomingSelected
                          ? (isOverdue ? Colors.red : Colors.green)
                          : (isDone ? Colors.blueGrey : Colors.red);
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AppointmentDetailScreen(
                                appointment: appointment,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F7F6),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF64548E,
                                ).withOpacity(0.45),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 62,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4E6D9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    appointment.doctorAvatarUrl.isNotEmpty
                                        ? appointment.doctorAvatarUrl
                                        : "https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?auto=format&fit=crop&w=300&q=80",
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.person,
                                        color: Colors.brown,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      appointment.doctorName,
                                      style: const TextStyle(
                                        color: brownText,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      appointment.doctorSpecialty,
                                      style: const TextStyle(
                                        color: subtitleText,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      appointment.displayTime,
                                      style: const TextStyle(
                                        color: subtitleText,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      appointment.displayDate,
                                      style: const TextStyle(
                                        color: subtitleText,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  badgeLabel,
                                  style: TextStyle(
                                    color: badgeColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
