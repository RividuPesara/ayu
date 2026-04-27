import 'package:flutter/material.dart';
import '../Mood Journal/moodSelectorScreen.dart';

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

  void nextPage() {
    if (currentPage < 6) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
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
                child: const Text(
                  "STEP 1",
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
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: "Curious about you... mind\n",
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
                      text: " a few things?",
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
              )
            ],
          ),
        ),
      ],
    );
  }

  // Shared Quiz Container
  Widget quizContainer({
    required Widget child,
    required int index,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Quiz Time",
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
                  "${index + 1} of 6",
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 35,
                      ),
                      SizedBox(width: 15),
                      Text(
                        "Back",
                        style: TextStyle(
                          fontSize: 25,
                          color: Color(0xffF7F4F2),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (currentPage == 6) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MoodSelectorScreen(),
                        ),
                      );
                    } else {
                      nextPage();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentPage == 6
                        ? const Color(0xff4B3425) // Complete button color
                        : const Color(0xff4B3425), // Next button color

                    foregroundColor: Colors.white,

                    padding: currentPage == 6
                        ? const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 20,
                    ) // Complete button padding
                        : const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 30,
                    ), // Next button padding

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        currentPage == 6 ? 30 : 30,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentPage == 6 ? "Complete" : "Next",
                        style: const TextStyle(
                          fontSize: 25,
                          color: Color(0xffF7F4F2),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Icon(
                        currentPage == 6
                            ? Icons.check_circle
                            : Icons.arrow_forward,
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
            const Text(
              "When were you born?",
              style: TextStyle(
                fontSize: 37,
                fontWeight: FontWeight.bold,
                color: Color(0xff4B3425),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "We'd love to celebrate\nyour birthday!",
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
                          decoration: const InputDecoration(
                            hintText: "YYYY",
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

            const Text(
              "We'll celebrate with you!",
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
      "How do you describe yourself?",
      ["Male", "Female", "Transgender", "Prefer not to say"],
      gender,
          (v) => setState(() => gender = v),
      subtitle: "Tell us a bit about you",
    );
  }

  // Interest Quiz (Multi Select)
  Widget interestQuiz() {
    return multiChoiceQuiz(
      2,
      "What kind of stories do you like?",
      [
        "Calm & peaceful",
        "Educational",
        "Documentary",
        "Science",
        "Songs & music",
      ],
      interests,
          (i) {
        setState(() {
          interests.contains(i)
              ? interests.remove(i)
              : interests.add(i);
        });
      },
      subtitle: "Pick what sounds fun to you!\n(You can choose more than one)",
    );
  }

  // Mood Quiz
  Widget moodQuiz() {
    return singleChoiceQuiz(
      3,
      "How are you feeling right now?",
      [
        "Happy & excited",
        "Calm & okay",
        "A little sad",
        "Worried or scared"
      ],
      mood,
          (v) => setState(() => mood = v),
      subtitle: "There's no wrong answer.\nJust tell us honestly",
    );
  }

// Religion Quiz
  Widget religionQuiz() {
    return singleChoiceQuiz(
      4,
      "Do you have a faith or belief?",
      [
        "Christian",
        "Muslim",
        "Buddhist",
        "Hindu",
        "Other",
        "Prefer not to say"
      ],
      religion,
          (v) => setState(() => religion = v),
      subtitle: "Totally optional.\nThis helps us customize your journey",
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
            const Text(
              "Your health journey",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 35,
                fontWeight: FontWeight.bold,
                color: Color(0xff4B3425),
              ),
            ),

            const SizedBox(height: 15),

            // Subtitle
            const Text(
              "Tell us about your health (all optional)",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                color: Color(0xff6D6661),
              ),
            ),

            const SizedBox(height: 30),

            // Type of Cancer Card
            _medicalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Type of cancer",
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
                        color: const Color(0xffCCC4BE),  // Outer border color
                        width: 5,  // Outer border width
                      ),
                    ),
                    child: Container(
                      width: 380,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xffF4F1EC),
                        borderRadius: BorderRadius.circular(30),  // Inner border radius
                        border: Border.all(
                          color: const Color(0xff4B3425),  // Inner border color
                          width: 1.5,  // Inner border width
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
                          hintText: "e.g., Leukemia, Lymphoma, etc.",
                          hintStyle: const TextStyle(
                            fontSize: 22,  // Hint text size (can be different from input)
                            color: Color(0xff878E96),  // Hint text color (usually lighter)
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                        ),
                      ),
                    ),)
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Stage Card
            _medicalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "What stage are you in?",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff4B3425),
                    ),
                  ),
                  const SizedBox(height: 15),

                  Column(
                    children: [
                      _sideRadioOption(0, "Early"),
                      const SizedBox(height: 10),
                      _sideRadioOption(1, "Advanced"),
                      const SizedBox(height: 10),
                      _sideRadioOption(2, "In remission"),
                      const SizedBox(height: 10),
                      _sideRadioOption(3, "Not sure"),
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
                    title: "Current treatment",
                    options: [
                      "Chemotherapy",
                      "Surgery",
                      "Radiation",
                      "None right now"
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
            color: isSelected ? const Color(0xff7B6BA8) : const Color(0xffCCC4BE),
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
                      color: isSelected ? const Color(0xff7B6BA8) : Colors.white,
                      borderRadius: BorderRadius.circular(35),
                      border: Border.all(
                        color: isSelected ? const Color(0xff7B6BA8) : const Color(0xffCCC4BE),
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