import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

class CallService {
  RTCPeerConnection? _peer;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------

  Future<void> initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  Future<void> _initPeer() async {
    final config = {
      "iceServers": [
        {"urls": "stun:stun.l.google.com:19302"},
      ],
      "sdpSemantics": "unified-plan",
    };

    _peer = await createPeerConnection(config);

    _peer!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        remoteRenderer.srcObject = _remoteStream;
      }
    };
  }

  // ---------------------------------------------------------------------------
  // MEDIA
  // ---------------------------------------------------------------------------

  Future<void> _openUserMedia({required bool audioOnly}) async {
    final mic = await Permission.microphone.request();
    final cam = audioOnly
        ? PermissionStatus.granted
        : await Permission.camera.request();

    if (!mic.isGranted || (!audioOnly && !cam.isGranted)) {
      throw Exception("Camera / Microphone permission denied");
    }

    final constraints = {
      "audio": true,
      "video": audioOnly
          ? false
          : {
        "facingMode": "user",
      },
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    localRenderer.srcObject = _localStream;

    for (var track in _localStream!.getTracks()) {
      await _peer!.addTrack(track, _localStream!);
    }
  }

  /// 🔥 QUAN TRỌNG: TẮT CAMERA / MIC THỰC SỰ
  void _stopMedia() {
    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        track.stop();
      }
      _localStream = null;
    }

    if (_remoteStream != null) {
      for (var track in _remoteStream!.getTracks()) {
        track.stop();
      }
      _remoteStream = null;
    }

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
  }

  // ---------------------------------------------------------------------------
  // CALLER
  // ---------------------------------------------------------------------------

  Future<void> startOutgoingCall(
      String callId, {
        required bool audioOnly,
      }) async {
    await _initPeer();
    await _openUserMedia(audioOnly: audioOnly);

    _peer!.onIceCandidate = (c) {
      if (c != null) {
        _db
            .collection("calls")
            .doc(callId)
            .collection("callerCandidates")
            .add({
          "candidate": c.candidate,
          "sdpMid": c.sdpMid,
          "sdpMLineIndex": c.sdpMLineIndex,
        });
      }
    };

    final offer = await _peer!.createOffer();
    await _peer!.setLocalDescription(offer);

    await _db.collection("calls").doc(callId).set({
      "offer": {"sdp": offer.sdp, "type": offer.type},
      "callerId": _currentUser?.uid,
      "status": "ringing",
      "mode": audioOnly ? "audio" : "video",
      "createdAt": FieldValue.serverTimestamp(),
    });

    _db.collection("calls").doc(callId).snapshots().listen((doc) async {
      final data = doc.data();
      if (data == null || data["answer"] == null) return;

      if (_peer!.getRemoteDescription() == null) {
        await _peer!.setRemoteDescription(
          RTCSessionDescription(
            data["answer"]["sdp"],
            data["answer"]["type"],
          ),
        );
      }
    });

    _db
        .collection("calls")
        .doc(callId)
        .collection("receiverCandidates")
        .snapshots()
        .listen((snapshot) {
      for (var d in snapshot.docs) {
        final c = d.data();
        _peer?.addCandidate(
          RTCIceCandidate(c["candidate"], c["sdpMid"], c["sdpMLineIndex"]),
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // RECEIVER
  // ---------------------------------------------------------------------------

  Future<void> answerCall(
      String callId, {
        required bool audioOnly,
      }) async {
    await _initPeer();
    await _openUserMedia(audioOnly: audioOnly);

    final doc = await _db.collection("calls").doc(callId).get();
    final data = doc.data();
    if (data == null || data["offer"] == null) {
      throw Exception("Offer not found");
    }

    await _peer!.setRemoteDescription(
      RTCSessionDescription(
        data["offer"]["sdp"],
        data["offer"]["type"],
      ),
    );

    _peer!.onIceCandidate = (c) {
      if (c != null) {
        _db
            .collection("calls")
            .doc(callId)
            .collection("receiverCandidates")
            .add({
          "candidate": c.candidate,
          "sdpMid": c.sdpMid,
          "sdpMLineIndex": c.sdpMLineIndex,
        });
      }
    };

    final answer = await _peer!.createAnswer();
    await _peer!.setLocalDescription(answer);

    await _db.collection("calls").doc(callId).update({
      "answer": {"sdp": answer.sdp, "type": answer.type},
      "status": "accepted",
    });

    _db
        .collection("calls")
        .doc(callId)
        .collection("callerCandidates")
        .snapshots()
        .listen((snapshot) {
      for (var d in snapshot.docs) {
        final c = d.data();
        _peer?.addCandidate(
          RTCIceCandidate(c["candidate"], c["sdpMid"], c["sdpMLineIndex"]),
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // END / CLEANUP
  // ---------------------------------------------------------------------------

  Future<void> hangUp(String callId) async {
    _stopMedia();
    await _peer?.close();
    _peer = null;

    await _db.collection("calls").doc(callId).update({
      "status": "ended",
    });
  }

  Future<void> dispose() async {
    _stopMedia();
    await _peer?.close();
    _peer = null;

    await localRenderer.dispose();
    await remoteRenderer.dispose();
  }
}
