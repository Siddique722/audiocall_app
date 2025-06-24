import 'package:agora/contabts/constants.dart';
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
    final int uid = int.tryParse(userId) ?? 0;
    try {
      final response = await http.get(
        Uri.parse(
            '${Constants.laravelApiBaseUrl}/access_token?channelName=$channelName&uid=$uid'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiI5ZWNhZTVhMC0wNWE4LTQ1NjItYTYwMC0zMjBjNTA1YWVhYmYiLCJqdGkiOiIxMDNkZmY3MTA5YWNkY2VjZjExOGM1MWNlMDg5ODUwNTNlMjA4NDBkNjc2Zjg2M2Y0OTVkMTEyYjI3YWZkOGJiNTAzMmM5OWNmNzQyZmNjOSIsImlhdCI6MTc0Njk0OTMxNC43NTQ4NDIsIm5iZiI6MTc0Njk0OTMxNC43NTQ4NDQsImV4cCI6MTc2Mjg0NjkxNC43NTExMjEsInN1YiI6IjM1Iiwic2NvcGVzIjpbXX0.0ocKK_vNe4BFOFj7x8tEOJCWLHIZMlUfyZ8lfognVqzHwx_Scv6vDEtQizDajSbIGfZA1ZMtPBP9pW1eGQtrEvbY7dwd5A5OeeXyUtNdSQt0rwUDGz8a_Q7Bx1hYt3DlQtCTo9Sb5W5OzH6J4nzFH6RaL9mPpU_vY4z5ApCxw5OaifIb9Z9_Bzw7zeCjVXklIxShI9RfFMyR6ekAVUBShbBj8eVAhxLUtuuC5z1NXdOBuXE53CuPhL0nH795ydn8s5KCTt4peapOigMii47EbhCpl-d07_LC2yy53-xyjUkpnhxA10N_Ws6JYJpWC3dHm6_YWibX5aXeNRkAgn2_24AUdENzE_5gu50REgTHPrYgp2OBaL67Hu1xRYywSN-B9BB0ujvpBkcyjRXuCT-yNGrLh3B3Jzun0Diz2Ims_YqhU2mtt6HbY6at4zUFyhGABV99hKxBMTvVsok9xzrBHDWRNcZf28IOyQInpExzXAc0z9IecK8hvFcyfXI2jT_5c0IMRkzMJlSzgdFMftM0KMV4OagU1KBBZEQBzJ7t6aKSKXFlf_IZeKPdNS9Wb78t0PKcQkijD_RggkNPyn7q_eJVGpWYutwFZ0HjNK2jEgkiJV3JkcOPv2ln-YCw0Mhez-xyBc9P-XIHROzGO26l-x9SlLia_exETurqkU3aG3E'
        },
      );
      if (response.statusCode == 200) {
        print('agora toke:-${response.body}');
        return jsonDecode(response.body)['token'];
      } else {
        throw Exception('Failed to fetch Agora token: ${response.statusCode}');
      }
    } catch (e) {
      log('Error fetching Agora token: $e');
      rethrow;
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
