import 'package:flutter/material.dart';
import 'chatbotScreen.dart';
import 'chatbot_service.dart';
import 'package:mobile_app/core/localization/app_localizations.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ChatSession> _sessions = [];
  List<ChatSession> _filtered = [];

  bool _isLoading = true;
  bool _isSearching = false;

  final TextEditingController searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final sessions = await fetchSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _filtered = List.from(sessions);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('chatHist.errLoad')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _searchSessions(String query) {
    setState(() {
      _filtered = _sessions
          .where((s) => s.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      searchController.clear();
      _filtered = List.from(_sessions);
    });
  }

  void _deleteAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset("assets/delete.png", height: 400),
            const SizedBox(height: 15),
            Text(
              context.t('chatHist.deleteAll'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w500,
                color: Color(0xff4A3324),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xffCBC2FF),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.t('common.cancel'),
                    style: TextStyle(color: Color(0xff64548E), fontSize: 19),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.close, color: Color(0xff64548E), size: 24),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                try {
                  await archiveAllSessions();
                  if (!mounted) return;
                  setState(() {
                    _sessions.clear();
                    _filtered.clear();
                  });
                  Navigator.pop(context);
                } catch (_) {
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.t('chatHist.errDeleteAll')),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff64548E),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.t('common.delete'),
                    style: TextStyle(color: Colors.white, fontSize: 19),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.delete_outline_sharp,
                    color: Colors.white,
                    size: 24,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSession(ChatSession session) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Chatbot(existingSession: session)),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final hour = dt.hour > 12
        ? dt.hour - 12
        : dt.hour == 0
        ? 12
        : dt.hour;
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    final month = context.t('month.full.${dt.month}');
    return '${dt.day.toString().padLeft(2, '0')} $month ${dt.year} | '
        '${hour.toString().padLeft(2, '0')}:$minute $amPm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F4F2),
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

                  Expanded(
                    child: _isSearching
                        ? TextField(
                            controller: searchController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: context.t('chatHist.searchHint'),
                              hintStyle: TextStyle(fontSize: 22),
                              border: InputBorder.none,
                            ),
                            onChanged: _searchSessions,
                          )
                        : Text(
                            context.t('chat.history'),
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w600,
                              color: Color(0xff4B3425),
                            ),
                          ),
                  ),

                  GestureDetector(
                    onTap: _toggleSearch,
                    child: Icon(
                      _isSearching ? Icons.close : Icons.search,
                      size: 35,
                    ),
                  ),

                  const SizedBox(width: 15),

                  GestureDetector(
                    onTap: _deleteAll,
                    child: const Icon(Icons.delete_outline_sharp, size: 35),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset("assets/not_found.png", height: 120),
                        SizedBox(height: 50),
                        Text(
                          context.t('chatHist.notFound'),
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          context.t('chatHist.noMatch'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 21),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final session = _filtered[index];
                        return Dismissible(
                          key: Key(session.sessionId),
                          background: Container(
                            color: Color(0xffFF6666),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete_outline_sharp,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          confirmDismiss: (_) async {
                            final errorMessage =
                                context.t('chatHist.errDeleteOne');
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await archiveSession(session.sessionId);
                              return true;
                            } catch (_) {
                              if (!mounted) return false;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(errorMessage),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                              return false;
                            }
                          },
                          onDismissed: (_) {
                            setState(() {
                              _sessions.removeWhere(
                                (s) => s.sessionId == session.sessionId,
                              );
                              _filtered.removeWhere(
                                (s) => s.sessionId == session.sessionId,
                              );
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 5),
                                      Text(
                                        session.title,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        _formatDate(session.lastMessageAt),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Color(0xff6E6E6E),
                                        ),
                                      ),
                                      if (session
                                          .dominantEmotion
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          session.dominantEmotion,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xff64548E),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 5),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 15),
                                GestureDetector(
                                  onTap: () => _openSession(session),
                                  child: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
