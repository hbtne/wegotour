// ...existing code...
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ...existing code...

class GeminiService {
  final String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  Future<String> sendMessage(String prompt) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('⚠️ GEMINI_API_KEY chưa được load từ .env');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates']?[0]?['content']?[0]?['text'] ??
          data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
          "Không có phản hồi từ Gemini.";
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  // --- Thêm các hàm xử lý ảnh và sendImageAndAsk ---
  Future<String> analyzeImageWithHuggingFace(File imageFile) async {
    final hfKey = dotenv.env['HUGGINGFACE_API_KEY'];
    if (hfKey == null || hfKey.isEmpty) {
      throw Exception('HUGGINGFACE_API_KEY không được cấu hình.');
    }

    final uri = Uri.parse('https://api-inference.huggingface.co/models/Salesforce/blip-image-captioning-base');
    final bytes = await imageFile.readAsBytes();

    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $hfKey',
        'Content-Type': 'application/octet-stream',
      },
      body: bytes,
    );

    if (resp.statusCode == 200) {
      final jsonResp = jsonDecode(resp.body);
      if (jsonResp is Map && jsonResp.containsKey('generated_text')) {
        return 'Caption: ${jsonResp['generated_text']}';
      }
      // HF sometimes returns a list
      if (jsonResp is List && jsonResp.isNotEmpty && jsonResp[0]['generated_text'] != null) {
        return 'Caption: ${jsonResp[0]['generated_text']}';
      }
      return 'Không có caption từ HuggingFace.';
    } else {
      throw Exception('HF HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  Future<String> analyzeImageWithVision(File imageFile) async {
    final visionKey = dotenv.env['VISION_API_KEY'] ?? dotenv.env['GEMINI_API_KEY'];
    if (visionKey == null || visionKey.isEmpty) {
      throw Exception('VISION_API_KEY/GEMINI_API_KEY chưa được load từ .env');
    }

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final uri = Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$visionKey');
    final body = jsonEncode({
      "requests": [
        {
          "image": {"content": base64Image},
          "features": [
            {"type": "LANDMARK_DETECTION", "maxResults": 5},
            {"type": "LABEL_DETECTION", "maxResults": 5}
          ]
        }
      ]
    });

    final resp = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body);
    if (resp.statusCode != 200) {
      throw Exception('Vision API HTTP ${resp.statusCode}: ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    final annotations =
        (data['responses'] != null && (data['responses'] as List).isNotEmpty) ? data['responses'][0] : null;
    if (annotations == null) return 'Không có thông tin địa điểm từ ảnh.';

    final landmarks = annotations['landmarkAnnotations'] as List<dynamic>? ?? [];
    final labels = annotations['labelAnnotations'] as List<dynamic>? ?? [];

    final sb = StringBuffer();
    if (landmarks.isNotEmpty) {
      sb.writeln('Detected landmarks:');
      for (var lm in landmarks) {
        final name = lm['description'] ?? 'Unknown';
        final score = (lm['score'] != null) ? (lm['score'] as num).toDouble() : null;
        sb.writeln('- $name${score != null ? ' (score: ${score.toStringAsFixed(2)})' : ''}');
      }
    }

    if (labels.isNotEmpty) {
      sb.writeln('Detected labels:');
      for (var lb in labels.take(5)) {
        final name = lb['description'] ?? 'Unknown';
        final score = (lb['score'] != null) ? (lb['score'] as num).toDouble() : null;
        sb.writeln('- $name${score != null ? ' (score: ${score.toStringAsFixed(2)})' : ''}');
      }
    }

    final result = sb.toString().trim();
    return result.isEmpty ? 'Không có thông tin từ ảnh.' : result;
  }

  /// Phân tích ảnh (HF ưu tiên, Vision fallback), ghép prompt và gọi Gemini.
  Future<String> sendImageAndAsk(File imageFile, String userQuestion) async {
    String analysis = '';
    final hfKey = dotenv.env['HUGGINGFACE_API_KEY'];
    final visionKey = dotenv.env['VISION_API_KEY'] ?? dotenv.env['GEMINI_API_KEY'];

    try {
      if (hfKey != null && hfKey.isNotEmpty) {
        analysis = await analyzeImageWithHuggingFace(imageFile);
      } else if (visionKey != null && visionKey.isNotEmpty) {
        analysis = await analyzeImageWithVision(imageFile);
      } else {
        throw Exception('Không có HUGGINGFACE_API_KEY hoặc VISION_API_KEY cấu hình.');
      }
    } catch (e) {
      // fallback: nếu HF lỗi và có Vision key thì thử Vision
      if ((hfKey != null && hfKey.isNotEmpty) && (visionKey != null && visionKey.isNotEmpty)) {
        try {
          analysis = await analyzeImageWithVision(imageFile);
        } catch (e2) {
          return '⚠️ Lỗi khi phân tích ảnh: $e | fallback lỗi: $e2';
        }
      } else {
        return '⚠️ Lỗi khi phân tích ảnh: $e';
      }
    }

    final combinedPrompt = StringBuffer();
    combinedPrompt.writeln('Bạn là một hướng dẫn viên du lịch chuyên nghiệp.');
    combinedPrompt.writeln('Người dùng gửi 1 ảnh. Kết quả phân tích tự động của ảnh:');
    combinedPrompt.writeln(analysis);
    combinedPrompt.writeln('');
    combinedPrompt.writeln('Câu hỏi của người dùng: $userQuestion');
    combinedPrompt.writeln(
        'Hãy trả lời chi tiết như hướng dẫn viên: nêu khả năng địa điểm, lịch sử ngắn, cách tới, điểm tham quan gần đó, và mức độ chắc chắn. Nếu không chắc chắn, gợi ý cách xác nhận.');

    try {
      final answer = await sendMessage(combinedPrompt.toString());
      return answer;
    } catch (e) {
      return '⚠️ Lỗi khi gọi Gemini: $e';
    }
  }
}
// ...existing code...