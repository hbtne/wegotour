import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

class GroupCallService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Map<String, RTCPeerConnection> _peers = {};
  final Map<String, MediaStream> _localStreams = {};
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, RTCVideoRenderer> remoteRenderers = {};

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  MediaStream? _previewStream;

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

  Future<MediaStream> _createLocalStream({required bool audioOnly}) async {
    if (!kIsWeb) {
      final mic = await Permission.microphone.request();
      final cam = audioOnly
          ? PermissionStatus.granted
          : await Permission.camera.request();

      if (!mic.isGranted || (!audioOnly && !cam.isGranted)) {
        throw Exception('Media permission denied');
      }
    }

    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': audioOnly
          ? false
          : {
        'facingMode': 'user',
      },
    });

    return stream;
  }

  Future<void> _preparePreview({required bool audioOnly}) async {
    _previewStream ??= await _createLocalStream(audioOnly: audioOnly);
    localRenderer.srcObject = _previewStream;
    onLocalStream?.call();
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
          'username': username,
          'credential': password,
        }
      ],
      'iceCandidatePoolSize': 10,
    });

    pc.onIceConnectionState = (state) {
      debugPrint('[$peerKey] ICE: $state');
    };

    pc.onTrack = (event) async {
      if (event.track.kind != 'video') return;

      debugPrint('🎥 Remote video from $peerKey');

      // init renderer
      if (!remoteRenderers.containsKey(peerKey)) {
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        remoteRenderers[peerKey] = renderer;
      }

      // init remote stream (ASYNC-safe)
      if (!_remoteStreams.containsKey(peerKey)) {
        final stream = await createLocalMediaStream('remote_$peerKey');
        _remoteStreams[peerKey] = stream;
      }

      _remoteStreams[peerKey]!.addTrack(event.track);
      remoteRenderers[peerKey]!.srcObject = _remoteStreams[peerKey];

      onRemoteStream?.call();
    };

    return pc;
  }

  String _peerKey(String a, String b) => '$a->$b';

  // ================= START GROUP CALL =================

  Future<void> startGroupCall(
      String groupCallId,
      List<String> participants, {
        required bool audioOnly,
      }) async {
    await initialize();
    await _preparePreview(audioOnly: audioOnly);

    final myUid = _auth.currentUser!.uid;

    for (final uid in participants) {
      if (uid == myUid) continue;

      final key = _peerKey(myUid, uid);

      final pc = await _createPeer(key);
      _peers[key] = pc;

      final stream = await _createLocalStream(audioOnly: audioOnly);
      _localStreams[key] = stream;

      for (final track in stream.getTracks()) {
        await pc.addTrack(track, stream);
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

      final offer = await pc.createOffer();
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

  // ================= ANSWER GROUP CALL =================

  Future<void> answerGroupCall(
      String groupCallId,
      String peerKey, {
        required bool audioOnly,
      }) async {
    await initialize();
    await _preparePreview(audioOnly: audioOnly);

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

    final stream = await _createLocalStream(audioOnly: audioOnly);
    _localStreams[peerKey] = stream;

    for (final track in stream.getTracks()) {
      await pc.addTrack(track, stream);
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

    final answer = await pc.createAnswer();
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
      for (final d in s.docChanges) {
        if (d.type == DocumentChangeType.added) {
          final c = d.doc.data()!;
          pc.addCandidate(
            RTCIceCandidate(
              c['candidate'],
              c['sdpMid'],
              c['sdpMLineIndex'],
            ),
          );
        }
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
      for (final d in s.docChanges) {
        if (d.type == DocumentChangeType.added) {
          final c = d.doc.data()!;
          pc.addCandidate(
            RTCIceCandidate(
              c['candidate'],
              c['sdpMid'],
              c['sdpMLineIndex'],
            ),
          );
        }
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

  // ================= MEDIA CONTROL =================

  void toggleMic(bool enable) {
    for (final s in _localStreams.values) {
      for (final t in s.getAudioTracks()) {
        t.enabled = enable;
      }
    }
  }

  void toggleVideo(bool enable) {
    for (final s in _localStreams.values) {
      for (final t in s.getVideoTracks()) {
        t.enabled = enable;
      }
    }
  }

  Future<void> switchCamera() async {
    for (final s in _localStreams.values) {
      final videos = s.getVideoTracks();
      if (videos.isNotEmpty) {
        await Helper.switchCamera(videos.first);
      }
    }
  }

  // ================= DISPOSE =================

  Future<void> dispose() async {
    for (final pc in _peers.values) {
      await pc.close();
    }
    _peers.clear();

    for (final s in _localStreams.values) {
      for (final t in s.getTracks()) {
        t.stop();
      }
      await s.dispose();
    }
    _localStreams.clear();

    for (final s in _remoteStreams.values) {
      await s.dispose();
    }
    _remoteStreams.clear();

    for (final r in remoteRenderers.values) {
      await r.dispose();
    }
    remoteRenderers.clear();

    _previewStream?.dispose();
    _previewStream = null;

    await localRenderer.dispose();
    _initialized = false;
  }
}
