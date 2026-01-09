import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'incoming_call_screen.dart';
import 'ringtone_player.dart';
import 'package:stour/main.dart';

class CallListener {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  StreamSubscription<QuerySnapshot>? _callSub;
  StreamSubscription<QuerySnapshot>? _groupCallSub;

  final Set<String> _shown = {};

  void start() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    print("Call listener starting...");

    /// ===== 1–1 CALL =====
    _callSub = _db
        .collection('calls')
        .where('status', isEqualTo: 'ringing')
        .where('status', whereIn: ['ringing', 'calling'])
        .snapshots()
        .listen((query) {
      for (var doc in query.docs) {
        _handleIncoming(
          callId: doc.id,
          data: doc.data() as Map<String, dynamic>,
          isGroup: false,
        );
      }
    });

    /// ===== GROUP CALL =====
    _groupCallSub = _db
        .collection('group_calls')
        .where('status', isEqualTo: 'ringing')
        .where('participants', arrayContains: uid)
        .snapshots()
        .listen((query) {
      for (var doc in query.docs) {
        _handleIncoming(
          callId: doc.id,
          data: doc.data() as Map<String, dynamic>,
          isGroup: true,
        );
      }
    });
  }

  void _handleIncoming({
    required String callId,
    required Map<String, dynamic> data,
    required bool isGroup,
  }) {
    if (_shown.contains(callId)) return;

    _shown.add(callId);

    final callType = data['mode'] as String? ?? 'audio';

    final callerName = isGroup
        ? (data['groupName'] as String? ?? 'Cuộc gọi nhóm')
        : (data['callerName'] as String? ?? 'Người gọi');

    final callerAvatar = isGroup
        ? (data['groupAvatar'] as String? ?? '')
        : (data['callerAvatar'] as String? ?? '');

    final participants = (data['participants'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    playRingtone();

    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      _shown.remove(callId);
      return;
    }

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => IncomingCallScreen(
        callId: callId,
        callerName: callerName,
        callerAvatar: callerAvatar,
        callType: callType,
        participants: participants,
        isGroup: isGroup,// 👈 thêm nhưng KHÔNG ảnh hưởng logic cũ
        onFinish: () {
          stopRingtone();
          _shown.remove(callId);
        },
      ),
    );
  }

  void dispose() {
    _callSub?.cancel();
    _groupCallSub?.cancel();
  }
}
