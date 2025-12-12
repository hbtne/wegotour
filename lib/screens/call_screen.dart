import 'package:flutter/material.dart';
import '../services/call_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CallScreen extends StatefulWidget {
  final String callId;
  final bool audioOnly;
  final bool isCaller; // 👈 thêm cờ xác định caller/callee

  const CallScreen({
    required this.callId,
    required this.audioOnly,
    required this.isCaller,
    super.key,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final callService = CallService();
  bool isLoaded = false;
  late Stream<DocumentSnapshot> callStream;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await callService.initRenderers();

    if (widget.isCaller) {
      // ---------------------------------------------------------
      // CALLER: Gửi offer
      // ---------------------------------------------------------
      await callService.startOutgoingCall(
        widget.callId,
        audioOnly: widget.audioOnly,
      );

      setState(() => isLoaded = true);
      return;
    }

    // ---------------------------------------------------------
    // CALLEE: Chờ OFFER trước khi answer
    // ---------------------------------------------------------
    callStream = FirebaseFirestore.instance
        .collection("calls")
        .doc(widget.callId)
        .snapshots();

    callStream.listen((doc) async {
      final data = doc.data() as Map<String, dynamic>?;

      // Không có offer → chưa answer được
      if (data == null || data["offer"] == null) return;

      print("Offer detected → answering...");

      // Chỉ answer 1 lần
      if (!isLoaded) {
        await callService.answerCall(
          widget.callId,
          audioOnly: widget.audioOnly,
        );

        setState(() => isLoaded = true);
      }
    });
  }

  @override
  void dispose() {
    callService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoaded) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          /// Audio Only UI
          if (widget.audioOnly)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.phone_in_talk_rounded,
                      size: 80, color: Colors.white),
                  SizedBox(height: 20),
                  Text("Đang kết nối...",
                      style: TextStyle(color: Colors.white, fontSize: 24)),
                ],
              ),
            )
          else
          /// Video UI
            Stack(
              children: [
                RTCVideoView(callService.remoteRenderer),
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
            ),

          /// END CALL BUTTON
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                backgroundColor: Colors.red,
                child: const Icon(Icons.call_end, size: 32),
                onPressed: () async {
                  await callService.hangUp(widget.callId);
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
