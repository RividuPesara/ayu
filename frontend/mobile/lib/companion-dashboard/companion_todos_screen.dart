import 'package:flutter/material.dart';
import '../Todo List/task_service.dart';
import '../dashboard_cache.dart';

class CompanionTodosScreen extends StatefulWidget {
  const CompanionTodosScreen({super.key});

  @override
  State<CompanionTodosScreen> createState() => _CompanionTodosScreenState();
}

class _CompanionTodosScreenState extends State<CompanionTodosScreen> {
  bool _isLoading = true;
  String? _error;
  List<TaskItem> _tasks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dateKey = DashboardCache.adjustedDayKey();
      final tasks = await TaskRepository.instance.fetchTasks(dateKey);
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _error = msg.contains('403')
            ? 'The patient has restricted access to their to-do list.'
            : 'Could not load tasks.';
        _isLoading = false;
      });
    }
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
                color: Color(0xFFFFDB8F),
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
                        border: Border.all(
                            color: const Color(0xFF4B3425), width: 1.5),
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Color(0xFF4B3425), size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'To-Do List',
                        style: TextStyle(
                          color: Color(0xFF4B3425),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Read only · Today',
                        style: TextStyle(
                            color: Color(0xFF7B6030), fontSize: 12),
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
                          color: Color(0xFFFFDB8F)))
                  : _error != null
                      ? _buildMessage(_error!)
                      : _tasks.isEmpty
                          ? _buildMessage('No tasks for today.')
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _tasks.length,
                              itemBuilder: (_, i) =>
                                  _buildTaskCard(_tasks[i]),
                            ),
            ),
          ],
        ),
      ),
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

  Widget _buildTaskCard(TaskItem task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Read-only checkbox
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: task.isDone ? const Color(0xFF9BB068) : Colors.transparent,
              border: Border.all(
                color: task.isDone
                    ? const Color(0xFF9BB068)
                    : const Color(0xFFCCCCCC),
                width: 2,
              ),
            ),
            child: task.isDone
                ? const Icon(Icons.check, color: Colors.white, size: 13)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: const Color(0xFF4B3425),
                    fontWeight: FontWeight.w500,
                    decoration: task.isDone
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                if (task.time.isNotEmpty && task.time != '00:00')
                  Text(
                    task.time,
                    style: const TextStyle(
                        color: Color(0xFF9B8A7E), fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
