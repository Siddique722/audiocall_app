import 'dart:developer';

import 'package:agora/model/call_model.dart';
import 'package:agora/services/fire_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:get/get.dart';
import '../../services/agora_service.dart';
import 'package:permission_handler/permission_handler.dart';

class CallScreen extends StatefulWidget {
  final CallModel call;
  final String channelName;

  const CallScreen({super.key, required this.call, required this.channelName});

  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final AgoraService _agoraService = AgoraService();
  final FirestoreService _firestoreService = FirestoreService();
  bool _joined = false;
  int? _remoteUid;
  bool _isCallEnded = false;
  late String displayName;
  late bool isReceiver;

  @override
  void initState() {
    super.initState();
    isReceiver = !widget.call.hasDialled;
    displayName =
        isReceiver ? widget.call.callerName : widget.call.receiverName;
    log('[CallScreen] initState: isReceiver=$isReceiver, displayName=$displayName');
    _initialize();
    _listenForCallStatus();
    if (!widget.call.hasDialled) {
      FlutterRingtonePlayer().playRingtone();
    }
  }

  Future<void> _initialize() async {
    try {
      debugPrint('[CallScreen] Requesting permissions...');
      await _requestPermissions();
      debugPrint('[CallScreen] Initializing Agora...');
      await _agoraService.initializeAgora();
      _agoraService.setEventHandler(
        onUserJoined: (uid) {
          debugPrint('[CallScreen] Remote user joined: uid=$uid');
          setState(() {
            _remoteUid = uid;
            _joined = true;
            FlutterRingtonePlayer().stop();
          });
        },
        onUserOffline: (uid) {
          debugPrint('[CallScreen] Remote user offline: uid=$uid');
          _endCall();
        },
      );
      debugPrint(
          '[CallScreen] Fetching Agora token for channel: ${widget.channelName}');
      final token = await _agoraService.getAgoraToken(
          widget.channelName, widget.call.callerId);
      debugPrint('[CallScreen] Agora token fetched successfully');
      await _agoraService.joinChannel(
          widget.channelName, widget.call.callerId, token);
      debugPrint('[CallScreen] Joined Agora channel');
    } catch (e, stack) {
      debugPrint('[CallScreen] Error initializing call: $e\n$stack');
      if (mounted) {
        setState(() {
          _isCallEnded = true;
        });
        Get.snackbar('Error', 'Failed to start call: $e');
      }
    }
  }

  Future<void> _requestPermissions() async {
    await [Permission.microphone].request();
  }

  void _listenForCallStatus() {
    _firestoreService.getCallStream(widget.call.callerId).listen((snapshot) {
      if (!snapshot.exists && !_isCallEnded) {
        _endCall();
      }
    });
  }

  void _endCall() async {
    setState(() => _isCallEnded = true);
    await _agoraService.leaveChannel();
    await _agoraService.dispose();
    FlutterRingtonePlayer().stop();
    await _firestoreService.endCall(
        widget.call.callerId, widget.call.receiverId);
    Get.back();
  }

  @override
  void dispose() {
    FlutterRingtonePlayer().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor: Colors.grey[800],
                child: Icon(
                  Icons.person,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20),
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10),
              Text(
                _joined
                    ? 'Connected'
                    : (isReceiver ? 'Incoming call...' : 'Calling...'),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[400],
                ),
              ),
              Expanded(child: Container()),
              Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton(
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.call_end),
                      onPressed: _endCall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
