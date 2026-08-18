import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app/Mood Journal/moodSelectorScreen.dart';
import 'package:mobile_app/homeScreen.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';

class Quiz extends StatefulWidget {
  const Quiz({super.key});

  @override
  State<Quiz> createState() => _QuizState();
}

class _QuizState extends State<Quiz> {
  final PageController _controller = PageController();

  int currentPage = 0;

  // Quiz Answers
  int? gender;
  int? mood;
  int? religion;
  int? medical;
  int? activePicker;
  int? stage;
  int? treatment;
  Set<int> treatments = {};

  Set<int> interests = {};

  int day = 1;
  int month = 1;
  int year = 2000;

  String _cancerType = '';
  bool _dobEntered = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyCompleted();
  }

  Future<void> _checkIfAlreadyCompleted() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!mounted) return;

    final profile = doc.data()?['patientProfile'];
    if (profile is Map && (profile['interests'] as List?)?.isNotEmpty == true) {
      Navigator.pop(context);
    }
  }

  void nextPage() {
    if (_isSaving) return;
    if (currentPage < 6) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    } else {
      _saveQuizData();
    }
  }

  void prevPage() {
    if (currentPage > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  static const _genderLabels = [
    'Male',
    'Female',
    'Transgender',
    'Prefer not to say',
  ];
  static const _moodLabels = [
    'Happy & excited',
    'Calm & okay',
    'A little sad',
    'Worried or scared',
  ];
  static const _religionLabels = [
    'Christian',
    'Muslim',
    'Buddhist',
    'Hindu',
    'Other',
    'Prefer not to say',
  ];
  static const _stageLabels = ['Early', 'Advanced', 'In remission', 'Not sure'];
  static const _treatmentLabels = [
    'Chemotherapy',
    'Surgery',
    'Radiation',
    'None right now',
  ];
  static const _interestLabels = [
    'Calm & peaceful',
    'Educational',
    'Documentary',
    'Science',
    'Songs & music',
  ];

  Future<void> _saveQuizData() async {
    if (interests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('quiz.errPickStory')),
        ),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);

    try {
      final patientProfile = <String, dynamic>{
        'interests': interests.map((i) => _interestLabels[i]).toList(),
        if (mood != null) 'initialMood': _moodLabels[mood!],
        if (_cancerType.isNotEmpty) 'cancerType': _cancerType,
        if (stage != null) 'cancerStage': _stageLabels[stage!],
        if (treatment != null) 'currentTreatment': _treatmentLabels[treatment!],
      };

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        if (gender != null) 'gender': _genderLabels[gender!],
        if (religion != null) 'religion': _religionLabels[religion!],
        if (_dobEntered)
          'dateOfBirth':
              '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
        // Write each patientProfile field individually to avoid clobbering
        for (final entry in patientProfile.entries)
          'patientProfile.${entry.key}': entry.value,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updates);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(
        content: Text(context.t('quiz.errSave', {'error': '$e'})),
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F1EC),
      body: SafeArea(
        child: PageView(
          controller: _controller,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (i) {
            setState(() => currentPage = i);
          },
          children: [
            introPage(),
            dobQuiz(),
            genderQuiz(),
            interestQuiz(),
            moodQuiz(),
            religionQuiz(),
            medicalQuiz(),
          ],
        ),
      ),
    );
  }

  // Intro Page
  Widget introPage() {
    double radius = 300;

    return Stack(
      children: [
        //Background Image
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Image.asset(
            "assets/questions_cat.png",
            height: 650,
            fit: BoxFit.cover,
          ),
        ),

        // Bottom Curved Area
        Positioned(
          bottom: -660,
          left: -320,
          child: Container(
            width: radius * 3.6,
            height: radius * 3.6,
            decoration: const BoxDecoration(
              color: Color(0xffFFFFFF),
              shape: BoxShape.circle,
            ),
          ),
        ),

        // Text + Button
        Positioned(
          bottom: 70,
          left: 25,
          right: 20,
          child: Column(
            children: [
              // Step Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xffFFEBC2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  context.t('quiz.step1'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xffE1A707),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Main Text
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: context.t('quiz.introLine1'),
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff4B3425),
                      ),
                    ),
                    TextSpan(
                      text: "sharing",
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Color(0xffFFBD19),
                      ),
                    ),
                    TextSpan(
                      text: context.t('quiz.introLine2'),
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff4B3425),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Arrow Button
              GestureDetector(
                onTap: nextPage,
                child: Container(
                  width: 102,
                  height: 102,
                  decoration: const BoxDecoration(
                    color: Color(0xff4B3425),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Shared Quiz Container
  Widget quizContainer({required Widget child, required int index}) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.t('quiz.title'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff4B3425),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xffE8DDD9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  context.t('quiz.progress', {
                    'current': '${index + 1}',
                    'total': '6',
                  }),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff9B6F57),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Expanded(child: child),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: prevPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff4B3425),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 30,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, color: Colors.white, size: 35),
                      SizedBox(width: 15),
                      Text(
                        context.t('quiz.back'),
                        style: TextStyle(
                          fontSize: 25,
                          color: Color(0xffF7F4F2),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: index == 5
                      ? () => Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MoodSelectorScreen(),
                          ),
                          (route) => false,
                        )
                      : nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: index == 5
                        ? const Color(0xff7B6BA8)
                        : const Color(0xff4B3425),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 32,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        index == 5 ? context.t('quiz.finish') : context.t('quiz.next'),
                        style: const TextStyle(
                          fontSize: 25,
                          color: Color(0xffF7F4F2),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Icon(
                        index == 5 ? Icons.check : Icons.arrow_forward,
                        color: Colors.white,
                        size: 35,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 55),
        ],
      ),
    );
  }

  Widget dobQuiz() {
    return quizContainer(
      index: 0,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              context.t('quiz.dobTitle'),
              style: TextStyle(
                fontSize: 37,
                fontWeight: FontWeight.bold,
                color: Color(0xff4B3425),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              context.t('quiz.dobSubtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w500,
                color: Color(0xff6D6661),
              ),
            ),

            const SizedBox(height: 20),

            // Date Input Section
            Container(
              width: MediaQuery.of(context).size.width * 1,
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Day
                  Container(
                    width: 120,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(
                        color: const Color(0xffCCC4BE),
                        width: 5,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xffF4F1EC),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xff5530E8),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: TextField(
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 2,
                          decoration: const InputDecoration(
                            hintText: "DD",
                            counterText: "",
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(
                            fontSize: 35,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff4B3425),
                          ),
                          onChanged: (value) {
                            setState(() {
                              day = int.tryParse(value) ?? day;
                              _dobEntered = true;
                            });
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // MONTH
                  Container(
                    width: 120,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(
                        color: const Color(0xffCCC4BE),
                        width: 5,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xffF4F1EC),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xff5530E8),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: TextField(
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 2,
                          decoration: const InputDecoration(
                            hintText: "MM",
                            counterText: "",
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(
                            fontSize: 35,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff4B3425),
                          ),
                          onChanged: (value) {
                            setState(() {
                              month = int.tryParse(value) ?? month;
                              _dobEntered = true;
                            });
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // YEAR
                  Container(
                    width: 120,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(
                        color: const Color(0xffCCC4BE),
                        width: 5,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xffF4F1EC),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xff5530E8),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: TextField(
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          decoration: InputDecoration(
                            hintText: context.t('quiz.dobYearHint'),
                            counterText: "",
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(
                            fontSize: 35,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff4B3425),
                          ),
                          onChanged: (value) {
                            setState(() {
                              year = int.tryParse(value) ?? year;
                              _dobEntered = true;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 60),

            Text(
              context.t('quiz.dobCelebrate'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w500,
                color: Color(0xff6D6661),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Gender Quiz
  Widget genderQuiz() {
    return singleChoiceQuiz(
      1,
      context.t('quiz.genderTitle'),
      [
        context.t('quiz.genderMale'),
        context.t('quiz.genderFemale'),
        context.t('quiz.genderTrans'),
        context.t('quiz.preferNotSay'),
      ],
      gender,
      (v) => setState(() => gender = v),
      subtitle: context.t('quiz.genderSubtitle'),
    );
  }

  // Interest Quiz (Multi Select)
  Widget interestQuiz() {
    return multiChoiceQuiz(
      2,
      context.t('quiz.interestTitle'),
      [
        context.t('quiz.interestCalm'),
        context.t('quiz.interestEdu'),
        context.t('quiz.interestDoc'),
        context.t('quiz.interestScience'),
        context.t('quiz.interestMusic'),
      ],
      interests,
      (i) {
        setState(() {
          interests.contains(i) ? interests.remove(i) : interests.add(i);
        });
      },
      subtitle: context.t('quiz.interestSubtitle'),
    );
  }

  // Mood Quiz
  Widget moodQuiz() {
    return singleChoiceQuiz(
      3,
      context.t('quiz.moodTitle'),
      [
        context.t('quiz.moodHappy'),
        context.t('quiz.moodCalm'),
        context.t('quiz.moodSad'),
        context.t('quiz.moodWorried'),
      ],
      mood,
      (v) => setState(() => mood = v),
      subtitle: context.t('quiz.moodSubtitle'),
    );
  }

  // Religion Quiz
  Widget religionQuiz() {
    return singleChoiceQuiz(
      4,
      context.t('quiz.religionTitle'),
      [
        context.t('quiz.relChristian'),
        context.t('quiz.relMuslim'),
        context.t('quiz.relBuddhist'),
        context.t('quiz.relHindu'),
        context.t('quiz.relOther'),
        context.t('quiz.preferNotSay'),
      ],
      religion,
      (v) => setState(() => religion = v),
      subtitle: context.t('quiz.religionSubtitle'),
    );
  }

  // Stage Button Widget

  // Medical Quiz
  Widget medicalQuiz() {
    return quizContainer(
      index: 5,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title
            Text(
              context.t('quiz.healthTitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 35,
                fontWeight: FontWeight.bold,
                color: Color(0xff4B3425),
              ),
            ),

            const SizedBox(height: 15),

            // Subtitle
            Text(
              context.t('quiz.healthSubtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, color: Color(0xff6D6661)),
            ),

            const SizedBox(height: 30),

            // Type of Cancer Card
            _medicalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('quiz.cancerType'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff4B3425),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(
                        color: const Color(0xffCCC4BE), // Outer border color
                        width: 5, // Outer border width
                      ),
                    ),
                    child: Container(
                      width: 380,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xffF4F1EC),
                        borderRadius: BorderRadius.circular(
                          30,
                        ), // Inner border radius
                        border: Border.all(
                          color: const Color(0xff4B3425), // Inner border color
                          width: 1.5, // Inner border width
                        ),
                      ),
                      // User input test field
                      child: TextField(
                        style: const TextStyle(
                          fontSize: 25,
                          color: Color(0xff4B3425),
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: context.t('quiz.cancerTypeHint'),
                          hintStyle: const TextStyle(
                            fontSize:
                                22, // Hint text size (can be different from input)
                            color: Color(
                              0xff878E96,
                            ), // Hint text color (usually lighter)
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                        ),
                        onChanged: (value) => _cancerType = value.trim(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Stage Card
            _medicalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('quiz.stageTitle'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff4B3425),
                    ),
                  ),
                  const SizedBox(height: 15),

                  Column(
                    children: [
                      _sideRadioOption(0, context.t('quiz.stageEarly')),
                      const SizedBox(height: 10),
                      _sideRadioOption(1, context.t('quiz.stageAdvanced')),
                      const SizedBox(height: 10),
                      _sideRadioOption(2, context.t('quiz.stageRemission')),
                      const SizedBox(height: 10),
                      _sideRadioOption(3, context.t('quiz.stageNotSure')),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Treatment Card
            _medicalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Current treatment",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff4B3425),
                    ),
                  ),
                  const SizedBox(height: 15),

                  _radioOptionsList(
                    title: context.t('quiz.treatmentTitle'),
                    options: [
                      context.t('quiz.treatChemo'),
                      context.t('quiz.treatSurgery'),
                      context.t('quiz.treatRadiation'),
                      context.t('quiz.treatNone'),
                    ],
                    selectedValue: treatment,
                    onChanged: (value) {
                      setState(() {
                        treatment = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Medical Card Widget
  Widget _medicalCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sideRadioOption(int value, String label) {
    final isSelected = stage == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          stage = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff7B6BA8) : Colors.white,
          borderRadius: BorderRadius.circular(35),
          border: Border.all(
            color: isSelected
                ? const Color(0xff7B6BA8)
                : const Color(0xffCCC4BE),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w400,
                color: isSelected ? Colors.white : const Color(0xff4B3425),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : const Color(0xff4B3425),
                  width: 2.5,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // Radio option for cancer treatment quiz
  Widget _radioOptionsList({
    required String title,
    required List<String> options,
    required int? selectedValue,
    required Function(int) onChanged,
    String? subtitle,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Options Container
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: options.length,
            itemBuilder: (context, i) {
              final isSelected = selectedValue == i;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xff7B6BA8)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(35),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xff7B6BA8)
                            : const Color(0xffCCC4BE),
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              options[i],
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w400,
                                color: isSelected
                                    ? const Color(0xffFFFFFF)
                                    : const Color(0xff4B3425),
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xffFFFFFF)
                                    : const Color(0xff4B3425),
                                width: 3,
                              ),
                            ),
                            child: isSelected
                                ? Center(
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xffFFFFFF),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  // Multi Choice
  Widget multiChoiceQuiz(
    int index,
    String title,
    List<String> options,
    Set<int> selectedValues,
    Function(int) onChanged, {
    String? subtitle,
  }) {
    return quizContainer(
      index: index,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 35,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff4B3425),
                ),
              ),

              // Subtitle
              if (subtitle != null) ...[
                const SizedBox(height: 20),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                    color: Color(0xff6D6661),
                  ),
                ),
              ],

              const SizedBox(height: 60),

              // Options Container
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: options.length,
                  itemBuilder: (context, i) {
                    final isSelected = selectedValues.contains(i);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () => onChanged(i),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xff7B6BA8)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(35),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Text
                                Expanded(
                                  child: Text(
                                    options[i],
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w400,
                                      color: isSelected
                                          ? const Color(0xffFFFFFF)
                                          : const Color(0xff4B3425),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                // Multi Select Circle
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xffFFFFFF)
                                          : const Color(0xff4B3425),
                                      width: 3,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(0xffFFFFFF),
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // Single Choice
  Widget singleChoiceQuiz(
    int index,
    String title,
    List<String> options,
    int? groupValue,
    Function(int) onChanged, {
    String? subtitle,
  }) {
    return quizContainer(
      index: index,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Main question title
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 35,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff4B3425),
                ),
              ),

              // Optional subtitle (shown only if provided)
              if (subtitle != null) ...[
                const SizedBox(height: 20),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                    color: Color(0xff6D6661),
                  ),
                ),
              ],

              const SizedBox(height: 60),

              // Container to hold all option cards with max width constraint
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: options.length,
                  itemBuilder: (context, i) {
                    final isSelected = groupValue == i;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () => onChanged(i),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xff7B6BA8)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(35),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Option text on the left
                                Expanded(
                                  child: Text(
                                    options[i],
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w400,
                                      color: isSelected
                                          ? const Color(0xffFFFFFF)
                                          : const Color(0xff4B3425),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                // Custom radio button on the right
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xffFFFFFF)
                                          : const Color(0xff4B3425),
                                      width: 3,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(0xffFFFFFF),
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
