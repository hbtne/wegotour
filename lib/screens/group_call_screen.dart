import 'package:flutter/material.dart';
import '../services/group_call_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class GroupCallScreen extends StatefulWidget {
  final String roomId;
  final bool audioOnly;

  const GroupCallScreen({required this.roomId, this.audioOnly = false, super.key});

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  final groupService = GroupCallService();

  @override
  void initState() {
    super.initState();
    _join();
  }

  Future<void> _join() async {
    await groupService.joinRoom(widget.roomId, audioOnly: widget.audioOnly);
    setState(() {});
  }

  @override
  void dispose() {
    groupService.leaveRoom(widget.roomId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: widget.audioOnly
          ? Center(child: Icon(Icons.phone_in_talk_rounded, size: 80, color: Colors.white))
          : Stack(
        children: [
          GridView.count(
            crossAxisCount: 2,
            children: groupService.remoteRenderers.values
                .map((r) => RTCVideoView(r))
                .toList(),
          ),
          Positioned(
            right: 20,
            bottom: 20,
            width: 120,
            height: 160,
            child: RTCVideoView(groupService.localRenderer, mirror: true),
          ),
        ],
      ),
    );
  }
}
