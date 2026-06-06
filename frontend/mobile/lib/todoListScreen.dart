import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'Todo List/task_service.dart';
import 'Notification/local_notification_scheduler.dart';
import 'dashboard_cache.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ToDoList(),
    );
  }
}

class ToDoList extends StatefulWidget {
  const ToDoList({super.key, this.isReadOnly = false});

  final bool isReadOnly;

  @override
  State<ToDoList> createState() => _ToDoListState();
}

class _ToDoListState extends State<ToDoList> {
  DateTime selectedDate = DashboardCache.adjustedNow();
  List<TaskItem> _tasks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  bool get _isPastDate {
    final today = DashboardCache.adjustedNow();
    return selectedDate.isBefore(DateTime(today.year, today.month, today.day));
  }

  List<DateTime> getCurrentWeek() {
    DateTime now = DashboardCache.adjustedNow();
    int weekday = now.weekday;
    DateTime startOfWeek = now.subtract(Duration(days: weekday % 7));
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  String formatKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _toTimeString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatTaskTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return time;
    final dt = DateTime(0, 0, 0, int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat.jm().format(dt);
  }

  Future<void> _loadTasks() async {
    final dateKey = formatKey(selectedDate);
    final repo = TaskRepository.instance;

    // Show stale cache immediately while a fresh fetch runs in background
    await repo.loadCachedTasks(dateKey);
    if (mounted) {
      setState(() => _tasks = repo.tasksFor(dateKey));
    }

    if (!repo.hasFreshCache(dateKey)) {
      if (mounted) setState(() => _isLoading = true);
      try {
        final tasks = await repo.fetchTasks(dateKey);
        if (mounted) {
          setState(() {
            _tasks = tasks;
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

  void _toggleTask(TaskItem task) {
    final dateKey = formatKey(selectedDate);
    final repo = TaskRepository.instance;

    repo.optimisticallyToggle(dateKey, task.taskId);
    setState(() => _tasks = repo.tasksFor(dateKey));

    toggleTaskApi(task.taskId).then((updated) {
      // if task is now done cancel its reminder
      if (updated.isDone) {
        LocalNotificationScheduler.instance.cancelTaskReminder(task.taskId);
      }
    }).catchError((_) {
      repo.revertToggle(dateKey, task.taskId);
      if (mounted) setState(() => _tasks = repo.tasksFor(dateKey));
    });
  }

  Future<void> _deleteTask(TaskItem task) async {
    final dateKey = formatKey(selectedDate);
    final repo = TaskRepository.instance;
    // Keep a backup to restore if the API call fails
    final backup = repo.tasksFor(dateKey);

    repo.removeByTaskId(dateKey, task.taskId);
    setState(() => _tasks = repo.tasksFor(dateKey));

    deleteTaskApi(task.taskId).catchError((_) {
      repo.restoreBackup(dateKey, backup);
      if (mounted) {
        setState(() => _tasks = repo.tasksFor(dateKey));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to delete "${task.title}". Please try again.',
            ),
          ),
        );
      }
    });
  }

  void showAddTaskDialog() {
    TextEditingController nameController = TextEditingController();
    TimeOfDay? selectedTime;
    bool isTextEmpty = false;
    bool isTimeMissing = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                "Add Task",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4B3425),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Task",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B3425),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: "Enter task",
                      errorText: isTextEmpty ? "Please enter a task" : null,
                      errorBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Time",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B3425),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedTime = picked;
                          if (isTimeMissing) isTimeMissing = false;
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: isTimeMissing && selectedTime == null
                              ? Colors.red
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: Color(0xff605D62),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            selectedTime != null
                                ? selectedTime!.format(context)
                                : "Select Time",
                            style: const TextStyle(
                              color: Color(0xff605D62),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isTimeMissing)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "       Please select a time",
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
              actions: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4B3425),
                          side: const BorderSide(color: Color(0xFF4B3425)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                          setDialogState(() {
                            isTextEmpty = nameController.text.trim().isEmpty;
                            isTimeMissing = selectedTime == null;
                          });

                          if (isTextEmpty || isTimeMissing) return;

                          final title = nameController.text.trim();
                          final dateKey = formatKey(selectedDate);
                          final timeStr = _toTimeString(selectedTime!);
                          final tempId =
                              'local_${DateTime.now().millisecondsSinceEpoch}';
                          final repo = TaskRepository.instance;

                          // Insert placeholder immediately so the UI responds without waiting
                          repo.insertOptimistic(
                            dateKey,
                            TaskItem(
                              taskId: tempId,
                              userId: '',
                              title: title,
                              dateKey: dateKey,
                              time: timeStr,
                              isDone: false,
                            ),
                          );
                          setState(() => _tasks = repo.tasksFor(dateKey));

                          // Capture messenger before the async gap to avoid stale context
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(context);

                          createTask(
                                title: title,
                                dateKey: dateKey,
                                time: timeStr,
                              )
                              .then((real) {
                                repo.replaceOptimistic(dateKey, tempId, real);
                                repo.invalidateDate(dateKey);
                                if (mounted) {
                                  setState(
                                    () => _tasks = repo.tasksFor(dateKey),
                                  );
                                }
                                // schedule a reminder 15 min before due time
                                final uid = FirebaseAuth.instance.currentUser?.uid;
                                if (uid != null) {
                                  LocalNotificationScheduler.instance.scheduleTaskReminder(
                                    uid: uid,
                                    taskId: real.taskId,
                                    title: real.title,
                                    dateKey: real.dateKey,
                                    time: real.time,
                                  );
                                }
                              })
                              .catchError((_) {
                                repo.removeByTaskId(dateKey, tempId);
                                if (mounted) {
                                  setState(
                                    () => _tasks = repo.tasksFor(dateKey),
                                  );
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Failed to add task. Please try again.',
                                      ),
                                    ),
                                  );
                                }
                              });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C6CA8),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<DateTime> week = getCurrentWeek();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: Color(0xffF7F4F2),
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: Color(0xff4B3425), width: 1.0),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Color(0xff4B3425),
                    size: 25,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Weekly Tasks",
                style: TextStyle(
                  fontSize: 50,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff4B3425),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Your path to balance, outlined day by day.\nTake a breath and focus on what matters.",
                style: TextStyle(color: Color(0xff6D6661), fontSize: 17),
              ),
              const SizedBox(height: 30),
              // Week view
              SizedBox(
                height: 84,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: week.length,
                  itemBuilder: (context, index) {
                    DateTime date = week[index];
                    bool isSelected =
                        DateFormat('yyyy-MM-dd').format(date) ==
                            DateFormat('yyyy-MM-dd').format(selectedDate);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedDate = date;
                          _tasks = [];
                          _isLoading = true;
                        });
                        _loadTasks();
                      },
                      child: Container(
                        width: 69,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF7C6CA8)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isSelected
                              ? [
                                  const BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 5,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('EEE').format(date).toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF8F8F8F),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              date.day.toString(),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 50),
              // Today Task Heading
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Today's Tasks",
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff4B3425),
                    ),
                  ),
                  if (!widget.isReadOnly && !_isPastDate)
                    GestureDetector(
                      onTap: showAddTaskDialog,
                      child: const Text(
                        "Add Task",
                        style: TextStyle(
                          color: Color(0xFF7C6CA8),
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 15),
              // Task List
              Expanded(
                child: _isLoading && _tasks.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF7C6CA8),
                          strokeWidth: 2.5,
                        ),
                      )
                    : ListView(
                        children: ([..._tasks]
                              ..sort((a, b) {
                                final doneOrder = a.isDone == b.isDone
                                    ? 0
                                    : a.isDone ? 1 : -1;
                                if (doneOrder != 0) return doneOrder;
                                return a.time.compareTo(b.time);
                              }))
                            .asMap()
                            .entries
                            .map((entry) {
                          final index = entry.key;
                          final task = entry.value;

                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == _tasks.length - 1 ? 0 : 15,
                            ),
                            child: Dismissible(
                              key: ValueKey(task.taskId),
                              direction: widget.isReadOnly
                                  ? DismissDirection.none
                                  : DismissDirection.endToStart,
                              background: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD94F4F),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              onDismissed: (_) => _deleteTask(task),
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: task.isDone
                                      ? Colors.grey.shade300
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: widget.isReadOnly
                                          ? null
                                          : () => _toggleTask(task),
                                      child: CircleAvatar(
                                        radius: 12,
                                        backgroundColor: task.isDone
                                            ? Colors.green
                                            : Colors.grey.shade300,
                                        child: task.isDone
                                            ? const Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task.title,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              decoration: task.isDone
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.access_time,
                                                size: 16,
                                                color: Color(0xff4D5558),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatTaskTime(task.time),
                                                style: const TextStyle(
                                                  color: Color(0xff4D5558),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}