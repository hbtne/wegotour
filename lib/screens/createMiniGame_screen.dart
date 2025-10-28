import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateMinigameScreen extends StatefulWidget {
  final String? minigameId;
  final Map<String, dynamic>? existingData;

  const CreateMinigameScreen({super.key, this.minigameId, this.existingData});

  @override
  _CreateMinigameScreenState createState() => _CreateMinigameScreenState();
}

class _CreateMinigameScreenState extends State<CreateMinigameScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _gameNameController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(text: '10');
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  List<Map<String, dynamic>> _questions = [];
  int currentQuestionIndex = 0;

  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _optionsController = TextEditingController();
  final TextEditingController _correctAnswerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      final data = widget.existingData!;
      _gameNameController.text = data['title'];
      _discountController.text = data['discountPercent'].toString();
      _startDateController.text = _formatDate(data['startDate'].toDate());
      _endDateController.text = _formatDate(data['endDate'].toDate());
      _questions = List<Map<String, dynamic>>.from(data['questions']);
    }
    _loadQuestion(currentQuestionIndex);
  }

  void _loadQuestion(int index) {
    if (_questions.isEmpty || index >= _questions.length) {
      // Clear form nếu chưa có câu hỏi hoặc vượt quá
      _questionController.clear();
      _optionsController.clear();
      _correctAnswerController.clear();
    } else {
      final q = _questions[index];
      _questionController.text = q['questionText'];
      _optionsController.text = (q['options'] as List<dynamic>).join('\n');
      _correctAnswerController.text = q['correctOptionIndex'].toString();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _saveCurrentQuestion() {
    final questionText = _questionController.text.trim();
    final options = _optionsController.text.trim().split('\n').where((e) => e.isNotEmpty).toList();
    final correctIndex = int.tryParse(_correctAnswerController.text) ?? -1;

    if (questionText.isEmpty || options.isEmpty || correctIndex < 0 || correctIndex >= options.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin câu hỏi hợp lệ')),
      );
      return;
    }

    final questionData = {
      'questionText': questionText,
      'options': options,
      'correctOptionIndex': correctIndex,
    };

    if (currentQuestionIndex < _questions.length) {
      // Cập nhật câu hỏi hiện tại
      _questions[currentQuestionIndex] = questionData;
    } else {
      // Thêm câu hỏi mới
      _questions.add(questionData);
    }
  }

  void _nextQuestion() {
    _saveCurrentQuestion();

    if (currentQuestionIndex < _questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        _loadQuestion(currentQuestionIndex);
      });
    } else if (currentQuestionIndex == _questions.length - 1) {
      // Đang ở câu cuối, nút sẽ là "Thêm câu hỏi", bấm để tạo câu mới
      setState(() {
        currentQuestionIndex++;
        _loadQuestion(currentQuestionIndex);
      });
    }
  }

  void _previousQuestion() {
    if (currentQuestionIndex == 0) return;
    _saveCurrentQuestion();
    setState(() {
      currentQuestionIndex--;
      _loadQuestion(currentQuestionIndex);
    });
  }

  Future<void> _submitMinigame() async {
    _saveCurrentQuestion();

    if (_formKey.currentState!.validate() && _questions.isNotEmpty) {
      try {
        final startParts = _startDateController.text.split('/');
        final endParts = _endDateController.text.split('/');

        final startDate = DateTime(
          int.parse(startParts[2]),
          int.parse(startParts[1]),
          int.parse(startParts[0]),
        );

        final endDate = DateTime(
          int.parse(endParts[2]),
          int.parse(endParts[1]),
          int.parse(endParts[0]),
        );

        final data = {
          'title': _gameNameController.text,
          'startDate': Timestamp.fromDate(startDate),
          'endDate': Timestamp.fromDate(endDate),
          'discountPercent': int.parse(_discountController.text),
          'questions': _questions,
          'updatedAt': Timestamp.now(),
        };

        if (widget.minigameId == null) {
          await _firestore.collection('minigames').add({
            ...data,
            'createdAt': Timestamp.now(),
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tạo minigame thành công')),
          );
        } else {
          await _firestore.collection('minigames').doc(widget.minigameId).update(data);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cập nhật minigame thành công')),
          );
        }

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng thêm ít nhất 1 câu hỏi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastQuestion = currentQuestionIndex == _questions.length;
    final isFirstQuestion = currentQuestionIndex == 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        title: const Text(
          'TẠO MINIGAME',
          style: TextStyle(
            color: Color(0xFF3B6332),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF3B6332)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel("Tên minigame"),
              _buildInputField(_gameNameController, "Nhập tên minigame"),

              const SizedBox(height: 16),
              _buildLabel("Khuyến mãi (%)"),
              _buildInputField(
                _discountController,
                "Nhập phần trăm",
                inputType: TextInputType.number,
              ),

              const SizedBox(height: 16),
              _buildLabel("Thời gian"),
              Row(
                children: [
                  Expanded(
                    child: _buildDateField(
                      controller: _startDateController,
                      label: 'Ngày bắt đầu',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDateField(
                      controller: _endDateController,
                      label: 'Ngày kết thúc',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              Text(
                "Số lượng câu hỏi: ${_questions.length + (isLastQuestion ? 1 : 0)}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              _buildLabel("Câu hỏi (${currentQuestionIndex + 1})"),
              _buildInputField(_questionController, "Nhập câu hỏi"),

              const SizedBox(height: 16),
              _buildLabel("Các lựa chọn"),
              _buildInputField(
                _optionsController,
                "Mỗi lựa chọn 1 dòng",
                maxLines: 4,
                inputType: TextInputType.multiline,
              ),

              const SizedBox(height: 16),
              _buildLabel("Lựa chọn đúng (số thứ tự, bắt đầu từ 0)"),
              _buildInputField(
                _correctAnswerController,
                "Nhập số thứ tự",
                inputType: TextInputType.number,
              ),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: isFirstQuestion ? null : _previousQuestion,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF3B6332),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    child: const Text('Câu hỏi trước'),
                  ),
                  ElevatedButton(
                    onPressed: _nextQuestion,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF3B6332),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    child: Text(isLastQuestion ? 'Thêm câu hỏi' : 'Câu hỏi tiếp theo'),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _submitMinigame,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF3B6332),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  ),
                  child: const Text('Lưu Minigame'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
    );
  }

  Widget _buildInputField(
      TextEditingController controller,
      String hintText, {
        int maxLines = 1,
        TextInputType inputType = TextInputType.text,
      }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: inputType,
      decoration: InputDecoration(
        hintText: hintText,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Trường này không được để trống';
        }
        return null;
      },
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );

        if (pickedDate != null) {
          controller.text = _formatDate(pickedDate);
        }
      },
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Trường này không được để trống';
        }
        return null;
      },
    );
  }
}


