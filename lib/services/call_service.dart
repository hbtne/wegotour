import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

class CallService {
  RTCPeerConnection? _peer;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  final username = dotenv.env['WEBRTC_USERNAME'];
  final password = dotenv.env['WEBRTC_PASSWORD'];

  StreamSubscription? _callerIceSub;
  StreamSubscription? _receiverIceSub;
  StreamSubscription? _answerSub;

  bool _initialized = false;

  VoidCallback? onLocalStream;
  VoidCallback? onRemoteStream;

  Future<void> initialize() async {
    if (_initialized) return;

    await localRenderer.initialize();
    await remoteRenderer.initialize();

    await _createPeer();

    _initialized = true;
  }

  Future<void> _createPeer() async {
    if (_peer != null) return;
    _peer = await createPeerConnection({
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

    _peer!.onIceConnectionState = (state) {
      debugPrint("❄️ ICE: $state");
    };

    _peer!.onTrack = (event) async {
      final kind = event.track.kind;
      debugPrint("🎯 onTrack: $kind, streams: ${event.streams.length}");

      MediaStream? stream;

      if (event.streams.isNotEmpty) {
        stream = event.streams.first;
      } else {
        _remoteStream ??= await createLocalMediaStream('remote');
        _remoteStream!.addTrack(event.track);
        stream = _remoteStream;
      }

      if (kind == 'audio') {
        debugPrint("🔊 Remote audio track added: ${event.track.id}");
        onRemoteStream?.call();
        return;
      }

      if (kind == 'video') {
        debugPrint("🎥 Remote video tracks: ${stream?.getVideoTracks().length}");
        remoteRenderer.srcObject = stream;
        onRemoteStream?.call();
      }
    };
  }

  // =================== MEDIA ===================

  Future<void> _openUserMedia({required bool audioOnly}) async {
    if (!kIsWeb) {
      final mic = await Permission.microphone.request();
      final cam = audioOnly
          ? PermissionStatus.granted
          : await Permission.camera.request();

      if (!mic.isGranted || (!audioOnly && !cam.isGranted)) {
        throw Exception("Media permission denied");
      }
    }

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': audioOnly
          ? false
          : {
        'facingMode': 'user',
      },
    });

    final audioTracks = _localStream!.getAudioTracks();
    final videoTracks = _localStream!.getVideoTracks();
    debugPrint("🎤 local audio tracks count: ${audioTracks.length}");
    debugPrint("🎥 local video tracks count: ${videoTracks.length}");

    localRenderer.srcObject = _localStream;
    onLocalStream?.call();

    for (final track in _localStream!.getTracks()) {
      await _peer!.addTrack(track, _localStream!);
    }

    if (!kIsWeb && Platform.isAndroid) {
      await Helper.setSpeakerphoneOn(true);

      if (audioTracks.isNotEmpty) {
        await Helper.setMicrophoneMute(false, audioTracks.first);
      }

      for (final t in audioTracks) {
        debugPrint("🎤 local audio track: enabled=${t.enabled}, id=${t.id}");
      }
    }

    _localStream!.getAudioTracks().forEach((t) => t.enabled = true);
  }

  void _stopMedia() {
    _localStream?.getTracks().forEach((t) => t.stop());
    _remoteStream?.getTracks().forEach((t) => t.stop());

    _localStream?.dispose();
    _remoteStream?.dispose();

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    _localStream = null;
    _remoteStream = null;
  }

  // =================== CALLER ===================

