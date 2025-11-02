import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreateEventScreen extends StatefulWidget {
  final String? groupId;
  const CreateEventScreen({super.key, this.groupId});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {

  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  List<Map<String, dynamic>> members = [];

  final Color primary = const Color(0xFF4A5C3B);
  final Color inputColor = const Color(0xFFFBE6A1);

  @override
  void dispose() {
    _titleCtrl.dispose();
    _destinationCtrl.dispose();
    _placeCtrl.dispose();
    _descriptionCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startDate = picked;
        else _endDate = picked;
      });
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startTime = picked;
        else _endTime = picked;
      });
    }
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    final startDate = DateFormat('dd/MM/yyyy').format(_startDate!);
    final startTime = _startTime?.format(context);
    final endDate = DateFormat('dd/MM/yyyy').format(_endDate!);
    final endTime = _endTime?.format(context);

    final newEvent = {
      "groupId": widget.groupId,
      "title": _titleCtrl.text.trim(),
      "destination": _destinationCtrl.text.trim(),
      "place": _placeCtrl.text.trim(),
      "description": _descriptionCtrl.text.trim(),
      "note": _noteCtrl.text.trim(),
      "startDate": startDate,
      "endDate": startTime,
      "startTime": endDate,
      "endTime": endTime,
      "joined": members,
      "createdBy": {
        "id": user?.uid,
        "name": user?.displayName ?? "Người dùng",
        "avatarUrl": user?.photoURL ??
            "https://cdn-icons-png.flaticon.com/512/847/847969.png",
      },
      "createdAt": FieldValue.serverTimestamp(),
    };

    final doc = await FirebaseFirestore.instance.collection("events").add(newEvent);

    await FirebaseFirestore.instance.collection("groups").doc(widget.groupId).update({
      'events': FieldValue.arrayUnion([{
      'id': doc.id,
        'title':_titleCtrl.text.trim(),
        'place': _placeCtrl.text.trim(),
        'time': _formatTimeRange(startDate, startTime, endDate, endTime)
      }])
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã tạo sự kiện thành công!")),
      );
      Navigator.pop(context);
    }
  }

  String _formatTimeRange(String? startDate, String? startTime, String? endDate, String? endTime) {
    if (startDate == null || startTime == null || endDate == null || endTime == null) return '';

    // Parse ngày để format lại thành dd/MM/yyyy
    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      final startStr = '${startTime.replaceAll(':', 'h ')}${DateFormat('dd/MM/yyyy').format(start)}';
      final endStr = '${endTime.replaceAll(':', 'h ')}${DateFormat('dd/MM/yyyy').format(end)}';
      return '$startStr - $endStr';
    } catch (e) {
      return '$startTime $startDate - $endTime $endDate';
    }
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: primary, fontSize: 16)),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            validator: (v) =>
            (v == null || v.isEmpty) ? "Vui lòng nhập $label" : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: inputColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Header
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF4A5C3B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          "TẠO SỰ KIỆN",
                          style: TextStyle(
                              color: Color(0xFF4A5C3B),
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 12),

                _buildTextField("Tên sự kiện", _titleCtrl),
                _buildTextField("Địa điểm", _destinationCtrl),

                // 🔹 Ngày giờ
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Ngày khởi hành",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, color: primary)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => _pickDate(true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: inputColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_startDate == null
                                      ? "Chọn ngày"
                                      : "${_startDate!.day}/${_startDate!.month}/${_startDate!.year}"),
                                  const Icon(Icons.calendar_today, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Ngày trở lại",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, color: primary)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => _pickDate(false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: inputColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_endDate == null
                                      ? "Chọn ngày"
                                      : "${_endDate!.day}/${_endDate!.month}/${_endDate!.year}"),
                                  const Icon(Icons.calendar_today, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Giờ đi",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, color: primary)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => _pickTime(true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: inputColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_startTime == null
                                      ? "Chọn giờ"
                                      : _startTime!.format(context)),
                                  const Icon(Icons.access_time, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Giờ về",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, color: primary)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => _pickTime(false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: inputColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_endTime == null
                                      ? "Chọn giờ"
                                      : _endTime!.format(context)),
                                  const Icon(Icons.access_time, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                _buildTextField("Nơi tập trung", _placeCtrl),
                _buildTextField("Mô tả", _descriptionCtrl),
                _buildTextField("Lưu ý", _noteCtrl),

                const SizedBox(height: 20),

                // Thêm thành viên
                Align(
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'Thêm thành viên',
                    style: TextStyle(
                        color: Color(0xFF324E2A),
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _selectMembers,
                      child: _buildMemberCircle('+', 'Thêm', isAdd: true),
                    ),
                    for (var m in members) _buildMemberCircle(m['avatar'], m['username']),
                  ],
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: BorderSide(color: primary),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Hủy"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: inputColor,
                        foregroundColor: primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 12),
                      ),
                      onPressed: _createEvent,
                      child: const Text("Tạo sự kiện"),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectMembers() async {
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();

    final allUsers = usersSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'username': data['username'] ?? 'Người dùng',
        'avatar': data['avatar'] ?? '', // có thể để trống nếu chưa có
      };
    }).toList();

    final selected = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) {
        // Sao chép danh sách hiện tại
        final tempSelected = [...members];

        return StatefulBuilder( // Dùng StatefulBuilder để cập nhật UI trong dialog
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Chọn thành viên'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  children: allUsers.map((user) {
                    final isSelected = tempSelected.any((u) => u['id'] == user['id']);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (checked) {
                        setStateDialog(() {
                          if (checked == true) {
                            // Thêm người dùng vào danh sách tạm
                            tempSelected.add({
                              'id': user['id'],
                              'username': user['username'],
                              'avatar': user['avatar'],
                            });
                          } else {
                            // Gỡ người dùng khỏi danh sách
                            tempSelected.removeWhere((u) => u['id'] == user['id']);
                          }
                        });
                      },
                      title: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: user['avatar'] != ''
                                ? NetworkImage(user['avatar'])
                                : const AssetImage('assets/default_avatar.png')
                            as ImageProvider,
                          ),
                          const SizedBox(width: 12),
                          Text(user['username']),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, tempSelected);
                  },
                  child: const Text('Xong'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null) {
      setState(() {
        members
          ..clear()
          ..addAll(selected);
      });
    }
  }

  Widget _buildMemberCircle(String? avatar, String? name, {bool isAdd = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isAdd
                  ? const Color(0xFFC2D3B3)
                  : const Color(0xFFA2B293),
            ),
            child: Center(
              child: isAdd
                  ? const Text(
                '+',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF324E2A),
                ),
              )
                  : ClipOval(
                child: (avatar != null)
                    ? Image.network(
                  avatar,
                  width: 55,
                  height: 55,
                  fit: BoxFit.cover,
                )
                    : Text((name ?? '?')
                    .toString()
                    .substring(0, 1)
                    .toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF324E2A),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isAdd ? 'Thêm' : (name ?? 'Ẩn danh'),
            style: const TextStyle(color: Color(0xFF324E2A), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
