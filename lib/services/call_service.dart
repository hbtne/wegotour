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

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------

  Future<void> initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  Future<void> _ensurePeer() async {
    print("before return: $_peer");
    if (_peer != null) return;

    _peer = await createPeerConnection({
      "iceServers": [
        {
          "urls": [
            "stun:stun.l.google.com:19302",
          ]
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

    print("After return: $_peer");

    // 🚨 BẮT BUỘC
    await _peer!.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
      init: RTCRtpTransceiverInit(
        direction: TransceiverDirection.SendRecv,
      ),
    );

    await _peer!.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(
        direction: TransceiverDirection.SendRecv,
      ),
    );

    _peer!.onTrack = (event) async {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
      } else {
        _remoteStream ??= await createLocalMediaStream('remote');
        _remoteStream!.addTrack(event.track);
        remoteRenderer.srcObject = _remoteStream;
      }
    };

    _peer!.onTrack = (event) {
      print("🔥 onTrack:");
      print("  kind: ${event.track.kind}");
      print("  streams: ${event.streams.length}");
    };
    _peer!.onIceCandidate = (candidate) {
      print("ICE candidate: ${candidate.candidate}");
    };
    _peer!.onIceConnectionState = (state) {
      print("ICE state: $state");
    };
  }

  // ---------------------------------------------------------------------------
  // MEDIA
  // ---------------------------------------------------------------------------

  Future<void> _openUserMedia({required bool audioOnly}) async {
    // 📱 Mobile permissions
    if (!kIsWeb) {
      final mic = await Permission.microphone.request();
      final cam =
      audioOnly ? PermissionStatus.granted : await Permission.camera.request();

      if (!mic.isGranted || (!audioOnly && !cam.isGranted)) {
        throw Exception("Permission denied");
      }
    }

    // 🌐 Web + Mobile dùng chung
    _localStream = await navigator.mediaDevices.getUserMedia({
      "audio": true,
      "video": audioOnly
          ? false
          : {
        "facingMode": "user",
      },
    });

    localRenderer.srcObject = _localStream;

    for (var track in _localStream!.getTracks()) {
      await _peer!.addTrack(track, _localStream!);
    }

    // 🔊 Android only
    if (!kIsWeb && Platform.isAndroid) {
      await Helper.setSpeakerphoneOn(true);
    }
  }

  void _stopMedia() {
    // ⛔ Stop LOCAL tracks (camera + mic)
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        track.stop();
      }
      _localStream!.dispose();
    }

    // ⛔ Stop REMOTE tracks
    if (_remoteStream != null) {
      for (final track in _remoteStream!.getTracks()) {
        track.stop();
      }
      _remoteStream!.dispose();
    }

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    _localStream = null;
    _remoteStream = null;
  }

  // ---------------------------------------------------------------------------
  // CALLER
  // ---------------------------------------------------------------------------

  Future<void> startOutgoingCall(
      String callId, {
        required bool audioOnly,
      }) async {
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

    // 👂 Listen ANSWER
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

    // 👂 Receiver ICE – CHỈ add ICE MỚI
    _receiverIceSub = _db
        .collection("calls")
        .doc(callId)
        .collection("receiverCandidates")
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final c = change.doc.data()!;
          _peer?.addCandidate(
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

  // ---------------------------------------------------------------------------
  // RECEIVER
  // ---------------------------------------------------------------------------

  Future<void> answerCall(
      String callId, {
        required bool audioOnly,
      }) async {
    if (_answered) return;
    _answered = true;

    await _ensurePeer();
    await _openUserMedia(audioOnly: audioOnly);
    print("Answered: $_answered");

    final doc = await _db.collection("calls").doc(callId).get();
    final data = doc.data();
    if (data == null || data["offer"] == null) return;

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
            .add(c.toMap());
      }
    };

    final answer = await _peer!.createAnswer();
    await _peer!.setLocalDescription(answer);

    await _db.collection("calls").doc(callId).update({
      "answer": answer.toMap(),
      "status": "accepted",
    });

    // 👂 Caller ICE – CHỈ add ICE MỚI
    _callerIceSub = _db
        .collection("calls")
        .doc(callId)
        .collection("callerCandidates")
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final c = change.doc.data()!;
          _peer?.addCandidate(
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

  // ---------------------------------------------------------------------------
  // END
  // ---------------------------------------------------------------------------

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
