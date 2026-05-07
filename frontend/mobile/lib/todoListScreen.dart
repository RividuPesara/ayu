import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Task {
  String title;
  TimeOfDay time;
  bool isDone;

  Task({required this.title, required this.time, this.isDone = false});
}

class ToDoList extends StatefulWidget {
  const ToDoList({super.key});

  @override
  State<ToDoList> createState() => _ToDoListState();
}

class _ToDoListState extends State<ToDoList> {
  DateTime selectedDate = DateTime.now();

  Map<String, List<Task>> tasksByDate = {};

  List<DateTime> getCurrentWeek() {
    DateTime now = DateTime.now();
    int weekday = now.weekday;

    DateTime startOfWeek = now.subtract(Duration(days: weekday % 7));

    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  String formatKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  List<Task> getTasksForSelectedDate() {
    return tasksByDate[formatKey(selectedDate)] ?? [];
  }

  void addTask(String title, TimeOfDay time) {
    String key = formatKey(selectedDate);

    if (!tasksByDate.containsKey(key)) {
      tasksByDate[key] = [];
    }

    tasksByDate[key]!.add(Task(title: title, time: time));

    setState(() {});
  }

  void toggleTask(Task task) {
    setState(() {
      task.isDone = !task.isDone;
    });
  }

  void showAddTaskDialog() {
    TextEditingController nameController = TextEditingController();
    TimeOfDay? selectedTime = null;
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

                  // Time selection button
                  GestureDetector(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedTime = picked;
                          if (isTimeMissing) {
                            isTimeMissing = false;
                          }
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
                          Icon(
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
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
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
                          side: BorderSide(
                            color: const Color(0xFF4B3425),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                        child: Text(
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

                          addTask(nameController.text.trim(), selectedTime!);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C6CA8),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                        child: Text(
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
                onTap: () {},
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: Color(0xffF7F4F2),
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(
                          color: Color(0xff4B3425),
                          width: 1.0
                      ),
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
                    color: Color(0xff4B3425)
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Your path to balance, outlined day by day.\nTake a breath and focus on what matters.",
                style: TextStyle(
                  color: Color(0xff6D6661),
                  fontSize: 17,
                ),
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
                    bool isSelected = DateFormat('yyyy-MM-dd').format(date) ==
                        DateFormat('yyyy-MM-dd').format(selectedDate);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedDate = date;
                        });
                      },
                      child: Container(
                        width: 69,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF7C6CA8)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 5,
                            )
                          ] : null,
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
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black,
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
                    style:
                    TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff4B3425),
                    ),
                  ),
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
                  )
                ],
              ),

              const SizedBox(height: 15),

              // Task List
              Expanded(
                child: ListView(
                  children: getTasksForSelectedDate().map((task) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
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
                            onTap: () => toggleTask(task),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: task.isDone
                                  ? Colors.green
                                  : Colors.grey.shade300,
                              child: task.isDone
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                        color: Color(0xff4D5558)
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat.jm().format(
                                        DateTime(0, 0, 0, task.time.hour, task.time.minute),
                                      ),
                                      style: const TextStyle(color: Color(0xff4D5558)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  }).toList(),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}