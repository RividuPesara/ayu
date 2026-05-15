import 'package:flutter/material.dart';
import 'histroyScreen.dart';
import 'chatbot_service.dart' as api;
import 'package:speech_to_text/speech_to_text.dart' as stt;

class Chatbot extends StatefulWidget {
  final api.ChatSession? existingSession;
  const Chatbot({super.key, this.existingSession});

  @override
  State<Chatbot> createState() => _ChatbotState();
}

class _ChatbotState extends State<Chatbot> {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  static const int _historyPageSize = 50;

  List<Map<String, dynamic>> messages = [];
  String? _sessionId;
  String? _nextHistoryCursor;
  bool _hasMoreHistory = false;

  bool isTyping = false;
  bool _isSending = false;
  bool _isLoadingHistory = false;
  bool _isLoadingOlder = false;

  // Voice Variables
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    scrollController.addListener(_onScroll);
    if (widget.existingSession != null) {
      _sessionId = widget.existingSession!.sessionId;
      _loadExistingMessages();
    }
  }

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);
    controller.dispose();
    scrollController.dispose();
    _speech.stop();
    _endCurrentSession();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingHistory || _isLoadingOlder || !_hasMoreHistory) {
      return;
    }
    if (!scrollController.hasClients) {
      return;
    }
    if (scrollController.position.pixels <= 100) {
      _loadOlderMessages();
    }
  }

  // Notify the backend when the user leaves so longTermSummary gets updated
  void _endCurrentSession() {
    if (_sessionId != null) {
      api.endSession(_sessionId!);
    }
  }

  Future<void> _loadExistingMessages() async {
    setState(() => _isLoadingHistory = true);
    try {
      final page = await api.fetchMessages(
        _sessionId!,
        limit: _historyPageSize,
      );
      if (!mounted) return;
      setState(() {
        messages = page.messages.map((m) => m.toLocalMessage()).toList();
        _nextHistoryCursor = page.nextCursor;
        _hasMoreHistory = page.hasMore;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
    } catch (e) {
      _showError('Could not load conversation history.');
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_sessionId == null || !_hasMoreHistory || _isLoadingOlder) {
      return;
    }

    setState(() => _isLoadingOlder = true);

    final previousOffset = scrollController.hasClients
        ? scrollController.offset
        : 0.0;
    final previousMaxExtent = scrollController.hasClients
        ? scrollController.position.maxScrollExtent
        : 0.0;

    try {
      final page = await api.fetchMessages(
        _sessionId!,
        limit: _historyPageSize,
        startAfter: _nextHistoryCursor,
      );

      if (!mounted) return;

      final older = page.messages.map((m) => m.toLocalMessage()).toList();
      if (older.isEmpty) {
        setState(() {
          _hasMoreHistory = false;
        });
        return;
      }

      setState(() {
        messages = [...older, ...messages];
        _nextHistoryCursor = page.nextCursor;
        _hasMoreHistory = page.hasMore;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!scrollController.hasClients) return;
        final newMaxExtent = scrollController.position.maxScrollExtent;
        final delta = newMaxExtent - previousMaxExtent;
        final targetOffset = previousOffset + delta;
        scrollController.jumpTo(
          targetOffset.clamp(0.0, scrollController.position.maxScrollExtent),
        );
      });
    } catch (_) {
      _showError('Could not load older messages.');
    } finally {
      if (mounted) {
        setState(() => _isLoadingOlder = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      messages.add({'isUser': true, 'message': text});
      _isSending = true;
      isTyping = false;
    });
    controller.clear();
    scrollToBottom();

    try {
      if (_sessionId == null) {
        final title = text.length > 60 ? '${text.substring(0, 57)}...' : text;
        _sessionId = await api.createSession(title);
      }

      // Add a streaming placeholder for Ayu's reply
      setState(() {
        messages.add({'isUser': false, 'message': '', 'isStreaming': true});
      });
      scrollToBottom();

      // Stream tokens from the backend
      await api.streamMessage(
        _sessionId!,
        text,
        onMeta: (_) {},
        onToken: (token) {
          if (!mounted) return;
          setState(() {
            final last = messages.last;
            messages[messages.length - 1] = {
              ...last,
              'message': (last['message'] as String) + token,
            };
          });
          scrollToBottom();
        },
      );

      // Mark streaming done
      if (mounted) {
        setState(() {
          messages[messages.length - 1] = {
            ...messages.last,
            'isStreaming': false,
          };
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        messages.add({
          'isUser': false,
          'message': 'Sorry, I could not get a response. Please try again.',
        });
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        scrollToBottom();
      }
    }
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

  void _startNewChat() {
    _endCurrentSession();
    setState(() {
      messages.clear();
      _sessionId = null;
      _nextHistoryCursor = null;
      _hasMoreHistory = false;
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final bool isUser = msg['isUser'] as bool;
    final bool isStreaming = msg['isStreaming'] as bool? ?? false;
    final String text = msg['message'] as String;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xff64548E) : const Color(0xffF4F7FD),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 18,
                ),
              ),
            ),
            if (isStreaming && !isUser) ...[
              const SizedBox(width: 4),
              const _BlinkingCursor(),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showSpinner =
        _isSending && !messages.any((m) => m['isStreaming'] == true);

    return Scaffold(
      backgroundColor: const Color(0xffF7F4F2),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: Color(0xffF7F4F2),
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: Color(0xff4B3425), width: 2.0),
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
                    'AI Helpers',
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

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _startNewChat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff64548E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      fixedSize: const Size(95, 54),
                    ),
                    child: const Text(
                      'Chat',
                      style: TextStyle(color: Colors.white, fontSize: 19),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffF4F7FD),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      fixedSize: const Size(110, 54),
                    ),
                    child: const Text(
                      'History',
                      style: TextStyle(color: Color(0xff3727AB), fontSize: 19),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            if (_isLoadingHistory)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (messages.isEmpty)
              Expanded(
                child: Center(
                  child: Image.asset('assets/logo.png', height: 120),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount:
                      messages.length +
                      (showSpinner ? 1 : 0) +
                      (_isLoadingOlder ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isLoadingOlder && index == 0) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2.0),
                        ),
                      );
                    }

                    final messageIndex = index - (_isLoadingOlder ? 1 : 0);
                    if (messageIndex == messages.length) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 12,
                          ),
                          child: _TypingIndicator(),
                        ),
                      );
                    }
                    return _buildMessage(messages[messageIndex]);
                  },
                ),
              ),

            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      enabled: !_isSending,
                      onChanged: (v) => setState(() => isTyping = v.isNotEmpty),
                      decoration: InputDecoration(
                        hintText: 'Ask me anything...',
                        hintStyle: const TextStyle(
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
                    onTap: _isSending
                        ? null
                        : isTyping
                        ? _sendMessage
                        : listen,
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: _isSending
                          ? Colors.grey
                          : const Color(0xff7B6BA8),
                      child: _isSending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
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

// Blinking cursor at the end of a streaming bubble
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: const Text(
        '\u258D',
        style: TextStyle(
          color: Color(0xff64548E),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Three dot typing indicator
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xffF4F7FD),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final opacity = ((_controller.value * 3 - i) % 1.0).clamp(
                0.2,
                1.0,
              );
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Opacity(
                  opacity: opacity,
                  child: const CircleAvatar(
                    radius: 5,
                    backgroundColor: Color(0xff64548E),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
