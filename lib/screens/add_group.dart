import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stour/model/group.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final List<Map<String, dynamic>> _members = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  /// 🔹 Tạo nhóm và lưu vào Firestore
  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên nhóm')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final docRef = _firestore.collection('groups').doc();

      final group = Group(
        id: docRef.id,
        name: name,
        description: desc,
        avatarUrl:'',
        lastMessage: 'Chưa có tin nhắn',
        lastTime: DateTime.now(),
        unread: false,
        members: _members,
      );

      await docRef.set(group.toMap());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo nhóm thành công 🎉')),
        );
        Navigator.pop(context); // 🔹 Đóng popup
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tạo nhóm: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 🔹 Mở danh sách người dùng để chọn thêm thành viên
  Future<void> _selectMembers() async {
    final usersSnapshot = await _firestore.collection('users').get();

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
        final tempSelected = [..._members];

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
        _members
          ..clear()
          ..addAll(selected);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 340,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFB5C4A3),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: const Center(
                  child: Text(
                    'TẠO NHÓM',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF324E2A),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tên nhóm
              Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Tên nhóm',
                  style: TextStyle(
                      color: Color(0xFF324E2A),
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Nhập tên nhóm ở đây...',
                  filled: true,
                  fillColor: const Color(0xFFFDE8B3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Mô tả
              Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Mô tả',
                  style: TextStyle(
                      color: Color(0xFF324E2A),
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Nhập mô tả ở đây',
                  filled: true,
                  fillColor: const Color(0xFFFDE8B3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 12),

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
                  for (var m in _members) _buildMemberCircle(m['avatar'], m['username']),
                ],
              ),

              const SizedBox(height: 24),

              // Nút
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF3B5D34)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(color: Color(0xFF3B5D34)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createGroup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDE8B3),
                        foregroundColor: const Color(0xFF3B5D34),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text('Tạo nhóm'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget avatar cho thành viên hoặc nút thêm
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
