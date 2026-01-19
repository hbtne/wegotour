import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/group_call_service.dart';

class GroupCallScreen extends StatefulWidget {
  final String groupCallId;
  final bool audioOnly;
  final bool isCaller;
  final List<String> participants;
  final String title;

  const GroupCallScreen({
    super.key,
    required this.groupCallId,
    required this.audioOnly,
    required this.isCaller,
    required this.participants,
    required this.title,
  });

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  final GroupCallService callService = GroupCallService();

  StreamSubscription<DocumentSnapshot>? _groupSub;
  StreamSubscription<QuerySnapshot>? _peerSub;

  bool _micEnabled = false;
  bool _videoEnabled = false;

  @override
  void initState() {
    super.initState();

    /// 🔥 rebuild UI khi có remote video
    callService.onRemoteStream = () {
      if (mounted) setState(() {});
    };
    callService.onLocalStream = () {
      if (mounted) setState(() {});
    };
    callService.initialize().then((_) async {
      if (widget.isCaller) {
        await callService.startGroupCall(
          widget.groupCallId,
          widget.participants,
          audioOnly: widget.audioOnly,
        );
      } else {
        _answerAllPeers();
      }
    });
    _listenGroupStatus();
  }

  // ================= ANSWER ALL PEERS =================

  void _answerAllPeers() {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    _peerSub = FirebaseFirestore.instance
        .collection('group_calls')
        .doc(widget.groupCallId)
        .collection('peers')
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docs) {
        final data = doc.data();

        if (data['receiver'] == myUid && data['answer'] == null) {
          await callService.answerGroupCall(
            widget.groupCallId,
            doc.id,
            audioOnly: widget.audioOnly,
          );
        }
      }
    });
  }

  // ================= GROUP STATUS =================

  void _listenGroupStatus() {
    _groupSub = FirebaseFirestore.instance
        .collection('group_calls')
        .doc(widget.groupCallId)
        .snapshots()
        .listen((doc) async {
      final data = doc.data();
      if (data == null) return;

      if (data['status'] == 'ended') {
        await _closeAndExit();
      }
    });
  }

  Future<void> _closeAndExit() async {
    await _groupSub?.cancel();
    await _peerSub?.cancel();
    await callService.dispose();

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _groupSub?.cancel();
    _peerSub?.cancel();
    callService.dispose();
    super.dispose();
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          widget.audioOnly ? _audioUI() : _videoGrid(),
          _callControls(),
        ],
      ),
    );
  }

  // ================= AUDIO =================

  Widget _audioUI() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.groups, size: 80, color: Colors.white),
        const SizedBox(height: 20),
        Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 22),
        ),
      ],
    ),
  );

  // ================= VIDEO GRID =================

  Widget _videoGrid() {
    final remotes = callService.remoteRenderers.values.toList();
    final count = remotes.length + 1; // local + remotes

    int crossAxisCount = 1;
    if (count > 2) crossAxisCount = 2;
    if (count > 4) crossAxisCount = 3;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      children: [
        _videoTile(
          callService.localRenderer,
          mirror: true,
          label: 'You',
        ),
        ...remotes.map((r) => _videoTile(r)),
      ],
    );
  }

  Widget _videoTile(
      RTCVideoRenderer renderer, {
        bool mirror = false,
        String? label,
      }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RTCVideoView(
          renderer,
          mirror: mirror,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
        if (label != null)
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  // ================= END =================

  Widget _callControls() => Positioned(
    bottom: 40,
    left: 0,
    right: 0,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [

        /// Mic
        FloatingActionButton(
          heroTag: 'mic',
          backgroundColor: _micEnabled ? Colors.grey : Colors.white,
          child: Icon(
            _micEnabled ? Icons.mic_off : Icons.mic,
            color: Colors.black,
          ),
          onPressed: () {
            setState(() {
              _micEnabled = !_micEnabled;
              callService.toggleMic(!_micEnabled);
            });
          },
        ),

        /// End call
        FloatingActionButton(
          backgroundColor: Colors.red,
          child: const Icon(Icons.call_end, size: 32),
          onPressed: () async {
            await FirebaseFirestore.instance
                .collection('group_calls')
                .doc(widget.groupCallId)
                .update({'status': 'ended'});

            await _closeAndExit();
          },
        ),

        /// Video
        if (!widget.audioOnly)
          FloatingActionButton(
            heroTag: 'video',
            backgroundColor: _videoEnabled ? Colors.grey : Colors.white,
            child: Icon(
              _videoEnabled ? Icons.videocam_off : Icons.videocam,
              color: Colors.black,
            ),
            onPressed: () {
              setState(() {
                _videoEnabled = !_videoEnabled;
                callService.toggleVideo(!_videoEnabled);
              });
            },
          ),

        /// Switch camera
        if (!widget.audioOnly)
          FloatingActionButton(
            heroTag: 'switch',
            backgroundColor: Colors.white,
            child: const Icon(Icons.cameraswitch, color: Colors.black),
            onPressed: () async {
              await callService.switchCamera();
            },
          ),
      ],
    ),
  );

}
