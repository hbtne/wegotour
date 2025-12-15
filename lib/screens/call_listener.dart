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
  StreamSubscription<QuerySnapshot>? _sub;

  final Set<String> _shown = {};
  bool _dialogShown = false;   // ⬅ ADD: tránh showDialog 2 lần

  void start() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    print("Call listener starting...");

    _sub = _db
        .collection('calls')
        .where('status', isEqualTo: 'ringing')
        .where('participants', arrayContains: uid)
        .snapshots()
        .listen((query) {
      print('LISTENER STILL ACTIVE');
      for (var doc in query.docs) {
        _handleIncoming(doc.id, doc.data() as Map<String, dynamic>);
      }
    });
  }

  void _handleIncoming(String callId, Map<String, dynamic> data) {
    print(_shown);
    if (_shown.contains(callId)) return;
    print(_dialogShown);
    // if (_dialogShown) return;             // ⬅ ADD: dialog đang mở → không mở tiếp

    _shown.add(callId);
    _dialogShown = true;                  // ⬅ ADD
    final callType = data['mode'] as String? ?? 'audio';
    final callerName = data['callerName'] as String? ?? 'Người gọi';
    final callerAvatar = data['callerAvatar'] as String? ?? '';
    // ⬅ FIX: participants cast an toàn
    final participants = (data['participants'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    playRingtone();

    // ⬅ FIX: context an toàn hơn
    final ctx = navigatorKey.currentContext;
    print(ctx);
    if (ctx == null) {
      _dialogShown = false;
      return;
    }
    print("opening incomming screen...");
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => IncomingCallScreen(
        callId: callId,
        callerName: callerName,
        callerAvatar: callerAvatar,
        callType: callType,
        participants: participants,
        onFinish: () {
          stopRingtone();
          _shown.remove(callId);
          _dialogShown = false;        // ⬅ RELEASE dialog flag
        },
      ),
    );
  }

  void dispose() {
    _sub?.cancel();
  }
}
