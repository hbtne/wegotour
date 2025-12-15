import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

  StreamSubscription? _callerIceSub;
  StreamSubscription? _receiverIceSub;
  StreamSubscription? _answerSub;

  bool _answered = false;
  VoidCallback? onRemoteStream;
  VoidCallback? onLocalStream;

  /* -------------------- INIT -------------------- */

  Future<void> initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  Future<void> _ensurePeer() async {
    if (_peer != null) return;

    _peer = await createPeerConnection({
      "iceServers": [
        {
          "urls": ["stun:stun.l.google.com:19302"]
        },
        {
          "urls": [
            "turn:openrelay.metered.ca:80",
            "turn:openrelay.metered.ca:443",
            "turn:openrelay.metered.ca:443?transport=tcp",
          ],
          "username": "openrelayproject",
          "credential": "openrelayproject",
        }
      ]
    });

    _peer!.onIceConnectionState = (state) {
      print("ICE state: $state");
    };

    _peer!.onTrack = (event) async {
      print("🔥 onTrack: ${event.track.kind}");

        _remoteStream ??= await createLocalMediaStream('remote');
        _remoteStream!.addTrack(event.track);
        remoteRenderer.srcObject = _remoteStream;
      print("streams length: ${event.streams.length}");
      onRemoteStream?.call();
    };
  }

  /* -------------------- MEDIA -------------------- */

  Future<void> _openUserMedia({required bool audioOnly}) async {
    if (!kIsWeb) {
      final mic = await Permission.microphone.request();
      final cam =
      audioOnly ? PermissionStatus.granted : await Permission.camera.request();

      if (!mic.isGranted || (!audioOnly && !cam.isGranted)) {
        throw Exception("Permission denied");
      }
    }

    _localStream = await navigator.mediaDevices.getUserMedia({
      "audio": true,
      "video": audioOnly
          ? false
          : {
        "facingMode": "user",
      },
    });

    localRenderer.srcObject = _localStream;
    onLocalStream?.call();
    for (final track in _localStream!.getTracks()) {
      await _peer!.addTrack(track, _localStream!);
    }

    if (!kIsWeb && Platform.isAndroid) {
      await Helper.setSpeakerphoneOn(true);
    }
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

  /* -------------------- CALLER -------------------- */

  Future<void> startOutgoingCall(
      String callId, {
        required bool audioOnly,
      }) async {
    await initRenderers();
    await _ensurePeer();
    await _openUserMedia(audioOnly: audioOnly);

    _peer!.onIceCandidate = (c) {
      if (c != null) {
        _db
            .collection("calls")
            .doc(callId)
            .collection("callerCandidates")
            .add(c.toMap());
      }
    };

    final offer = await _peer!.createOffer();
    await _peer!.setLocalDescription(offer);

    await _db.collection("calls").doc(callId).update({
      "offer": offer.toMap(),
    });

    _answerSub = _db
        .collection("calls")
        .doc(callId)
        .snapshots()
        .listen((doc) async {
      final data = doc.data();
      if (data == null || data["answer"] == null) return;
      if (_peer!.getRemoteDescription() != null) return;

      await _peer!.setRemoteDescription(
        RTCSessionDescription(
          data["answer"]["sdp"],
          data["answer"]["type"],
        ),
      );
    });

    _receiverIceSub = _db
        .collection("calls")
        .doc(callId)
        .collection("receiverCandidates")
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final c = change.doc.data()!;
          _peer!.addCandidate(
            RTCIceCandidate(
              c["candidate"],
              c["sdpMid"],
              c["sdpMLineIndex"],
            ),
          );
        }
      }
    });
  }

  /* -------------------- RECEIVER -------------------- */

  Future<void> answerCall(
      String callId, {
        required bool audioOnly,
      }) async {
    if (_answered) return;
    _answered = true;

    await initRenderers();
    await _ensurePeer();

    final doc = await _db.collection("calls").doc(callId).get();
    final data = doc.data();
    if (data == null || data["offer"] == null) return;

    await _peer!.setRemoteDescription(
      RTCSessionDescription(
        data["offer"]["sdp"],
        data["offer"]["type"],
      ),
    );

    await _openUserMedia(audioOnly: audioOnly);

    _peer!.onIceCandidate = (c) {
      if (c != null) {
        _db
            .collection("calls")
            .doc(callId)
            .collection("receiverCandidates")
            .add(c.toMap());
      }
    };

    final answer = await _peer!.createAnswer();
    await _peer!.setLocalDescription(answer);

    await _db.collection("calls").doc(callId).update({
      "answer": answer.toMap(),
      "status": "accepted",
    });

    _callerIceSub = _db
        .collection("calls")
        .doc(callId)
        .collection("callerCandidates")
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final c = change.doc.data()!;
          _peer!.addCandidate(
            RTCIceCandidate(
              c["candidate"],
              c["sdpMid"],
              c["sdpMLineIndex"],
            ),
          );
        }
      }
    });
  }

  /* -------------------- END -------------------- */

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
  }
}
