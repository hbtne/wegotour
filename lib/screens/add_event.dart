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
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
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
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng chọn đầy đủ ngày và giờ")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final startDateStr = DateFormat('dd/MM/yyyy').format(_startDate!);
    final endDateStr = DateFormat('dd/MM/yyyy').format(_endDate!);
    final startTimeStr = _startTime!.format(context);
    final endTimeStr = _endTime!.format(context);

    final newEvent = {
      "groupId": widget.groupId,
      "title": _titleCtrl.text.trim(),
      "destination": _destinationCtrl.text.trim(),
      "place": _placeCtrl.text.trim(),
      "description": _descriptionCtrl.text.trim(),
      "note": _noteCtrl.text.trim(),
      "startDate": startDateStr,
      "endDate": endDateStr,
      "startTime": startTimeStr,
      "endTime": endTimeStr,
      "joined": members,
      "createdBy": {
        "id": user.uid,
        "name": user.displayName ?? "Người dùng",
        "avatarUrl": user.photoURL ??
            "https://cdn-icons-png.flaticon.com/512/847/847969.png",
      },
      "createdAt": FieldValue.serverTimestamp(),
    };

    final docRef =
        await FirebaseFirestore.instance.collection("events").add(newEvent);

    // 🔹 Cập nhật group với sự kiện mới
    await FirebaseFirestore.instance.collection("groups").doc(widget.groupId).update({
      'events': FieldValue.arrayUnion([
        {
          'id': docRef.id,
          'title': _titleCtrl.text.trim(),
          'place': _placeCtrl.text.trim(),
          'time': "$startTimeStr $startDateStr",
        }
      ])
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã tạo sự kiện thành công!")),
      );
      Navigator.pop(context);
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

  Future<void> _selectMembers() async {
    final usersSnapshot =
        await FirebaseFirestore.instance.collection('users').get();

    final allUsers = usersSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'username': data['username'] ?? 'Người dùng',
        'avatar': data['avatar'] ?? '',
      };
    }).toList();

    final selected = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) {
        final tempSelected = [...members];

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Chọn thành viên'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  children: allUsers.map((user) {
                    final isSelected =
                        tempSelected.any((u) => u['id'] == user['id']);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (checked) {
                        setStateDialog(() {
                          if (checked == true) {
                            tempSelected.add(user);
                          } else {
                            tempSelected.removeWhere(
                                (u) => u['id'] == user['id']);
                          }
                        });
                      },
                      title: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: (user['avatar']?.isNotEmpty ?? false)
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
                  onPressed: () => Navigator.pop(context, tempSelected),
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
        members = selected;
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
                      child: (avatar != null && avatar.isNotEmpty)
                          ? Image.network(
                              avatar,
                              width: 55,
                              height: 55,
                              fit: BoxFit.cover,
                            )
                          : Text(
                              (name ?? '?')
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

                // Ngày và giờ
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDateSelector("Ngày khởi hành", true),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDateSelector("Ngày trở lại", false),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeSelector("Giờ đi", true),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTimeSelector("Giờ về", false),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                _buildTextField("Nơi tập trung", _placeCtrl),
                _buildTextField("Mô tả", _descriptionCtrl),
                _buildTextField("Lưu ý", _noteCtrl),

                const SizedBox(height: 20),
                const Text(
                  'Thêm thành viên',
                  style: TextStyle(
                      color: Color(0xFF324E2A),
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _selectMembers,
                      child: _buildMemberCircle('+', 'Thêm', isAdd: true),
                    ),
                    for (var m in members)
                      _buildMemberCircle(m['avatar'], m['username']),
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

  Widget _buildDateSelector(String label, bool isStart) {
    final date = isStart ? _startDate : _endDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontWeight: FontWeight.bold, color: primary)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _pickDate(isStart),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: inputColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(date == null
                    ? "Chọn ngày"
                    : DateFormat('dd/MM/yyyy').format(date)),
                const Icon(Icons.calendar_today, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelector(String label, bool isStart) {
    final time = isStart ? _startTime : _endTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontWeight: FontWeight.bold, color: primary)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _pickTime(isStart),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: inputColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(time == null ? "Chọn giờ" : time.format(context)),
                const Icon(Icons.access_time, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
