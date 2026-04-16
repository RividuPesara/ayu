import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/network/backend_connector.dart';

final BackendConnector _backend = BackendConnector.instance;

// Models
class ChatSession {
  final String sessionId;
  final String title;
  final String dominantEmotion;
  final int messageCount;
  final DateTime? lastMessageAt;

  ChatSession({
    required this.sessionId,
    required this.title,
    required this.dominantEmotion,
    required this.messageCount,
    required this.lastMessageAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      sessionId: json['session_id'] as String,
      title: json['title'] as String? ?? '',
      dominantEmotion: json['dominant_emotion'] as String? ?? '',
      messageCount: json['message_count'] as int? ?? 0,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'] as String)
          : null,
    );
  }
}

class ChatMessage {
  final String messageId;
  final String role;
  final String content;
  final DateTime? timestamp;

  ChatMessage({
    required this.messageId,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['message_id'] as String,
      role: json['role'] as String? ?? '',
      content: json['content'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }

  // Convert to the local map format used by the chat UI
  Map<String, dynamic> toLocalMessage() {
    return {
      'isUser': role == 'patient',
      'message': content,
      'messageId': messageId,
    };
  }
}

class ChatMessagePage {
  final List<ChatMessage> messages;
  final String? nextCursor;
  final bool hasMore;

  ChatMessagePage({
    required this.messages,
    required this.nextCursor,
    required this.hasMore,
  });
}

class SendMessageResult {
  final String response;
  final String sentiment;
  final String safetyFlag;
  final String pathTaken;
  final String messageId;

  SendMessageResult({
    required this.response,
    required this.sentiment,
    required this.safetyFlag,
    required this.pathTaken,
    required this.messageId,
  });

  factory SendMessageResult.fromJson(Map<String, dynamic> json) {
    return SendMessageResult(
      response: json['response'] as String? ?? '',
      sentiment: json['sentiment'] as String? ?? '',
      safetyFlag: json['safety_flag'] as String? ?? 'non_crisis',
      pathTaken: json['path_taken'] as String? ?? '',
      messageId: json['message_id'] as String? ?? '',
    );
  }
}

// Create a new session and return its id
Future<String> createSession(String title) async {
  final response = await _backend.post(
    '/chatbot/sessions',
    body: {'title': title},
  );

  if (response.statusCode == 201) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['session_id'] as String;
  }

  throw Exception(
    'Failed to create session: ${response.statusCode} ${response.body}',
  );
}

// Load all sessions for the history screen
Future<List<ChatSession>> fetchSessions() async {
  final response = await _backend.get('/chatbot/sessions');

  if (response.statusCode == 200) {
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => ChatSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  throw Exception('Failed to load sessions: ${response.statusCode}');
}

// Load one page of messages for an existing session
Future<ChatMessagePage> fetchMessages(
  String sessionId, {
  int limit = 50,
  String? startAfter,
}) async {
  final response = await _backend.get(
    '/chatbot/sessions/$sessionId/messages',
    queryParameters: {
      'limit': limit,
      if (startAfter != null && startAfter.isNotEmpty)
        'start_after': startAfter,
    },
  );

  if (response.statusCode == 200) {
    final list = jsonDecode(response.body) as List<dynamic>;
    final messages = list
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();

    final hasMore = messages.length == limit;
    final nextCursor = hasMore && messages.isNotEmpty
        ? messages.first.messageId
        : null;

    return ChatMessagePage(
      messages: messages,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  throw Exception('Failed to load messages: ${response.statusCode}');
}

// Send a message and get Ayu's response
Future<SendMessageResult> sendMessage(String sessionId, String content) async {
  final response = await _backend.post(
    '/chatbot/sessions/$sessionId/messages',
    body: {'content': content},
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return SendMessageResult.fromJson(data);
  }

  throw Exception(
    'Failed to send message: ${response.statusCode} ${response.body}',
  );
}

// Metadata sent as the first SSE event by the streaming endpoint
class StreamMeta {
  final String sentiment;
  final String safetyFlag;
  final String pathTaken;
  final List<String> sources;
  final String sessionId;
  final String messageId;

  StreamMeta({
    required this.sentiment,
    required this.safetyFlag,
    required this.pathTaken,
    required this.sources,
    required this.sessionId,
    required this.messageId,
  });

  factory StreamMeta.fromJson(Map<String, dynamic> json) {
    return StreamMeta(
      sentiment: json['sentiment'] as String? ?? '',
      safetyFlag: json['safety_flag'] as String? ?? 'non_crisis',
      pathTaken: json['path_taken'] as String? ?? '',
      sources:
          (json['sources'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      sessionId: json['session_id'] as String? ?? '',
      messageId: json['message_id'] as String? ?? '',
    );
  }
}

/// Stream Ayu's reply token by token
Future<void> streamMessage(
  String sessionId,
  String content, {
  required void Function(StreamMeta meta) onMeta,
  required void Function(String token) onToken,
}) async {
  final request = await _backend.request(
    'POST',
    '/chatbot/sessions/$sessionId/messages/stream',
    body: {'content': content},
  );

  final client = http.Client();
  try {
    final streamed = await client.send(request);
    if (streamed.statusCode != 200) {
      final body = await streamed.stream.bytesToString();
      throw Exception('Stream failed: ${streamed.statusCode} $body');
    }

    final lineStream = streamed.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lineStream) {
      if (!line.startsWith('data: ')) continue;
      final payload = line.substring(6);
      if (payload.isEmpty) continue;

      final Map<String, dynamic> parsed =
          jsonDecode(payload) as Map<String, dynamic>;
      final event = parsed['event'] as String?;

      if (event == 'meta') {
        onMeta(StreamMeta.fromJson(parsed));
      } else if (event == 'token') {
        onToken(parsed['text'] as String? ?? '');
      } else if (event == 'done') {
        break;
      }
    }
  } finally {
    client.close();
  }
}

// Signal the backend that the user left the session so longTermSummary gets updated
Future<void> endSession(String sessionId) async {
  try {
    await _backend.post('/chatbot/sessions/$sessionId/end');
  } catch (_) {}
}

// delete a single session by marking it archived on backend
Future<void> archiveSession(String sessionId) async {
  final response = await _backend.post('/chatbot/sessions/$sessionId/archive');
  if (response.statusCode != 200) {
    throw Exception('Failed to archive session: ${response.statusCode}');
  }
}

// delete all sessions for the current user by marking status as archived
Future<int> archiveAllSessions() async {
  final response = await _backend.post('/chatbot/sessions/archive-all');
  if (response.statusCode != 200) {
    throw Exception('Failed to archive all sessions: ${response.statusCode}');
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  return data['count'] as int? ?? 0;
}
