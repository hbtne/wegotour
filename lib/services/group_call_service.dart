import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupCallService {
  final _db = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;

  Map<String, RTCPeerConnection> peerConnections = {};
  Map<String, RTCVideoRenderer> remoteRenderers = {};

  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  MediaStream? localStream;

  Future<void> initLocalRenderer() async {
    await localRenderer.initialize();
  }

  Future<void> openMicrophoneAndCamera({bool audioOnly = false}) async {
    final media = {
      "audio": true,
      "video": !audioOnly ? {"facingMode": "user"} : false,
    };
    localStream = await navigator.mediaDevices.getUserMedia(media);
    localRenderer.srcObject = localStream;
  }

  Future<void> joinRoom(String roomId, {bool audioOnly = false}) async {
    await initLocalRenderer();
    await openMicrophoneAndCamera(audioOnly: audioOnly);

    await _db.collection("calls").doc(roomId).set({
      "participants": FieldValue.arrayUnion([currentUser!.uid]),
    }, SetOptions(merge: true));

    _db.collection("calls").doc(roomId).snapshots().listen((doc) {
      if (!doc.exists) return;
      final data = doc.data()!;
      final participants = List<String>.from(data['participants'] ?? []);
      for (String peerId in participants) {
        if (peerId != currentUser!.uid && !peerConnections.containsKey(peerId)) {
          _createPeerConnectionWith(peerId, roomId, audioOnly: audioOnly);
        }
      }
    });
  }

  Future<void> _createPeerConnectionWith(String peerId, String roomId, {bool audioOnly = false}) async {
    final config = {"iceServers": [{"urls": "stun:stun.l.google.com:19302"}]};

    RTCPeerConnection pc = await createPeerConnection(config);
    peerConnections[peerId] = pc;

    if (localStream != null) pc.addStream(localStream!);

    RTCVideoRenderer renderer = RTCVideoRenderer();
    await renderer.initialize();
    remoteRenderers[peerId] = renderer;

    pc.onAddStream = (stream) {
      renderer.srcObject = stream;
    };

    pc.onIceCandidate = (candidate) {
      if (candidate != null) {
        _db.collection('calls').doc(roomId)
            .collection('candidates')
            .doc("${currentUser!.uid}_to_$peerId")
            .collection('items')
            .add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    // Tạo offer nếu UID nhỏ hơn peerId
    if (currentUser!.uid.compareTo(peerId) < 0) {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      await _db.collection('calls').doc(roomId)
          .collection('signals')
          .doc("${currentUser!.uid}_to_$peerId")
          .set({'offer': offer.toMap()});
    }

    // Lắng nghe signals
    _db.collection('calls').doc(roomId)
        .collection('signals')
        .doc("${peerId}_to_${currentUser!.uid}")
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      final remoteDesc = await pc.getRemoteDescription();

      if (data['offer'] != null && remoteDesc == null) {
        final offer = RTCSessionDescription(data['offer']['sdp'], data['offer']['type']);
        await pc.setRemoteDescription(offer);
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        await _db.collection('calls').doc(roomId)
            .collection('signals')
            .doc("${currentUser!.uid}_to_$peerId")
            .set({'answer': answer.toMap()});
      }

      if (data['answer'] != null && remoteDesc == null) {
        final answer = RTCSessionDescription(data['answer']['sdp'], data['answer']['type']);
        await pc.setRemoteDescription(answer);
      }
    });

    // Lắng nghe ICE candidates
    _db.collection('calls').doc(roomId)
        .collection('candidates')
        .doc("${peerId}_to_${currentUser!.uid}")
        .collection('items')
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        var c = doc.data();
        pc.addCandidate(RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']));
      }
    });
  }

  Future<void> leaveRoom(String roomId) async {
    for (var pc in peerConnections.values) {
      await pc.close();
    }
    for (var r in remoteRenderers.values) {
      await r.dispose();
    }
    await localStream?.dispose();

    await _db.collection('calls').doc(roomId).update({
      'participants': FieldValue.arrayRemove([currentUser!.uid])
    });

    peerConnections.clear();
    remoteRenderers.clear();
  }
}
