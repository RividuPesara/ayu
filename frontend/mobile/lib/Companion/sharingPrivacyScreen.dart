import 'package:flutter/material.dart';
import 'package:mobile_app/Companion/companion_service.dart';

class CompanionPrivacyScreen extends StatefulWidget {
  const CompanionPrivacyScreen({super.key});

  @override
  State<CompanionPrivacyScreen> createState() =>
      _CompanionPrivacyScreenState();
}

class _CompanionPrivacyScreenState extends State<CompanionPrivacyScreen> {
  final _service = CompanionService();

  bool moodJournal = true;
  bool todoList = false;
  bool tracking = true;
  bool dailyPlans = true;

  bool _loadingInit = true;
  bool _saving = false;

  final Color bgColor = const Color(0xFFF5F1EF);
  final Color brown = const Color(0xFF4B3425);

  @override
  void initState() {
    super.initState();
    _loadPrivacy();
  }

  Future<void> _loadPrivacy() async {
    try {
      final privacy = await _service.getPrivacy();
      if (!mounted) return;
      setState(() {
        moodJournal = privacy.moodJournal;
        todoList = privacy.todoList;
        tracking = privacy.tracking;
        dailyPlans = privacy.doctorAppointments;
        _loadingInit = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingInit = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.savePrivacy(
        CompanionPrivacy(
          moodJournal: moodJournal,
          todoList: todoList,
          tracking: tracking,
          doctorAppointments: dailyPlans,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Privacy settings saved.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _loadingInit
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF6B5A4A),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 28,
                              color: Color(0xFF4B3425),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Companion',
                          style: TextStyle(
                            color: Color(0xFF4B3425),
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 44),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      decoration: BoxDecoration(
                        color: brown,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Space, Your\nTerms',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 18),
                          Text(
                            'Control how much of your journey you share\nCompanion.',
                            style: TextStyle(
                              color: Color(0xFF9C8A7D),
                              fontSize: 19,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    privacyTile(
                      icon: Icons.sentiment_satisfied_alt,
                      title: 'Mood Journal',
                      subtitle: 'Allow companion to see your\nmood entries',
                      value: moodJournal,
                      onChanged: (v) => setState(() => moodJournal = v),
                    ),

                    privacyTile(
                      icon: Icons.checklist,
                      title: 'To-Do List',
                      subtitle: 'Share your daily tasks and\npriorities',
                      value: todoList,
                      onChanged: (v) => setState(() => todoList = v),
                    ),

                    privacyTile(
                      icon: Icons.bar_chart,
                      title: 'Tracking',
                      subtitle: 'Enable health and activity\nmetric sharing',
                      value: tracking,
                      onChanged: (v) => setState(() => tracking = v),
                    ),

                    privacyTile(
                      icon: Icons.calendar_today,
                      title: 'Doctor Appointments',
                      subtitle:
                          'Let your companion see\nupcoming doctor appointments',
                      value: dailyPlans,
                      onChanged: (v) => setState(() => dailyPlans = v),
                    ),

                    const Spacer(),

                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 53,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brown,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget privacyTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 26),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 26,
            color: const Color(0xFF4B3425),
          ),

          const SizedBox(width: 20),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF4B3425),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF4B3425),
                    fontSize: 19,
                    height: 1.15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: brown,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFDCDDD9),
              trackOutlineColor:
                  WidgetStateProperty.all(Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }
}
