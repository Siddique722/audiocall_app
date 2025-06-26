import 'package:agora/contabts/constants.dart';
import 'package:agora/services/auth_services.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:http/http.dart' as http;
import 'dart:developer' show log;
import 'dart:convert';

class AgoraService {
  RtcEngine? _engine;

  /// Initializes the Agora RTC Engine
  Future<void> initializeAgora() async {
    try {
      // Create an instance of RtcEngine
      _engine = createAgoraRtcEngine();
      // Initialize the engine with the Agora App ID
      await _engine!.initialize(const RtcEngineContext(
        appId: Constants.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));
      // Enable audio
      await _engine!.enableAudio();
    } catch (e) {
      print('Error initializing Agora: $e');
      rethrow;
    }
  }

  /// Fetches an Agora token from the Laravel backend
  Future<String> getAgoraToken(String channelName, String userId) async {
    final token = await AuthService().getToken();
    print('[AgoraService] getAgoraToken: userId=$userId');
    print('[AgoraService] getAgoraToken: token=$token');
    final int uid = int.tryParse(userId) ?? 0;
    final url = 'https://etalk.mtai.live/api/agora/token';
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'channelName': channelName,
      'uid': uid,
    });
    print('[AgoraService] getAgoraToken: url=$url');
    print('[AgoraService] getAgoraToken: headers=$headers');
    print('[AgoraService] getAgoraToken: body=$body');
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: body,
    );
    print(
        '[===================AgoraService========================] getAgoraToken: response.statusCode=${response.statusCode}');
    print('[AgoraService] getAgoraToken: response.body=${response.body}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['token'];
    } else {
      throw Exception('Failed to fetch Agora token: ${response.statusCode}');
    }
  }

  /// Joins an Agora channel
  Future<void> joinChannel(
      String channelName, String userId, String token) async {
    final int uid = int.tryParse(userId) ?? 0;
    try {
      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
    } catch (e) {
      print('Error joining channel: $e');
      rethrow;
    }
  }

  /// Leaves the Agora channel
  Future<void> leaveChannel() async {
    try {
      await _engine!.leaveChannel();
    } catch (e) {
      print('Error leaving channel: $e');
      rethrow;
    }
  }

  /// Sets event handlers for Agora events
  void setEventHandler({
    required Function(int uid) onUserJoined,
    required Function(int uid) onUserOffline,
  }) {
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          onUserJoined(remoteUid); // Call the provided callback
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          onUserOffline(remoteUid); // Call the provided callback
        },
      ),
    );
  }

  /// Disposes the Agora engine
  Future<void> dispose() async {
    try {
      await _engine!.release();
      _engine = null;
    } catch (e) {
      print('Error disposing Agora engine: $e');
      rethrow;
    }
  }
}
