import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

class GroupCallService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final Map<String, RTCPeerConnection> _peers = {};
  final Map<String, RTCVideoRenderer> remoteRenderers = {};

  MediaStream? _localStream;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final username = dotenv.env['WEBRTC_USERNAME'];
  final password = dotenv.env['WEBRTC_PASSWORD'];
  bool _initialized = false;
  VoidCallback? onLocalStream;
  VoidCallback? onRemoteStream;
  // ================= INIT =================

  Future<void> initialize() async {
    if (_initialized) return;
    await localRenderer.initialize();
    _initialized = true;
  }

  // ================= MEDIA =================

  Future<void> _openUserMedia({required bool audioOnly}) async {
    if (!kIsWeb) {
      await Permission.microphone.request();
      if (!audioOnly) await Permission.camera.request();
    }

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': audioOnly ? false : {'facingMode': 'user'},
    });

    localRenderer.srcObject = _localStream;
    onLocalStream?.call();
  }

  void toggleMic(bool enable) {
    final audioTracks = _localStream?.getAudioTracks();
    if (audioTracks != null && audioTracks.isNotEmpty) {
      audioTracks.first.enabled = enable;
    }
  }

  void toggleVideo(bool enable) {
    final videoTracks = _localStream?.getVideoTracks();
    if (videoTracks != null && videoTracks.isNotEmpty) {
      videoTracks.first.enabled = enable;
    }
  }

  Future<void> switchCamera() async {
    final videoTracks = _localStream?.getVideoTracks();
    if (videoTracks != null && videoTracks.isNotEmpty) {
      await Helper.switchCamera(videoTracks.first);
    }
  }

  // ================= PEER =================

  Future<RTCPeerConnection> _createPeer(String peerKey) async {
    final pc = await createPeerConnection({
      'iceServers': [
        {
          'urls': [
            'stun:global.stun.metered.ca:3478',
            'turn:global.relay.metered.ca:80',
            'turn:global.relay.metered.ca:443',
            'turns:global.relay.metered.ca:443'
          ],
          'username': '$username',
          'credential': '$password',
        }
      ],
      'iceCandidatePoolSize': 10,
    });

    pc.onConnectionState = (state) {
      debugPrint('[$peerKey] state: $state');
    };

    /// 🔥 GIỐNG CALL SERVICE
    pc.onTrack = (event) async {
      final stream = event.streams.first;

      remoteRenderers.putIfAbsent(peerKey, () => RTCVideoRenderer());
      await remoteRenderers[peerKey]!.initialize();
      remoteRenderers[peerKey]!.srcObject = stream;
      onRemoteStream?.call();

      debugPrint('✅ Remote ${event.track.kind} attached for $peerKey');
    };

    return pc;
  }

  String _peerKey(String a, String b) =>
      a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

  // ================= START GROUP CALL (CALLER) =================

  Future<void> startGroupCall(
      String groupCallId,
      List<String> participants, {
        required bool audioOnly,
      }) async {
    await initialize();
    await _openUserMedia(audioOnly: audioOnly);

    final myUid = _auth.currentUser!.uid;

    for (final uid in participants) {
      if (uid == myUid) continue;

      final key = _peerKey(myUid, uid);
      final pc = await _createPeer(key);
      _peers[key] = pc;

      /// 🔥 COPY Y HỆT CALL SERVICE
      for (final track in _localStream!.getTracks()) {
        pc.addTrack(track, _localStream!);
      }

      pc.onIceCandidate = (c) {
        if (c != null) {
          _db
              .collection('group_calls')
              .doc(groupCallId)
              .collection('peers')
              .doc(key)
              .collection('callerCandidates')
              .add(c.toMap());
        }
      };

      /// 🔥 OFFER GIỐNG 1–1
      final offer = await pc.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': !audioOnly,
      });
      await pc.setLocalDescription(offer);

      await _db
          .collection('group_calls')
          .doc(groupCallId)
          .collection('peers')
          .doc(key)
          .set({
        'offer': offer.toMap(),
        'caller': myUid,
        'receiver': uid,
      });

      _listenAnswer(groupCallId, key, pc);
      _listenReceiverIce(groupCallId, key, pc);
    }
  }

  // ================= ANSWER GROUP CALL (RECEIVER) =================

  Future<void> answerGroupCall(
      String groupCallId,
      String peerKey, {
        required bool audioOnly,
      }) async {
    await initialize();
    await _openUserMedia(audioOnly: audioOnly);

    final doc = await _db
        .collection('group_calls')
        .doc(groupCallId)
        .collection('peers')
        .doc(peerKey)
        .get();

    final data = doc.data();
    if (data == null) return;

    final pc = await _createPeer(peerKey);
    _peers[peerKey] = pc;

    for (final track in _localStream!.getTracks()) {
      pc.addTrack(track, _localStream!);
    }

    await pc.setRemoteDescription(
      RTCSessionDescription(
        data['offer']['sdp'],
        data['offer']['type'],
      ),
    );

    pc.onIceCandidate = (c) {
      if (c != null) {
        doc.reference
            .collection('receiverCandidates')
            .add(c.toMap());
      }
    };

    /// 🔥 ANSWER GIỐNG 1–1
    final answer = await pc.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': !audioOnly,
    });
    await pc.setLocalDescription(answer);

    await doc.reference.update({'answer': answer.toMap()});

    _listenCallerIce(groupCallId, peerKey, pc);
  }

  // ================= ICE =================

  void _listenCallerIce(String callId, String key, RTCPeerConnection pc) {
    _db
        .collection('group_calls')
        .doc(callId)
        .collection('peers')
        .doc(key)
        .collection('callerCandidates')
        .snapshots()
        .listen((s) {
      for (final d in s.docs) {
        final c = d.data();
        pc.addCandidate(
          RTCIceCandidate(
            c['candidate'],
            c['sdpMid'],
            c['sdpMLineIndex'],
          ),
        );
      }
    });
  }

  void _listenReceiverIce(String callId, String key, RTCPeerConnection pc) {
    _db
        .collection('group_calls')
        .doc(callId)
        .collection('peers')
        .doc(key)
        .collection('receiverCandidates')
        .snapshots()
        .listen((s) {
      for (final d in s.docs) {
        final c = d.data();
        pc.addCandidate(
          RTCIceCandidate(
            c['candidate'],
            c['sdpMid'],
            c['sdpMLineIndex'],
          ),
        );
      }
    });
  }

  void _listenAnswer(String callId, String key, RTCPeerConnection pc) {
    _db
        .collection('group_calls')
        .doc(callId)
        .collection('peers')
        .doc(key)
        .snapshots()
        .listen((doc) async {
      final data = doc.data();
      if (data == null || data['answer'] == null) return;
      if (await pc.getRemoteDescription() != null) return;

      await pc.setRemoteDescription(
        RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        ),
      );
    });
  }

  // ================= DISPOSE =================

  Future<void> dispose() async {
    for (final pc in _peers.values) {
      await pc.close();
    }
    _peers.clear();

    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();

    for (final r in remoteRenderers.values) {
      await r.dispose();
    }
    remoteRenderers.clear();

    await localRenderer.dispose();
  }
}
