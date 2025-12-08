import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateCollectionEvent extends StatefulWidget {
  const CreateCollectionEvent({super.key});
  @override
  State<CreateCollectionEvent> createState() => _CreateCollectionEventState();
}

class _CreateCollectionEventState extends State<CreateCollectionEvent> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 7));
  final _badgeIconCtrl = TextEditingController();

  Future<void> _create() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final badgeId = 'badge_${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
    final event = {
      'title': title,
      'description': _descCtrl.text.trim(),
      'category': 'collection',
      'startAt': Timestamp.fromDate(_start),
      'endAt': Timestamp.fromDate(_end),
      'createdBy': user.uid,
      'createdAt': Timestamp.now(),
      'badge': {
        'id': badgeId,
        'name': 'Huy hiệu $title',
        'icon': _badgeIconCtrl.text.trim(),
        'description': 'Huy hiệu sự kiện $title',
      },
      'processed': false,
    };
    await FirebaseFirestore.instance.collection('collect_events').add(event);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo event sưu tầm thành công')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo event sưu tầm')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Tiêu đề')),
          TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Mô tả')),
          TextField(controller: _badgeIconCtrl, decoration: const InputDecoration(labelText: 'URL icon huy hiệu (tuỳ chọn)')),
          Row(children: [
            TextButton(onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: _start, firstDate: DateTime.now().subtract(const Duration(days:1)), lastDate: DateTime(2100));
              if (d != null) setState(() => _start = d);
            }, child: Text('Bắt đầu: ${_start.toLocal().toIso8601String().split('T').first}')),
            const SizedBox(width: 8),
            TextButton(onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: _end, firstDate: _start, lastDate: DateTime(2100));
              if (d != null) setState(() => _end = d);
            }, child: Text('Kết thúc: ${_end.toLocal().toIso8601String().split('T').first}')),
          ]),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _create, child: const Text('Tạo')),
        ]),
      ),
    );
  }
}