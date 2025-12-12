import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VisionApiService {
  static String get apiKey => dotenv.env['GOOGLE_API_KEY'] ?? '';

  /// Validate ảnh có chứa keywords không
  ///
  /// Returns:
  /// - `isValid`: true nếu ảnh hợp lệ
  /// - `detectedLabels`: Danh sách labels phát hiện được
  /// - `matchedKeywords`: Keywords nào được tìm thấy
  static Future<Map<String, dynamic>> validateImage({
    required File imageFile,
    required List<String> requiredKeywords,
    double minConfidence = 0.7, // Độ tin cậy tối thiểu
  }) async {
    try {
      // 1. Convert image sang base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // 2. Gọi Google Vision API
      final url = Uri.parse(
        'https://vision.googleapis.com/v1/images:annotate?key=$apiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [
                {'type': 'LABEL_DETECTION', 'maxResults': 20},
                {'type': 'WEB_DETECTION', 'maxResults': 10},
              ],
            }
          ]
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Vision API error: ${response.statusCode}');
      }

      final result = jsonDecode(response.body);
      final annotations = result['responses'][0];

      // 3. Lấy labels
      final List<dynamic> labelAnnotations =
          annotations['labelAnnotations'] ?? [];
      final List<dynamic> webEntities =
          annotations['webDetection']?['webEntities'] ?? [];

      // Merge labels từ cả 2 nguồn
      final Set<String> allLabels = {};

      for (var label in labelAnnotations) {
        final description = (label['description'] as String).toLowerCase();
        final score = label['score'] as double;
        if (score >= minConfidence) {
          allLabels.add(description);
        }
      }

      for (var entity in webEntities) {
        if (entity['description'] != null) {
          final description = (entity['description'] as String).toLowerCase();
          allLabels.add(description);
        }
      }

      // 4. Check keywords match
      final List<String> matchedKeywords = [];

      for (final keyword in requiredKeywords) {
        final normalizedKeyword = _normalizeVietnamese(keyword.toLowerCase());

        // Check exact match hoặc partial match
        for (final label in allLabels) {
          final normalizedLabel = _normalizeVietnamese(label);

          if (normalizedLabel.contains(normalizedKeyword) ||
              normalizedKeyword.contains(normalizedLabel)) {
            matchedKeywords.add(keyword);
            break;
          }
        }
      }

      final isValid = matchedKeywords.isNotEmpty;

      return {
        'isValid': isValid,
        'detectedLabels': allLabels.toList(),
        'matchedKeywords': matchedKeywords,
        'totalLabels': allLabels.length,
        'message': isValid
            ? 'Ảnh hợp lệ! Tìm thấy: ${matchedKeywords.join(", ")}'
            : 'Ảnh không chứa từ khóa yêu cầu: ${requiredKeywords.join(", ")}',
      };
    } catch (e) {
      // Fallback: Nếu lỗi API, cho phép đăng nhưng đánh dấu pending review
      print('Vision API Error: $e');
      return {
        'isValid': true, // Tạm chấp nhận
        'detectedLabels': <String>[],
        'matchedKeywords': <String>[],
        'requiresReview': true,
        'message': 'Không thể xác minh ảnh. Bài đăng đang chờ duyệt.',
      };
    }
  }

  /// Normalize Vietnamese text (xóa dấu để so sánh dễ hơn)
  static String _normalizeVietnamese(String text) {
    const vietnamese =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const normalized =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

    String result = text.toLowerCase();
    for (int i = 0; i < vietnamese.length; i++) {
      result = result.replaceAll(vietnamese[i], normalized[i]);
    }
    return result;
  }

  /// Quick test function
  static Future<void> testVisionApi(File imageFile) async {
    print('🔍 Testing Vision API...');
    final result = await validateImage(
      imageFile: imageFile,
      requiredKeywords: ['bánh mì', 'bread', 'food'],
    );
    print('✅ Result: $result');
  }
}
