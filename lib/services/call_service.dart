import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

class CallService {
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;

  /// Khởi tạo renderers
  Future<void> initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  /// Tạo PeerConnection
  Future<void> initPeerConnection() async {
    final config = {
      "iceServers": [
        {"urls": "stun:stun.l.google.com:19302"},
      ],
      "sdpSemantics": "unified-plan"
    };

    peerConnection = await createPeerConnection(config);

    /// Khi nhận track từ remote
    peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        remoteRenderer.srcObject = remoteStream;
      }
    };
  }

  /// Mở camera/micro
  Future<void> openUserMedia({bool audioOnly = false}) async {
    // 1) Request permissions (rất quan trọng)
    final mic = await Permission.microphone.request();
    final cam = audioOnly ? PermissionStatus.granted : await Permission.camera.request();

    if (!mic.isGranted || (!audioOnly && !cam.isGranted)) {
      throw Exception("Camera/Microphone permission denied");
    }

    // 2) GetUserMedia
    final mediaParams = {
      "audio": true,
      "video": audioOnly
          ? false
          : {
        "facingMode": "user",
      }
    };

    localStream = await navigator.mediaDevices.getUserMedia(mediaParams);
    localRenderer.srcObject = localStream;

    // 3) Add tracks vào peer
    if (peerConnection != null) {
      for (var track in localStream!.getTracks()) {
        await peerConnection!.addTrack(track, localStream!);
      }
    }
  }

  // ---------------------------------------------------------------------------
  //  CALLER: START OUTGOING CALL (OFFER)
  // ---------------------------------------------------------------------------

  Future<void> startOutgoingCall(
      String callId, {
        bool audioOnly = false,
      }) async {
    await initPeerConnection();
    await openUserMedia(audioOnly: audioOnly);

    /// Lưu ICE của caller
    peerConnection!.onIceCandidate = (RTCIceCandidate? candidate) {
      if (candidate != null) {
        _db
            .collection("calls")
            .doc(callId)
            .collection("callerCandidates")
            .add({
          "candidate": candidate.candidate,
          "sdpMid": candidate.sdpMid,
          "sdpMLineIndex": candidate.sdpMLineIndex,
        });
      }
    };

    /// Tạo OFFER
    final offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);

    /// Lưu OFFER lên Firestore
    await _db.collection("calls").doc(callId).set({
      "offer": {"sdp": offer.sdp, "type": offer.type},
      "callerId": currentUser?.uid,
      "status": "ringing",
      "mode": audioOnly ? 'audio' : 'video',
      "createdAt": FieldValue.serverTimestamp(),
    });

    /// Nhận ANSWER từ callee
    _db.collection("calls").doc(callId).snapshots().listen((doc) async {
      final data = doc.data();
      if (data == null) return;

      // Lấy remoteDescription (API mới)
      final remoteDesc = await peerConnection!.getRemoteDescription();

      if (data["answer"] != null && remoteDesc == null) {
        final answer = RTCSessionDescription(
          data["answer"]["sdp"],
          data["answer"]["type"],
        );
        await peerConnection!.setRemoteDescription(answer);
      }
    });

    /// Nhận ICE từ callee
    _db
        .collection("calls")
        .doc(callId)
        .collection("receiverCandidates")
        .snapshots()
        .listen((snapshot) {
      for (var d in snapshot.docs) {
        final c = d.data();
        peerConnection!.addCandidate(RTCIceCandidate(
          c["candidate"],
          c["sdpMid"],
          c["sdpMLineIndex"],
        ));
      }
    });
  }

  // ---------------------------------------------------------------------------
  //  RECEIVER: ANSWER CALL
  // ---------------------------------------------------------------------------

  Future<void> answerCall(String callId, {bool audioOnly = false}) async {
    await initPeerConnection();
    await openUserMedia(audioOnly: audioOnly);

    final doc = await _db.collection("calls").doc(callId).get();
    final data = doc.data();
    if (data == null || data["offer"] == null) {
      throw Exception("Offer not found");
    }

    /// Set OFFER từ caller
    final offer = RTCSessionDescription(
      data["offer"]["sdp"],
      data["offer"]["type"],
    );
    await peerConnection!.setRemoteDescription(offer);

    /// Gửi ICE của callee
    peerConnection!.onIceCandidate = (candidate) {
      if (candidate != null) {
        _db
            .collection('calls')
            .doc(callId)
            .collection('receiverCandidates')
            .add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    /// Tạo ANSWER
    final answer = await peerConnection!.createAnswer();
    await peerConnection!.setLocalDescription(answer);

    /// Lưu ANSWER
    await _db.collection("calls").doc(callId).update({
      "answer": {"sdp": answer.sdp, "type": answer.type},
      "status": "accepted",
      "acceptedMode": audioOnly ? 'audio' : 'video',
    });

    /// Nhận ICE từ caller
    _db
        .collection('calls')
        .doc(callId)
        .collection('callerCandidates')
        .snapshots()
        .listen((snapshot) {
      for (var d in snapshot.docs) {
        final c = d.data();
        peerConnection!.addCandidate(RTCIceCandidate(
          c['candidate'],
          c['sdpMid'],
          c['sdpMLineIndex'],
        ));
      }
    });
  }

  // ---------------------------------------------------------------------------
  // END CALL
  // ---------------------------------------------------------------------------

  Future<void> hangUp(String callId) async {
    await localStream?.dispose();
    await remoteStream?.dispose();
    await peerConnection?.close();

    /// Set trạng thái ended
    await _db.collection("calls").doc(callId).update({
      "status": "ended",
    });
  }

  /// Cleanup renderer
  Future<void> dispose() async {
    await localRenderer.dispose();
    await remoteRenderer.dispose();
  }
}
