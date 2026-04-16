import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_app/Mood Journal/mood_journal_service.dart';

class NewJournalEntryPage extends StatefulWidget {
  const NewJournalEntryPage({super.key});

  @override
  State<NewJournalEntryPage> createState() => _NewJournalEntryPageState();
}

class _NewJournalEntryPageState extends State<NewJournalEntryPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _entryController = TextEditingController();

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _entryFocusNode = FocusNode();

  final ImagePicker _picker = ImagePicker();

  final List<String> _undoStack = [];
  final List<String> _redoStack = [];

  File? _selectedImage;
  bool _isUndoRedoAction = false;
  bool _isSubmitting = false;

  static const List<String> _journalMoodKeys = [
    'Depression',
    'Anxiety',
    'Normal',
    'Normal',
  ];

  int selectedMood = 0;
  static const int _maxChars = 300;

  final List<String> moodImages = [
    "assets/faces/sad.png",
    "assets/faces/anxiety.png",
    "assets/faces/normal.png",
    "assets/faces/happy.png",
  ];

  final List<Color> moodShadowColors = [
    Color(0xFFFF8A5B), // sad
    Color(0xFF8E7CFF), // anxiety
    Color(0xFFB0A8A0), // normal
    Color(0xFFFFC857), // happy
  ];

  @override
  void initState() {
    super.initState();

    _entryController.addListener(_handleEntryTextChanged);
    unawaited(MoodJournalRepository.instance.ensureInitialized());
  }

  void _handleEntryTextChanged() {
    if (_isUndoRedoAction) return;

    if (_undoStack.isEmpty || _undoStack.last != _entryController.text) {
      _undoStack.add(_entryController.text);
    }

    if (_redoStack.isNotEmpty) {
      _redoStack.clear();
    }

    setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _entryController.dispose();
    _titleFocusNode.dispose();
    _entryFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _persistEntryInBackground({
    required String tempId,
    required String title,
    required String content,
    required String userMood,
    required bool incrementedDay,
    required int previousActiveDaysCount,
    required int previousJournalStreak,
    required String previousLastActiveDateKey,
  }) async {
    final repository = MoodJournalRepository.instance;

    try {
      final result = await createJournalEntry(
        title: title,
        content: content,
        userMood: userMood,
      );
      repository.replaceEntry(tempId, result.entry);
      repository.syncFromJournalCreateResult(result);
    } catch (_) {
      repository.removeEntryById(tempId);
      if (incrementedDay) {
        repository.restoreDayCounters(
          activeDaysCount: previousActiveDaysCount,
          journalStreak: previousJournalStreak,
          lastActiveDateKey: previousLastActiveDateKey,
        );
      }
    } finally {
      _isSubmitting = false;
    }
  }

  Future<void> _submitEntry() async {
    if (_isSubmitting) {
      return;
    }

    final title = _titleController.text.trim();
    final content = _entryController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both title and entry')),
      );
      return;
    }

    final selectedMoodKey = _journalMoodKeys[selectedMood];
    final tempId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    final repository = MoodJournalRepository.instance;
    final previousActiveDaysCount = repository.activeDaysCount;
    final previousJournalStreak = repository.journalStreak;
    final previousLastActiveDateKey = repository.lastActiveDateKey;
    final incrementedDay = repository.incrementActiveDayIfNeeded();

    repository.insertOptimisticEntry(
      JournalEntryItem(
        entryId: tempId,
        title: title,
        content: content,
        userMood: selectedMoodKey,
        aiMood: 'pending',
        isMismatch: false,
        safetyFlag: 'non_crisis',
        entryDate: DateTime.now(),
      ),
    );

    _isSubmitting = true;

    if (mounted) {
      Navigator.pop(context);
    }

    unawaited(
      _persistEntryInBackground(
        tempId: tempId,
        title: title,
        content: content,
        userMood: selectedMoodKey,
        incrementedDay: incrementedDay,
        previousActiveDaysCount: previousActiveDaysCount,
        previousJournalStreak: previousJournalStreak,
        previousLastActiveDateKey: previousLastActiveDateKey,
      ),
    );
  }

  void _undo() {
    if (_undoStack.length <= 1) return;

    _isUndoRedoAction = true;

    final currentText = _undoStack.removeLast();
    _redoStack.add(currentText);

    final previousText = _undoStack.last;
    _entryController.text = previousText;
    _entryController.selection = TextSelection.fromPosition(
      TextPosition(offset: _entryController.text.length),
    );

    _isUndoRedoAction = false;
    setState(() {});
  }

  void _redo() {
    if (_redoStack.isEmpty) return;

    _isUndoRedoAction = true;

    final redoText = _redoStack.removeLast();
    _undoStack.add(redoText);

    _entryController.text = redoText;
    _entryController.selection = TextSelection.fromPosition(
      TextPosition(offset: _entryController.text.length),
    );

    _isUndoRedoAction = false;
    setState(() {});
  }

  Widget moodImage(int index, bool isSelected) {
    return AnimatedScale(
      scale: isSelected ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: moodShadowColors[index].withOpacity(0.35),
                    blurRadius: 4,
                    spreadRadius: 2,
                    offset: const Offset(0, 0),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: SizedBox(
            width: 70,
            height: 70,
            child: ClipOval(
              child: Image.asset(moodImages[index], fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFF2EFEC) : const Color(0xFFE6E2DE),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? const Color(0xFF5C3B29) : const Color(0xFFA59A93),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF5F1EF);
    const brown = Color(0xFF4B3425);
    const border = Color(0xFF9A887C);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final characterCount = _entryController.text.length;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + bottomInset),
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
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: brown, width: 1.2),
                        ),
                        child: const Icon(
                          Icons.chevron_left,
                          color: brown,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    const Text(
                      "New Journal Entry",
                      style: TextStyle(
                        fontSize: 25,
                        fontFamily: 'Urbanist',
                        fontWeight: FontWeight.w700,
                        color: brown,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 38),

                const Text(
                  "Journal Title",
                  style: TextStyle(
                    fontSize: 17,
                    fontFamily: 'Urbanist',
                    fontWeight: FontWeight.w600,
                    color: brown,
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        color: brown,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _titleController,
                          focusNode: _titleFocusNode,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) {
                            FocusScope.of(
                              context,
                            ).requestFocus(_entryFocusNode);
                          },
                          style: const TextStyle(
                            fontSize: 19,
                            fontFamily: 'Urbanist',
                            fontWeight: FontWeight.w600,
                            color: Color(0xA31F160F),
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            hintText: "Feeling Bad Again",
                            hintStyle: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Urbanist',
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6E625D),
                            ),
                          ),
                        ),
                      ),
                      const Icon(Icons.edit_outlined, color: brown, size: 18),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  "Select Your Emotion",
                  style: TextStyle(
                    fontSize: 17,
                    fontFamily: 'Urbanist',
                    fontWeight: FontWeight.w600,
                    color: brown,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: List.generate(moodImages.length, (index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedMood = index;
                        });
                      },
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index == moodImages.length - 1 ? 0 : 18,
                        ),
                        child: moodImage(index, selectedMood == index),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 24),

                const Text(
                  "Write Your Entry",
                  style: TextStyle(
                    fontFamily: 'Urbanist',
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                    color: brown,
                  ),
                ),
                const SizedBox(height: 18),

                Container(
                  constraints: const BoxConstraints(minHeight: 300),
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  decoration: BoxDecoration(
                    color: Color(0xFFFDFDFD),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: border, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 190,
                        child: TextField(
                          controller: _entryController,
                          focusNode: _entryFocusNode,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          maxLines: null,
                          expands: true,
                          maxLength: _maxChars,
                          style: const TextStyle(
                            fontSize: 28,
                            height: 1.35,
                            color: Color(0xFF4B3425),
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            counterText: "",
                            hintText:
                                "I had a bad day today, at\nschool... It’s fine I guess...",
                            hintStyle: TextStyle(
                              fontSize: 28,
                              height: 1.35,
                              color: Color(0xFF8E8782),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      if (_selectedImage != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            _selectedImage!,
                            height: 90,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],

                      const SizedBox(height: 33),

                      Row(
                        children: [
                          _smallIconButton(
                            icon: Icons.undo_rounded,
                            onTap: _undo,
                            enabled: _undoStack.length > 1,
                          ),
                          const SizedBox(width: 10),
                          _smallIconButton(
                            icon: Icons.redo_rounded,
                            onTap: _redo,
                            enabled: _redoStack.isNotEmpty,
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _pickPhoto,
                            style: TextButton.styleFrom(foregroundColor: brown),
                            icon: const Icon(
                              Icons.camera_alt_outlined,
                              size: 18,
                            ),
                            label: const Text(
                              "Add Photo",
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "$characterCount/$_maxChars",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: brown,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 42),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _submitEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brown,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Create Journal",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.check, size: 20, color: Color(0xFFFFFFFF)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
