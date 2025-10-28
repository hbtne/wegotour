import 'package:flutter/material.dart';
import 'package:stour/screens/main_screen.dart';
import 'package:stour/util/question.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stour/util/const.dart';
import 'package:stour/util/coupon.dart';

class QuestionScreen extends StatefulWidget {
  final List<Question> listquestion;
  const QuestionScreen({super.key, required this.listquestion});

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  int questionNumber = 0;
  int correctAnswers = 0;
  int? selectedAnswerIndex;

  void checkAnswer(int selectedIndex) {
    setState(() {
      if (selectedIndex == widget.listquestion[questionNumber].correctAnswerIndex) {
        correctAnswers++;
      }

      if (questionNumber < widget.listquestion.length - 1) {
        questionNumber++;
        selectedAnswerIndex = null;
      } else {
        finished(correctAnswers);
      }
    });
  }

  void finished(int result) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _QuestionResult(
          result: result,
          totalQuestions: widget.listquestion.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = widget.listquestion[questionNumber];
    final count = questionNumber + 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Câu hỏi $count/${widget.listquestion.length}',
          style: TextStyle(
            color: Color(0xFF3B6332),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color.fromARGB(255, 35, 52, 10)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: SizedBox(
                width: double.maxFinite,
                height: 250,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  elevation: 3.0,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          currentQuestion.questionText,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 20, color: Color(0xFF3B6332)),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Hiển thị các lựa chọn
          ...currentQuestion.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ElevatedButton(
                onPressed: () {
                  if (selectedAnswerIndex == null) {
                    setState(() {
                      selectedAnswerIndex = index;
                    });
                    Future.delayed(const Duration(seconds: 1), () {
                      checkAnswer(index);
                    });
                  }
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (selectedAnswerIndex == index) {
                      return selectedAnswerIndex == currentQuestion.correctAnswerIndex
                          ? Color(0x503B6332)
                          : Colors.red;
                    }
                    return Color(0x50FFD166);
                  }),
                  minimumSize: WidgetStateProperty.all(const Size(double.infinity, 50)),
                ),
                child: Text(option, style: const TextStyle(fontSize: 15, color: Color(0xFF3B6332),))
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _QuestionResult extends StatelessWidget {
  final int result;
  final int totalQuestions;

  const _QuestionResult({
    required this.result,
    required this.totalQuestions,
  });

  @override
  Widget build(BuildContext context) {
    final successRate = (result / totalQuestions * 100).round();
    String resultText;

    if (successRate >= 80) {
      resultText = 'Xuất sắc! Bạn đã trả lời đúng $result/$totalQuestions câu. Bạn nhận được voucher của WeGo!';
    } else if (successRate >= 50) {
      resultText = 'Tốt! Bạn đã trả lời đúng $result/$totalQuestions câu. Bạn nhận được voucher của WeGo!!';
    } else {
      resultText = 'Tiếc quá! Bạn chỉ trả lời đúng $result/$totalQuestions câu. Cố gắng lần sau nhé!';
    }

    return Scaffold(
      appBar: AppBar(
        title:             Text('MINIGAMES', style: TextStyle(color: Color(0xFF3B6332), fontWeight: FontWeight.bold)),
        // backgroundColor: Constants.lightgreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color.fromARGB(255, 35, 52, 10)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('KẾT QUẢ', style: TextStyle(fontSize: 35, fontWeight: FontWeight.w600)),
            const SizedBox(height: 45),
            Text('$result/$totalQuestions câu đúng', style: const TextStyle(
              fontSize: 24,
              color: Color(0xFF3B6332),
              fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 20),
            Text(resultText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 40),
            if (successRate >= 50)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('MÃ VOUCHER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('WGGFGF${DateTime.now().millisecondsSinceEpoch.toString().substring(5, 10)}',
                          style: TextStyle(fontSize: 24, color: Color(0xFF3B6332))),
                      // Text('Giảm ${successRate >= 80 ? : },
                      //     style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MainScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0x80FFD166),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Trở về trang chủ',
                style: TextStyle(fontSize: 18,  color: Color(0xFF3B6332)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
