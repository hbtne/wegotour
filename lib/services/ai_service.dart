// ...existing code...
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
// ...existing code...

class GeminiService {
  final String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  // ...existing sendMessage...

  // New: send message with conversation history (history: list of {role: 'user'|'ai', content: '...'})
  Future<String> sendMessageWithHistory(List<Map<String, String>> history) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('⚠️ GEMINI_API_KEY chưa được load từ .env');
    }

    // Build a single textual prompt from history. You can refine formatting as needed.
    final sb = StringBuffer();
    sb.writeln('Bạn là một trợ lý du lịch. Trả lời dựa trên ngữ cảnh sau:');
    for (var msg in history) {
      final role = msg['role'] ?? 'user';
      final content = msg['content'] ?? '';
      if (role == 'user') {
        sb.writeln('User: $content');
      } else {
        sb.writeln('Assistant: $content');
      }
    }
    sb.writeln('Assistant:'); // signal AI to respond

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': sb.toString()}
          ]
        }
      ]
    });

    final uri = Uri.parse('$_baseUrl?key=$apiKey');
    final response = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Try multiple possible paths in response
      final text = data['candidates']?[0]?['content']?[0]?['text'] ??
          data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      return text ?? 'Không có phản hồi từ Gemini.';
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }
}
// ...existing code...