import 'package:flutter/material.dart';
import '../Tracker/tracker_service.dart';
import '../dashboard_cache.dart';

class CompanionTrackerScreen extends StatefulWidget {
  const CompanionTrackerScreen({super.key});

  @override
  State<CompanionTrackerScreen> createState() => _CompanionTrackerScreenState();
}

class _CompanionTrackerScreenState extends State<CompanionTrackerScreen> {
  bool _isLoading = true;
  String? _error;
  List<ScheduleItem> _meds = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dateKey = DashboardCache.adjustedDayKey();
      final meds = await TrackerRepository.instance.fetchSchedule(dateKey);
      setState(() {
        _meds = meds;
        _isLoading = false;
      });
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _error = msg.contains('403')
            ? 'The patient has restricted access to their tracker.'
            : 'Could not load medication schedule.';
        _isLoading = false;
      });
    }
  }

  double get _progress {
    final visible = _meds.where((m) => m.status != 'missed').toList();
    if (visible.isEmpty) return 0.0;
    return visible.where((m) => m.status == 'taken').length / visible.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF9BB068),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medication Tracker',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Read only · Today',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF9BB068)))
                  : _error != null
                      ? _buildMessage(_error!)
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final visible = _meds.where((m) => m.status != 'missed').toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Progress bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Today\'s Progress',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4B3425),
                    ),
                  ),
                  Text(
                    '${(visible.isEmpty ? 0 : visible.where((m) => m.status == 'taken').length)}/${visible.length} taken',
                    style: const TextStyle(
                        color: Color(0xFF9B8A7E), fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(20),
                backgroundColor: const Color(0xFFE8EFD8),
                color: const Color(0xFF9BB068),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (visible.isEmpty)
          _buildMessage('No medications scheduled for today.')
        else
          ...visible.map((item) => _buildMedCard(item)),
      ],
    );
  }

  Widget _buildMessage(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(msg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF9B8A7E))),
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
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xffF2F5EB),
                  borderRadius: BorderRadius.circular(20),
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
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4B3425),
                      decoration: isTaken
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  Text(
                    item.scheduledTime,
                    style: const TextStyle(
                        color: Color(0xFF9B8A7E), fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          // Read-only status — no tap
          isTaken
              ? Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                    border: Border.all(
                        color: const Color(0xff4B3425), width: 2),
                  ),
                  child: const Icon(Icons.check,
                      color: Colors.white, size: 16),
                )
              : const Icon(Icons.circle_outlined,
                  size: 28, color: Color(0xffCCCCCC)),
        ],
      ),
    );
  }
}