  Future<void> startCall(
      String callId, {
        required bool audioOnly,
      }) async {
    await initialize();
    await _openUserMedia(audioOnly: audioOnly);

    // danh sách ICE chờ xử lý
    final List<RTCIceCandidate> pendingCandidates = [];

    // gửi ICE của caller
    _peer!.onIceCandidate = (c) {
      if (c != null) {
        _db
            .collection("calls")
            .doc(callId)
            .collection("callerCandidates")
            .add(c.toMap());
      }
    };

    // tạo offer
    final offer = await _peer!.createOffer();
    await _peer!.setLocalDescription(offer);

    final senders = await _peer!.getSenders();
    for (final s in senders) {
      debugPrint("📤 sender after offer: ${s.track?.kind}");
    }

    // gửi offer lên Firestore
    await _db.collection("calls").doc(callId).update({
      "offer": offer.toMap(),
      "status": "calling",
      "callerId": _currentUser?.uid,
      "createdAt": FieldValue.serverTimestamp(),
    });

    // Lắng nghe answer từ receiver
    _answerSub = _db
        .collection("calls")
        .doc(callId)
        .snapshots()
        .listen((doc) async {
      final data = doc.data();
      if (data == null || data["answer"] == null) return;

      // tránh set lại remoteDescription
      final currentRemote = await _peer!.getRemoteDescription();
      if (currentRemote != null) return;

      // set remote answer
      await _peer!.setRemoteDescription(
        RTCSessionDescription(
          data["answer"]["sdp"],
          data["answer"]["type"],
        ),
      );

      // xử lý ICE pending
      for (final ice in pendingCandidates) {
        await _peer!.addCandidate(ice);
      }
      pendingCandidates.clear();
    });

    // Lắng nghe ICE từ receiver
    _receiverIceSub = _db
        .collection("calls")
        .doc(callId)
        .collection("receiverCandidates")
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final c = change.doc.data()!;
          final ice = RTCIceCandidate(
            c["candidate"],
            c["sdpMid"],
            c["sdpMLineIndex"],
          );

          final remoteDesc = await _peer!.getRemoteDescription();

          if (remoteDesc != null) {
            await _peer!.addCandidate(ice);
          } else {
            pendingCandidates.add(ice);
          }
        }
      }
    });
  }
  // =================== RECEIVER ===================

  Future<void> answerCall(
      String callId, {
        required bool audioOnly,
      }) async {
    await initialize();

    final doc = await _db.collection("calls").doc(callId).get();
    final data = doc.data();
    if (data == null || data["offer"] == null) return;

    // mở camera/mic trước
    await _openUserMedia(audioOnly: audioOnly);

    // danh sách ICE chờ xử lý
    final List<RTCIceCandidate> pendingCandidates = [];

    // Lắng nghe ICE từ caller
    _callerIceSub = _db
        .collection("calls")
        .doc(callId)
        .collection("callerCandidates")
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final c = change.doc.data()!;
          final ice = RTCIceCandidate(
            c["candidate"],
            c["sdpMid"],
            c["sdpMLineIndex"],
          );

          // kiểm tra remoteDescription đã sẵn sàng chưa
          final remoteDesc = await _peer!.getRemoteDescription();

          if (remoteDesc != null) {
            await _peer!.addCandidate(ice);
          } else {
            pendingCandidates.add(ice);
          }
        }
      }
    });

    // set remote offer
    await _peer!.setRemoteDescription(
      RTCSessionDescription(
        data["offer"]["sdp"],
        data["offer"]["type"],
      ),
    );

    // xử lý các ICE pending
    for (final ice in pendingCandidates) {
      await _peer!.addCandidate(ice);
    }
    pendingCandidates.clear();

    // gửi ICE của receiver
    _peer!.onIceCandidate = (c) {
      if (c != null) {
        _db
            .collection("calls")
            .doc(callId)
            .collection("receiverCandidates")
            .add(c.toMap());
      }
    };

    // tạo answer
    final answer = await _peer!.createAnswer();
    await _peer!.setLocalDescription(answer);

    await _db.collection("calls").doc(callId).update({
      "answer": answer.toMap(),
      "status": "accepted",
    });

    debugPrint("remote description: ${await _peer!.getRemoteDescription()}");
  }

  // =================== END ===================

  Future<void> hangUp(String callId) async {
    await _db.collection("calls").doc(callId).update({
      "status": "ended",
      "endedBy": _currentUser?.uid,
      "endedAt": FieldValue.serverTimestamp(),
    });

    await dispose();
  }

  Future<void> dispose() async {
    await _callerIceSub?.cancel();
    await _receiverIceSub?.cancel();
    await _answerSub?.cancel();

    _stopMedia();
    await _peer?.close();
    _peer = null;

    await localRenderer.dispose();
    await remoteRenderer.dispose();

    _initialized = false;
  }
}