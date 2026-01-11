// ai_chat_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:stour/services/ai_service.dart';
import 'package:stour/screens/details.dart';
import 'package:stour/util/places.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final GeminiService _gemini = GeminiService();
  final ImagePicker _picker = ImagePicker();

  File? _pickedImage;
  bool _isLoading = false;

  // Prevent double analysis for same image paths
  final Set<String> _processingImagePaths = {};

  // Speech to text
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListening = false;
  double _soundLevel = 0.0;

  // Vision key / android info from .env (or set here)
  static final String _googleVisionApiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
  static final String _androidPackage = dotenv.env['ANDROID_PACKAGE'] ?? '';
  static final String _androidSha1 = dotenv.env['ANDROID_SHA1'] ?? '';

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (kDebugMode) print('Speech status: $status');
          if (status == 'notListening' || status == 'done') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (error) {
          if (kDebugMode) print('Speech error: $error');
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (kDebugMode) print('Init speech failed: $e');
      if (mounted) setState(() => _speechAvailable = false);
    }
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      await _initSpeech();
      if (!_speechAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Micro không khả dụng trên thiết bị này')),
          );
        }
        return;
      }
    }
    if (mounted) setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _controller.text = result.recognizedWords;
            _controller.selection = TextSelection.fromPosition(
                TextPosition(offset: _controller.text.length));
          });
        }
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 3),
      localeId: 'vi_VN',
      onSoundLevelChange: (level) {
        if (mounted) setState(() => _soundLevel = level);
      },
      cancelOnError: true,
    );
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
    } catch (e) {
      if (kDebugMode) print('Stop listening error: $e');
    } finally {
      if (mounted) setState(() => _isListening = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 75);
      if (picked != null) {
        if (mounted) setState(() => _pickedImage = File(picked.path));
      }
    } catch (e) {
      if (kDebugMode) print('Pick image failed: $e');
    }
  }

  // Remove diacritics (Vietnamese-friendly) to improve matching
  String _removeDiacritics(String str) {
    final withDia =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    final noDia =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    var s = str;
    for (var i = 0; i < withDia.length; i++) {
      s = s.replaceAll(withDia[i], noDia[i]);
      s = s.replaceAll(withDia[i].toUpperCase(), noDia[i].toUpperCase());
    }
    return s;
  }

  // Unicode-aware normalize: remove diacritics, remove punctuation (keep letters/numbers), collapse spaces
  String _normalize(String s) {
    var out = _removeDiacritics(s ?? '');
    out = out.toLowerCase();
    // remove punctuation but keep unicode letters/numbers and spaces
    out = out.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    return out;
  }

  // Levenshtein distance
  int _levenshtein(String a, String b) {
    final la = a.length;
    final lb = b.length;
    if (la == 0) return lb;
    if (lb == 0) return la;
    final dp = List.generate(la + 1, (_) => List<int>.filled(lb + 1, 0));
    for (var i = 0; i <= la; i++) dp[i][0] = i;
    for (var j = 0; j <= lb; j++) dp[0][j] = j;
    for (var i = 1; i <= la; i++) {
      for (var j = 1; j <= lb; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        dp[i][j] = [dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost]
            .reduce((v, e) => v < e ? v : e);
      }
    }
    return dp[la][lb];
  }

  double _similarity(String a, String b) {
    final na = a.trim();
    final nb = b.trim();
    if (na.isEmpty && nb.isEmpty) return 1.0;
    if (na.isEmpty || nb.isEmpty) return 0.0;
    final dist = _levenshtein(na, nb);
    final maxLen = na.length > nb.length ? na.length : nb.length;
    return 1.0 - (dist / maxLen);
  }

  // token-level similarity: for each token in candidate find best matching token in place name
  double _tokenOverlapScore(String cand, String place) {
    final candTokens = cand.split(' ').where((t) => t.length > 1).toList();
    final placeTokens = place.split(' ').where((t) => t.length > 1).toList();
    if (candTokens.isEmpty || placeTokens.isEmpty) return 0.0;

    int matched = 0;
    double sumBest = 0.0;
    for (final ct in candTokens) {
      double best = 0.0;
      for (final pt in placeTokens) {
        final sim = _similarity(ct, pt);
        best = sim > best ? sim : best;
        // fast substring match counts strongly
        if (pt.contains(ct) || ct.contains(pt)) {
          best = best < 0.9 ? 0.9 : best;
        }
      }
      if (best >= 0.7) matched++;
      sumBest += best;
    }

    final avgBest = sumBest / candTokens.length;
    final ratio = matched /
        (placeTokens.length > candTokens.length
            ? placeTokens.length
            : candTokens.length);
    // combine average best token similarity and matched token ratio
    return (avgBest * 0.6) + (ratio * 0.4);
  }

  // Find best matching Place using combined string + token heuristics
  Future<Place?> _findPlaceByCandidates(List<String> candidates) async {
    if (candidates.isEmpty) return null;
    final normCandidates = candidates.map((c) => _normalize(c)).toList();
    if (kDebugMode) print('Vision candidates normalized: $normCandidates');

    final coll = FirebaseFirestore.instance.collection('stourplace1');
    final snap = await coll.get();

    const double combinedThreshold = 0.75;
    Place? bestPlace;
    double bestScore = 0.0;

    if (kDebugMode) print('Comparing against ${snap.docs.length} place docs');

    for (final doc in snap.docs) {
      final data = doc.data();
      final rawName = (data['name'] ?? '').toString();
      if (rawName.isEmpty) continue;
      final nname = _normalize(rawName);

      if (kDebugMode)
        print('Comparing place: "$rawName" -> normalized: "$nname"');

      for (final cand in normCandidates) {
        if (cand.isEmpty) continue;
        final stringSim = _similarity(cand, nname); // whole-string similarity
        final tokenScore =
            _tokenOverlapScore(cand, nname); // token overlap heuristic
        // combined score: weight whole-string similarity more but token helps bilingual / partial matches
        final combined = (stringSim * 0.6) + (tokenScore * 0.4);

        if (kDebugMode) {
          print(
              '  candidate="$cand" vs name="$nname" => stringSim=${stringSim.toStringAsFixed(3)}, tokenScore=${tokenScore.toStringAsFixed(3)}, combined=${combined.toStringAsFixed(3)}');
        }

        // relax: accept single very-high token match even if combined slightly lower
        final containsRelax = cand.contains(nname) || nname.contains(cand);

        final accepted = combined >= combinedThreshold ||
            (combined >= 0.7 && containsRelax) ||
            tokenScore >= 0.85;

        if (accepted && combined > bestScore) {
          bestScore = combined;
          try {
            bestPlace = Place.fromDocument(doc);
          } catch (e) {
            if (kDebugMode) print('Place.fromDocument failed: $e');
            try {
              bestPlace = Place(
                id: data['id'] ?? doc.id,
                name: rawName,
                address: data['address'] ?? '',
                img: data['image'] ?? '',
                rating: data['rating']?.toString() ?? '0.0',
                price: data['price'] ?? 0,
                history: data['history'] ?? '',
                duration: data['duration'] ?? 0,
                city: data['city'] ?? '',
                district: data['district'] ?? '',
                openTime: data['opentime'] ?? 0,
                closeTime: data['closetime'] ?? 0,
                checkinCount: data['checkinCount'] ?? 0,
                reviewCount: data['reviewCount'] ?? 0,
                isAccepted: data['isAccepted'] ?? false,
              );
            } catch (_) {
              bestPlace = null;
            }
          }
          if (kDebugMode) {
            print(
                '  -> selected current best: "$rawName" with score=${bestScore.toStringAsFixed(3)}');
          }
        }
      }
    }

    if (kDebugMode) {
      if (bestPlace != null) {
        print(
            'Best matched place FINAL: ${bestPlace.name}, score=${bestScore.toStringAsFixed(3)}');
      } else {
        print('No matching place found for candidates.');
      }
    }
    return bestPlace;
  }

  Future<Map<String, dynamic>> _analyzeImageAndCandidates(File image) async {
    if (_googleVisionApiKey.trim().isEmpty) {
      if (kDebugMode) print('Vision API key not set. Skipping cloud analysis.');
      return {
        'summary': 'Google Vision API key not provided.',
        'candidates': <String>[]
      };
    }

    final bytes = await image.readAsBytes();
    const maxBytes = 4 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      if (kDebugMode) print('Image too large: ${bytes.length} bytes');
      return {'summary': 'Ảnh quá lớn.', 'candidates': <String>[]};
    }

    final base64Image = base64Encode(bytes);
    final uri = Uri.parse(
        'https://vision.googleapis.com/v1/images:annotate?key=$_googleVisionApiKey');

    final requestBody = {
      "requests": [
        {
          "image": {"content": base64Image},
          "features": [
            {"type": "LANDMARK_DETECTION", "maxResults": 5},
            {"type": "WEB_DETECTION", "maxResults": 5},
            {"type": "LABEL_DETECTION", "maxResults": 5},
            {"type": "LOGO_DETECTION", "maxResults": 5}
          ]
        }
      ]
    };

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_androidPackage.isNotEmpty)
      headers['X-Android-Package'] = _androidPackage;
    if (_androidSha1.isNotEmpty) headers['X-Android-Cert'] = _androidSha1;

    final resp =
        await http.post(uri, headers: headers, body: jsonEncode(requestBody));

    if (kDebugMode && resp.statusCode != 200) {
      try {
        if (resp.body.isNotEmpty)
          print('Vision API response body: ${resp.body}');
      } catch (_) {}
    }

    if (resp.statusCode != 200) {
      String message = 'Vision API error ${resp.statusCode}';
      try {
        final Map<String, dynamic> jb = jsonDecode(resp.body);
        if (jb['error'] != null) {
          message = jb['error']['message']?.toString() ?? resp.body.toString();
        }
      } catch (_) {}
      throw Exception('Vision API failed: $message');
    }

    final Map<String, dynamic> jsonResp = jsonDecode(resp.body);
    final annotations = jsonResp['responses']?[0] ?? {};

    final parts = <String>[];
    final candidates = <String>[];

    final landmark = annotations['landmarkAnnotations'] as List<dynamic>?;
    if (landmark != null && landmark.isNotEmpty) {
      final desc = (landmark[0]['description'] ?? '').toString();
      final score = (landmark[0]['score'] ?? 0).toString();
      parts.add('Landmark detected: $desc (confidence: $score)');
      if (desc.isNotEmpty) candidates.add(desc);
    }

    final web = annotations['webDetection'] as Map<String, dynamic>?;
    if (web != null) {
      final bestGuess = (web['bestGuessLabels'] as List<dynamic>?)
          ?.map((b) => b['label'])
          .whereType<String>()
          .toList();
      if (bestGuess != null && bestGuess.isNotEmpty) {
        parts.add('Best guess: ${bestGuess.join(', ')}');
        candidates.addAll(bestGuess);
      }
      final webEntities = (web['webEntities'] as List<dynamic>?)
          ?.map((e) => e['description'])
          .whereType<String>()
          .take(5)
          .toList();
      if (webEntities != null && webEntities.isNotEmpty) {
        parts.add('Web entities: ${webEntities.join(', ')}');
        candidates.addAll(webEntities);
      }
    }

    final labels = (annotations['labelAnnotations'] as List<dynamic>?)
        ?.map((l) =>
            '${l['description']} (${(l['score'] ?? 0).toStringAsFixed(2)})')
        .take(5)
        .toList();
    if (labels != null && labels.isNotEmpty) {
      parts.add('Labels: ${labels.join(', ')}');
      labels.forEach((l) {
        final plain = l.toString().split(' (').first;
        if (plain.isNotEmpty) candidates.add(plain);
      });
    }

    final logos = (annotations['logoAnnotations'] as List<dynamic>?)
        ?.map((l) => l['description'])
        .whereType<String>()
        .toList();
    if (logos != null && logos.isNotEmpty) {
      parts.add('Logos: ${logos.join(', ')}');
      candidates.addAll(logos);
    }

    final summary =
        parts.isEmpty ? 'No strong visual matches found.' : parts.join('. ');
    final uniqueCandidates = candidates
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();

    if (kDebugMode)
      print('Vision returned candidates (unique): $uniqueCandidates');
    return {'summary': summary, 'candidates': uniqueCandidates};
  }

  Future<void> _scrollToEnd(
      {Duration duration = const Duration(milliseconds: 300)}) async {
    if (!_scrollController.hasClients) return;
    try {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: duration,
        curve: Curves.easeOut,
      );
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _pickedImage == null) return;

    // Prevent re-entrancy: if we're already loading (text or image), do nothing
    if (_isLoading) return;

    if (text.isNotEmpty) {
      _messages.add({'role': 'user', 'content': text});
    }
    if (_pickedImage != null) {
      _messages.add(
          {'role': 'user', 'content': '[Image]', 'image': _pickedImage!.path});
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _controller.clear();
      });
    }

    // ensure UI updated and scrolled
    await Future.delayed(const Duration(milliseconds: 50));
    _scrollToEnd();

    try {
      String aiResponse = '';

      if (_pickedImage != null) {
        final imagePath = _pickedImage!.path;

        // If this image is already being processed, skip duplicate analysis
        if (_processingImagePaths.contains(imagePath)) {
          if (kDebugMode)
            print(
                'Image already processing: $imagePath — skipping duplicate call.');
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        // mark as processing
        _processingImagePaths.add(imagePath);

        String analysis = '';
        List<String> candidates = <String>[];
        try {
          final res = await _analyzeImageAndCandidates(_pickedImage!);
          analysis = res['summary'] ?? '';
          candidates = (res['candidates'] as List<dynamic>?)?.cast<String>() ??
              <String>[];
        } catch (e) {
          if (kDebugMode) print('Vision analysis failed: $e');
          analysis = 'Failed to analyze image via Vision API: $e';
        }

        // show candidates in messages for debug/visibility (only add once per image)
        final alreadyHasAnalysisMessage = _messages.any((m) =>
            m['role'] == 'system' &&
            (m['content'] ?? '').toString().startsWith('Image analysis:') &&
            m['imagePath'] == imagePath);

        // if (!alreadyHasAnalysisMessage) {
        //   _messages.add({'role': 'system', 'content': 'Image analysis: $analysis', 'imagePath': imagePath});
        // }
        // if (candidates.isNotEmpty) {
        //   final alreadyHasCandidatesMsg = _messages.any((m) =>
        //       m['role'] == 'system' &&
        //       (m['content'] ?? '').toString().startsWith('Candidates:') &&
        //       m['imagePath'] == imagePath);
        //   if (!alreadyHasCandidatesMsg) {
        //     _messages.add({'role': 'system', 'content': 'Candidates: ${candidates.join(', ')}', 'imagePath': imagePath});
        //   }
        // }

        Place? matchedPlace;
        try {
          matchedPlace = await _findPlaceByCandidates(candidates);
        } catch (e) {
          if (kDebugMode) print('Place lookup failed: $e');
        }

        if (matchedPlace != null) {
          if (kDebugMode)
            print('Matched place found in _send(): ${matchedPlace.name}');
          // add AI confirmation message and attach 'place' so UI shows button
          final aiMsg = {
            'role': 'ai',
            'content':
                'Mình đã nhận diện địa điểm "${matchedPlace.name}". Bạn muốn xem chi tiết chứ?',
            'place': matchedPlace,
            'imagePath': imagePath,
          };
          if (mounted) {
            setState(() {
              _messages.add(aiMsg);
              _pickedImage = null;
              _isLoading = false;
            });
          } else {
            _messages.add(aiMsg);
          }

          // remove processing mark
          _processingImagePaths.remove(imagePath);

          await Future.delayed(const Duration(milliseconds: 50));
          _scrollToEnd();
          return;
        }

        // No place match -> send analysis to model as system message and continue normal flow
        final sendMessages = _messages
            .map((m) => {
                  'role': m['role'] as String,
                  'content': (m['content'] ?? '').toString(),
                })
            .toList();

        // append analysis as system-level context
        sendMessages
            .add({'role': 'system', 'content': 'Image analysis: $analysis'});
        aiResponse = await _gemini.sendMessageWithHistory(sendMessages);

        if (mounted) {
          setState(() {
            _messages.add({'role': 'ai', 'content': aiResponse});
            _pickedImage = null;
            _isLoading = false;
          });
        } else {
          _messages.add({'role': 'ai', 'content': aiResponse});
        }

        // remove processing mark
        _processingImagePaths.remove(imagePath);

        await Future.delayed(const Duration(milliseconds: 50));
        _scrollToEnd();
        return;
      }

      // Normal text-only flow
      final sendMessages = _messages
          .map((m) => {
                'role': m['role'] as String,
                'content': (m['content'] ?? '').toString(),
              })
          .toList();

      aiResponse = await _gemini.sendMessageWithHistory(sendMessages);
      if (mounted) {
        setState(() {
          _messages.add({'role': 'ai', 'content': aiResponse});
        });
      } else {
        _messages.add({'role': 'ai', 'content': aiResponse});
      }
      await Future.delayed(const Duration(milliseconds: 50));
      _scrollToEnd();
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({'role': 'ai', 'content': '⚠️ Lỗi khi kết nối AI: $e'});
        });
      } else {
        _messages.add({'role': 'ai', 'content': '⚠️ Lỗi khi kết nối AI: $e'});
      }
      _scrollToEnd();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    final isUser = msg['role'] == 'user';
    final imagePath = msg['image'] as String?;
    final placeObj = msg['place'] as Place?;
    final content = (msg['content'] ?? '').toString();

    final mdStyle = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: const TextStyle(
        color: Colors.black87,
        fontSize: 14,
        height: 1.4,
      ),
      strong: const TextStyle(fontWeight: FontWeight.bold),
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFDFF7E8) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(imagePath)),
              ),
              if (content.isNotEmpty) const SizedBox(height: 8),
            ],
            if (content.isNotEmpty)
              MarkdownBody(
                data: content,
                styleSheet: mdStyle,
                selectable: false,
              ),
            if (placeObj != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailScreen(placeToDisplay: placeObj),
                      ),
                    );
                  }
                },
                child: const Text('Xem chi tiết',
                    style: TextStyle(color: Color(0xFF3B6332))),
              )
            ]
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    try {
      _speech.stop();
    } catch (_) {}
    try {
      _speech.cancel();
    } catch (_) {}
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black26,
      body: SafeArea(
        child: Center(
          child: Container(
            width: 440,
            height: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              children: [
                const Text(
                  'Wee AI',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B6332)),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildBubble(msg);
                    },
                  ),
                ),
                if (_pickedImage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_pickedImage!,
                              width: 80, height: 80, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                            child: Text('Ảnh đã chọn - sẵn sàng gửi')),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _pickedImage = null),
                        )
                      ],
                    ),
                  ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.photo, color: Color(0xFF3B6332)),
                      onPressed: _pickImage,
                    ),
                    IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color:
                            _isListening ? Colors.red : const Color(0xFF3B6332),
                      ),
                      onPressed: () async {
                        if (_isListening) {
                          await _stopListening();
                        } else {
                          await _startListening();
                        }
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send,
                                color: Color(0xFF3B6332)),
                            onPressed: _send,
                          ),
                  ],
                ),
                if (_isListening)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: LinearProgressIndicator(
                      value: (_soundLevel / 10).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[200],
                      color: Colors.redAccent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
