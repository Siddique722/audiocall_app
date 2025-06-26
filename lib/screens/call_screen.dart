import 'dart:async';
import 'dart:developer';

import 'package:agora/model/call_model.dart';
import 'package:agora/services/fire_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:get/get.dart';

import '../../services/agora_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora/services/auth_services.dart';

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
  bool _isCallEnded = false;
  late String displayName;
  late String otherUserName;
  late bool isReceiver;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  Timer? _timer;
  int _callDuration = 0; // seconds

  @override
  void initState() {
    super.initState();
    isReceiver = !widget.call.hasDialled;
    displayName =
        isReceiver ? widget.call.callerName : widget.call.receiverName;
    otherUserName =
        isReceiver ? widget.call.callerName : widget.call.receiverName;
    log('[CallScreen] initState: isReceiver=$isReceiver, displayName=$displayName');
    _initialize();
    _listenForCallStatus();
    if (!widget.call.hasDialled) {
      FlutterRingtonePlayer().playRingtone();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _joined && !_isCallEnded) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
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
            _joined = true;
            FlutterRingtonePlayer().stop();
          });
          _startTimer();
        },
        onUserOffline: (uid) {
          debugPrint('[CallScreen] Remote user offline: uid=$uid');
          _endCall();
        },
      );
      debugPrint('[CallScreen] Fetching userId from SharedPreferences');
      final userId = await AuthService().getUserId(); // standardized to 'id'
      debugPrint('[CallScreen] userId=$userId');
      if (userId == null) throw Exception('User ID not found');
      final token =
          await AuthService().getToken(); // standardized to 'auth_token'
      debugPrint('[CallScreen] token=$token');
      final fcmToken =
          await AuthService().getFcmToken(); // standardized to 'fcm_token'
      debugPrint('[CallScreen] fcmToken=$fcmToken');
      debugPrint(
          '[CallScreen] Fetching Agora token for channel: ${widget.channelName}');
      final agoraToken =
          await _agoraService.getAgoraToken(widget.channelName, userId);
      debugPrint('[CallScreen] Agora token fetched successfully');
      await _agoraService.joinChannel(widget.channelName, userId, agoraToken);
      debugPrint('[CallScreen] Joined Agora channel');
    } catch (e, stack) {
      debugPrint('[CallScreen] Error initializing call: $e\n$stack');
      if (mounted) {
        debugPrint('[CallScreen] Error Failed to start call: $e');
        setState(() {
          _isCallEnded = true;
        });
        Get.snackbar('Error', 'Failed to start call: $e',
            backgroundColor: Colors.white, colorText: Colors.red);
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
    _stopTimer();
    if (mounted) setState(() => _isCallEnded = true);
    await _agoraService.leaveChannel();
    await _agoraService.dispose();
    FlutterRingtonePlayer().stop();
    await _firestoreService.endCall(
        widget.call.callerId, widget.call.receiverId);
    if (mounted) Get.back();
  }

  void _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await _agoraService.muteLocalAudioStream(_isMuted);
  }

  void _toggleSpeaker() async {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    await _agoraService.setEnableSpeakerphone(_isSpeakerOn);
  }

  @override
  void dispose() {
    _stopTimer();
    FlutterRingtonePlayer().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange,
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
              const SizedBox(height: 20),
              Text(
                otherUserName.isNotEmpty ? otherUserName : 'Unknown',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _joined
                    ? 'Connected'
                    : (isReceiver ? 'Incoming call...' : 'Calling...'),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 10),
              if (_joined)
                Text(
                  'Call Duration: ${_formatDuration(_callDuration)}',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              Expanded(child: Container()),
              Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton(
                      heroTag: 'mic',
                      backgroundColor: _isMuted ? Colors.grey : Colors.green,
                      child: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                      onPressed: _toggleMute,
                    ),
                    const SizedBox(width: 30),
                    FloatingActionButton(
                      heroTag: 'end',
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.call_end),
                      onPressed: _endCall,
                    ),
                    const SizedBox(width: 30),
                    FloatingActionButton(
                      heroTag: 'speaker',
                      backgroundColor: _isSpeakerOn ? Colors.blue : Colors.grey,
                      child:
                          Icon(_isSpeakerOn ? Icons.volume_up : Icons.hearing),
                      onPressed: _toggleSpeaker,
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
