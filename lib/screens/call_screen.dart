import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/call_service.dart';

class CallScreen extends StatefulWidget {
  final String callId;
  final bool audioOnly;
  final bool isCaller;
  bool isConnected;

  CallScreen({
    required this.callId,
    required this.audioOnly,
    required this.isCaller,
    this.isConnected = false,
    super.key,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallService callService = CallService();
  StreamSubscription<DocumentSnapshot>? _callSub;

  // bool _connected = false;

  @override
  void initState() {
    super.initState();
    callService.onLocalStream = () {
      if (!mounted) return;
      setState(() {});
    };

    callService.onRemoteStream = () {
      if (!mounted) return;
      setState(() => widget.isConnected = true);
    };

    _init();
  }

  Future<void> _init() async {
    await callService.initialize();

    if (widget.isCaller) {
      await callService.startCall(
        widget.callId,
        audioOnly: widget.audioOnly,
      );
      _listenCaller();
    } else {
      await callService.answerCall(
        widget.callId,
        audioOnly: widget.audioOnly,
      );
      _listenCallee();
    }
  }

  void _listenCaller() {
    _callSub = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen((doc) async {
      final data = doc.data();
      if (data == null) return;

      if (['declined', 'ended', 'missed'].contains(data['status'])) {
        callService.dispose();
        await _closeAndExit();
      }

      if (data['status'] == 'accepted' && !widget.isConnected) {
        setState(() => widget.isConnected = true);
      }
    });
  }

  void _listenCallee() {
    print(widget.isConnected);
    _callSub = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen((doc) async {
      var data = doc.data();
      if (data == null) return;
      if (['ended', 'declined'].contains(data['status'])) {
        await callService.hangUp(widget.callId);
        _closeAndExit();
      }
    });
  }

  Future<void> _closeAndExit() async {
    await _callSub?.cancel();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _callSub?.cancel();
    callService.hangUp(widget.callId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("🎥 Remote srcObject tracks: "
        "${callService.remoteRenderer.srcObject?.getVideoTracks().length}");
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (!widget.isConnected)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          else if (widget.audioOnly)
            _audioUI()
          else
            _videoUI(),
          _endCallButton(),
        ],
      ),
    );
  }

  Widget _audioUI() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.phone_in_talk_rounded,
            size: 80, color: Colors.white),
        SizedBox(height: 20),
        Text('Cuộc gọi đang diễn ra...',
            style: TextStyle(color: Colors.white, fontSize: 22)),
      ],
    ),
  );

  Widget _videoUI() => Stack(
    fit: StackFit.expand,
    children: [
      RTCVideoView(
        callService.remoteRenderer,
        mirror: false,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        filterQuality: FilterQuality.none,
      )
      ,
      Positioned(
        right: 16,
        top: 40,
        width: 120,
        height: 160,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: RTCVideoView(
            callService.localRenderer,
            mirror: true,
          ),
        ),
      ),
    ],
  );

  Widget _endCallButton() => Positioned(
    bottom: 40,
    left: 0,
    right: 0,
    child: Center(
      child: FloatingActionButton(
        backgroundColor: Colors.red,
        child: const Icon(Icons.call_end, size: 32),
        onPressed: () async {
          await callService.hangUp(widget.callId);
          _closeAndExit();
        },
      ),
    ),
  );
}
