import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mobile_app/dashboardScreen.dart';

class MoodSelectorScreen extends StatefulWidget {
  const MoodSelectorScreen({super.key});

  @override
  State<MoodSelectorScreen> createState() => _MoodSelectorScreenState();
}

class _MoodSelectorScreenState extends State<MoodSelectorScreen> {
  int selectedMoodIndex = 2;
  double pointerAngle = math.pi / 2;

  final List<_MoodData> moods = const [
    _MoodData(
      labelTop: 'VERY LOW',
      description: 'I feel very low.',
      faceType: MoodFaceType.verySad,
    ),
    _MoodData(
      labelTop: 'LOW',
      description: 'I feel sad.',
      faceType: MoodFaceType.sad,
    ),
    _MoodData(
      labelTop: 'NORMAL',
      description: 'I Feel Neutral.',
      faceType: MoodFaceType.neutral,
    ),
    _MoodData(
      labelTop: 'GOOD',
      description: 'I feel happy.',
      faceType: MoodFaceType.happy,
    ),
    _MoodData(
      labelTop: 'GREAT',
      description: 'I feel amazing.',
      faceType: MoodFaceType.veryHappy,
    ),
  ];

  void _updatePointerFromLocalPosition(
      Offset localPosition,
      Size size,
      double wheelHeight,
      ) {
    final double centerX = size.width / 2;
    final double centerY = size.height;

    final double dx = localPosition.dx - centerX;
    final double dy = centerY - localPosition.dy;

    double angle = math.atan2(dy, dx);
    angle = angle.clamp(0.0, math.pi);

    final double segmentSize = math.pi / 5;
    int index = ((math.pi - angle) / segmentSize).floor();
    index = index.clamp(0, 4);

    if (index == 0 || index == 4) {
      return;
    }

    setState(() {
      selectedMoodIndex = index;
      pointerAngle = angle;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mood = moods[selectedMoodIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F1EF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;
            final double screenHeight = constraints.maxHeight;

            final double wheelWidth = screenWidth;
            final double wheelHeight = screenWidth * 0.62;

            final double radius = wheelWidth / 2;
            final double centerX = wheelWidth / 2;
            final double centerY = wheelHeight;

            final double pointerDistanceFromCenter = radius - 26;

            final double pointerX =
                centerX + pointerDistanceFromCenter * math.cos(pointerAngle);
            final double pointerY =
                centerY - pointerDistanceFromCenter * math.sin(pointerAngle);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Mood Journal',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5A4032),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        mood.labelTop,
                        style: const TextStyle(
                          fontSize: 16,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFA17154),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: screenHeight * 0.05),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'How would you\ndescribe your mood?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      height: 1.25,
                      fontFamily: 'Urbanist',
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5A4032),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  mood.description,
                  style: const TextStyle(
                    fontSize: 26,
                    color: Color(0xFF7A675D),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 48),
                Transform.translate(
                  offset: const Offset(0, -18),
                  child: _CenterMoodFace(
                    key: ValueKey(selectedMoodIndex),
                    faceType: mood.faceType,
                    index: selectedMoodIndex,
                  ),
                ),
                const SizedBox(height: 8),
                Transform.translate(
                  offset: const Offset(0, -18),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 50,
                    color: Color(0xFFB4AAA4),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -10),
                  child: SizedBox(
                    width: 170,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => Dashboard()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4B3425),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        'Let’s Check In',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: wheelWidth,
                  height: wheelHeight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanDown: (details) {
                      _updatePointerFromLocalPosition(
                        details.localPosition,
                        Size(wheelWidth, wheelHeight),
                        wheelHeight,
                      );
                    },
                    onPanUpdate: (details) {
                      _updatePointerFromLocalPosition(
                        details.localPosition,
                        Size(wheelWidth, wheelHeight),
                        wheelHeight,
                      );
                    },
                    onTapDown: (details) {
                      _updatePointerFromLocalPosition(
                        details.localPosition,
                        Size(wheelWidth, wheelHeight),
                        wheelHeight,
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            'assets/moodselector.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _InnerArcPainter(),
                          ),
                        ),
                        Positioned(
                          left: pointerX - 20,
                          top: pointerY - 20,
                          child: _MoodOrb(index: selectedMoodIndex),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CenterMoodFace extends StatelessWidget {
  final MoodFaceType faceType;
  final int index;

  const _CenterMoodFace({
    super.key,
    required this.faceType,
    required this.index,
  });

  Color _getColor() {
    switch (index) {
      case 1:
        return const Color(0xFFFFB36A);
      case 2:
        return const Color(0xFFD7B8A8);
      case 3:
        return const Color(0xFFB8D37A);
      default:
        return const Color(0xFFD7B8A8);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      height: 170,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getColor(),
      ),
      child: CustomPaint(
        painter: _FacePainter(faceType),
      ),
    );
  }
}

class _MoodOrb extends StatefulWidget {
  final int index;

  const _MoodOrb({required this.index});

  @override
  State<_MoodOrb> createState() => _MoodOrbState();
}

class _MoodOrbState extends State<_MoodOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _glowAnimation = Tween<double>(
      begin: 18,
      end: 26,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  List<Color> _getGradient() {
    switch (widget.index) {
      case 0:
        return const [Color(0xFFFF8A5B), Color(0xFFF26A3D)];
      case 1:
        return const [Color(0xFFFFB36A), Color(0xFFFF8A4C)];
      case 2:
        return const [Color(0xFFD7B8A8), Color(0xFFC79D86)];
      case 3:
        return const [Color(0xFFB8D37A), Color(0xFF99BF59)];
      case 4:
        return const [Color(0xFFB99AF5), Color(0xFF9B79E8)];
      default:
        return const [Color(0xFFD7B8A8), Color(0xFFC79D86)];
    }
  }

  Color _getGlow() {
    switch (widget.index) {
      case 0:
        return const Color(0x66FF7A45);
      case 1:
        return const Color(0x66FFA154);
      case 2:
        return const Color(0x66C79D86);
      case 3:
        return const Color(0x669BBC5E);
      case 4:
        return const Color(0x669B79E8);
      default:
        return const Color(0x66C79D86);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = _getGlow();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _getGradient(),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.9),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor,
                  blurRadius: _glowAnimation.value,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InnerArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height),
      radius: size.width / 2 - 8,
    );

    final paint = Paint()
      ..color = const Color(0x665A4032)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      math.pi,
      -math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum MoodFaceType {
  verySad,
  sad,
  neutral,
  happy,
  veryHappy,
}

class _FacePainter extends CustomPainter {
  final MoodFaceType type;

  _FacePainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF5A4032)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    switch (type) {
      case MoodFaceType.verySad:
        canvas.drawLine(
          Offset(size.width * 0.30, size.height * 0.36),
          Offset(size.width * 0.38, size.height * 0.30),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.62, size.height * 0.30),
          Offset(size.width * 0.70, size.height * 0.36),
          paint,
        );

        final sadRect = Rect.fromCenter(
          center: Offset(size.width / 2, size.height * 0.70),
          width: 36,
          height: 18,
        );
        canvas.drawArc(sadRect, math.pi, math.pi, false, paint);
        break;

      case MoodFaceType.sad:
        canvas.drawLine(
          Offset(size.width * 0.30, size.height * 0.34),
          Offset(size.width * 0.39, size.height * 0.30),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.61, size.height * 0.30),
          Offset(size.width * 0.70, size.height * 0.34),
          paint,
        );

        final sadRect = Rect.fromCenter(
          center: Offset(size.width / 2, size.height * 0.69),
          width: 40,
          height: 18,
        );
        canvas.drawArc(sadRect, math.pi, math.pi, false, paint);
        break;

      case MoodFaceType.neutral:
        canvas.drawLine(
          Offset(size.width * 0.34, size.height * 0.30),
          Offset(size.width * 0.34, size.height * 0.40),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.66, size.height * 0.30),
          Offset(size.width * 0.66, size.height * 0.40),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.36, size.height * 0.64),
          Offset(size.width * 0.64, size.height * 0.64),
          paint,
        );
        break;

      case MoodFaceType.happy:
        final leftEyeRect = Rect.fromCenter(
          center: Offset(size.width * 0.34, size.height * 0.34),
          width: 18,
          height: 10,
        );
        final rightEyeRect = Rect.fromCenter(
          center: Offset(size.width * 0.66, size.height * 0.34),
          width: 18,
          height: 10,
        );

        canvas.drawArc(leftEyeRect, 0, math.pi, false, paint);
        canvas.drawArc(rightEyeRect, 0, math.pi, false, paint);

        final smileRect = Rect.fromCenter(
          center: Offset(size.width / 2, size.height * 0.58),
          width: 42,
          height: 28,
        );
        canvas.drawArc(smileRect, 0, math.pi, false, paint);
        break;

      case MoodFaceType.veryHappy:
        final leftEyeRect = Rect.fromCircle(
          center: Offset(size.width * 0.34, size.height * 0.34),
          radius: 6,
        );
        final rightEyeRect = Rect.fromCircle(
          center: Offset(size.width * 0.66, size.height * 0.34),
          radius: 6,
        );

        canvas.drawArc(leftEyeRect, 0, math.pi, false, paint);
        canvas.drawArc(rightEyeRect, 0, math.pi, false, paint);

        final bigSmileRect = Rect.fromCenter(
          center: Offset(size.width / 2, size.height * 0.58),
          width: 42,
          height: 30,
        );
        canvas.drawArc(bigSmileRect, 0, math.pi, false, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _FacePainter oldDelegate) {
    return oldDelegate.type != type;
  }
}

class _MoodData {
  final String labelTop;
  final String description;
  final MoodFaceType faceType;

  const _MoodData({
    required this.labelTop,
    required this.description,
    required this.faceType,
  });
}