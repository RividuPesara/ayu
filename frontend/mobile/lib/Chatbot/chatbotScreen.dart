import 'package:flutter/material.dart';
import 'histroyScreen.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:mobile_app/dashboardScreen.dart';

class Chatbot extends StatefulWidget {
  final List<Map<String, dynamic>>? previousMessages;

  const Chatbot({super.key, this.previousMessages});

  @override
  State<Chatbot> createState() => _ChatbotState();
}

class _ChatbotState extends State<Chatbot> {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();

  List<Map<String, dynamic>> messages = [];

  bool isTyping = false;

  // Voice Variables
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    // Load Previous Messages (History)
    if (widget.previousMessages != null) {
      messages = List.from(widget.previousMessages!);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToBottom();
      });
    }
  }

  void sendMessage() {
    if (controller.text.trim().isEmpty) return;

    setState(() {
      messages.add({
        "isUser": true,
        "message": controller.text,
      });
    });

    String userMessage = controller.text;

    controller.clear();
    isTyping = false;

    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        messages.add({
          "isUser": false,
          "message": "This is an AI response",
        });
      });

      scrollToBottom();
    });

    scrollToBottom();
  }

  void scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Voice to Text Function
  void listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();

      if (available) {
        setState(() => _isListening = true);

        _speech.listen(
          onResult: (result) {
            setState(() {
              controller.text = result.recognizedWords;
              isTyping = controller.text.isNotEmpty;
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Widget buildMessage(Map<String, dynamic> msg) {
    bool isUser = msg["isUser"];

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xff64548E)
              : const Color(0xffF4F7FD),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          msg["message"],
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 19,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffF7F4F2),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Dashboard(),
                        ),
                      );
                    },
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
                  const SizedBox(width: 12),
                  const Text(
                    "AI Helpers",
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff4B3425),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 38),

            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        messages.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff64548E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      fixedSize: const Size(90, 54),
                    ),
                    child: Text(
                      "Chat",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HistoryScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffF4F7FD),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      fixedSize: const Size(110, 54),
                    ),
                    child: Text(
                      "History",
                      style: TextStyle(
                        color: Color(0xff3727AB),
                        fontSize: 19,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Logo
            if (messages.isEmpty)
              Expanded(
                child: Center(
                  child: Image.asset(
                    "assets/logo.png",
                    height: 120,
                  ),
                ),
              ),

            // Messages
            if (messages.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return buildMessage(messages[index]);
                  },
                ),
              ),

            // Input
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      onChanged: (value) {
                        setState(() {
                          isTyping = value.isNotEmpty;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Ask me anything...",
                        hintStyle: TextStyle(
                          color: Color(0xffB8B8B8),
                          fontSize: 19,
                        ),
                        filled: true,
                        fillColor: Color(0xffFFFFFF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(17),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  GestureDetector(
                    onTap: isTyping ? sendMessage : listen,
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xff7B6BA8),
                      child: Icon(
                        isTyping
                            ? Icons.arrow_upward
                            : _isListening
                            ? Icons.mic
                            : Icons.mic_none,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 35),
          ],
        ),
      ),
    );
  }
}