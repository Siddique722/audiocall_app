// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'fire_store.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class AuthService {
//   final FirestoreService _firestoreService = FirestoreService();

//   // Save user ID and token to SharedPreferences
//   Future<void> saveUserToPrefs(String id, String token) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('user_id', id);
//     await prefs.setString('auth_token', token);
//   }

//   // Get user ID from SharedPreferences
//   Future<String?> getUserId() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString('user_id');
//   }

//   // Get token from SharedPreferences
//   Future<String?> getToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString('auth_token');
//   }

//   // Clear user ID and token from SharedPreferences
//   Future<void> clearUserPrefs() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove('user_id');
//     await prefs.remove('auth_token');
//   }

//   Future<bool> login(String email, String password, String fcmToken) async {
//     try {
//       final response = await http.post(
//         Uri.parse('https://etalk.mtai.live/api/user/login'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({
//           'email': email,
//           'password': password,
//           'fcm_token': fcmToken,
//         }),
//       );
//       final data = jsonDecode(response.body);
//       print('-------------login successfully------------------');
//       print(data);
//       print('-------------login successfully------------------');
//       print("token=======${data['token']}");
//       print("user=======${data['user']}");

//       if (data['status'] == 'success') {
//         _token = data['token'];
//         String id = data['user']['id'].toString();
//         print("id=======$id");
//         _currentUser = data['user'];
//         await _firestoreService.saveUserFromApi(data['user'], data['token']);
//         await saveUserToPrefs(id, _token!); // Save to SharedPreferences
//         return true;
//       } else {
//         throw Exception(data['message'] ?? 'Login failed');
//       }
//     } catch (e) {
//       rethrow;
//     }
//   }

//   Future<bool> signup(String name, String email, String password,
//       String confirmPassword) async {
//     try {
//       final response = await http.post(
//         Uri.parse('https://etalk.mtai.live/api/user/register'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({
//           'name': name,
//           'email': email,
//           'password': password,
//           'confirm_password': confirmPassword,
//         }),
//       );
//       final data = jsonDecode(response.body);
//       if (data['status'] == 'success') {
//         //_token = data['token'];
//         String id = data['user']['id'].toString();
//         //  _currentUser = data['user'];
//         await _firestoreService.saveUserFromApi(data['user'], data['token']);
//         await saveUserToPrefs(id, data['token']!); // Save to SharedPreferences
//         return true;
//       } else {
//         throw Exception(data['message'] ?? 'Signup failed');
//       }
//     } catch (e) {
//       rethrow;
//     }
//   }

//   Future<void> signOut() async {
//     _token = null;
//     _currentUser = null;
//     await clearUserPrefs(); // Clear from SharedPreferences
//   }
// }

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'fire_store.dart';

class AuthService {
  final FirestoreService _firestoreService = FirestoreService();
  String? _token; // Store the auth token
  Map<String, dynamic>? _currentUser; // Store the user data

  AuthService() {
    // Initialize by fetching token and user ID from SharedPreferences
    _loadUserFromPrefs();
  }

  // Load user ID and token from SharedPreferences during initialization
  Future<void> _loadUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userId = prefs.getString('user_id');
    if (userId != null && _token != null) {
      // Optionally fetch user data from Firestore if needed
      final user = await _firestoreService.getUser(userId);
      if (user != null) {
        _currentUser = user.toMap();
      }
    }
  }

  // Save user ID, token, and FCM token to SharedPreferences
  Future<void> saveUserToPrefs(String id, String token, String fcmToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('id', id); // standardized to 'id'
    await prefs.setString('auth_token', token); // standardized to 'auth_token'
    await prefs.setString('fcm_token', fcmToken); // standardized to 'fcm_token'
    print(
        '---========------=-=-=-=-=-=-=-=-=-=-=-SHARED PREFERENCES FCM TOKEN=${fcmToken}');
    // Also update FCM token in Firestore
    await _firestoreService.updateFcmToken(id, fcmToken);
  }

  // Get user ID from SharedPreferences
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('id'); // standardized to 'id'
  }

  // Get token from SharedPreferences
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token'); // standardized to 'auth_token'
  }

  // Get FCM token from SharedPreferences
  Future<String?> getFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token'); // standardized to 'fcm_token'
  }

  // Clear user ID, token, and FCM token from SharedPreferences
  Future<void> clearUserPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('id'); // standardized to 'id'
    await prefs.remove('auth_token'); // standardized to 'auth_token'
    await prefs.remove('fcm_token'); // standardized to 'fcm_token'
  }

  // Getter for current user
  Map<String, dynamic>? get currentUser => _currentUser;

  // Getter for token
  String? get token => _token;

  Future<bool> login(String email, String password) async {
    try {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) throw Exception('Unable to get FCM token');
      final response = await http.post(
        Uri.parse('https://etalk.mtai.live/api/user/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'fcm_token': fcmToken, // Always send FCM token to backend
        }),
      );
      final data = jsonDecode(response.body);
      print('[LOGIN] Backend response:');
      print(data);
      if (data['status'] == 'success') {
        _token = data['token'];
        String id = data['user']['id'].toString();
        _currentUser = data['user'];
        // Always use local FCM token for Firestore
        final userMap = Map<String, dynamic>.from(data['user']);
        userMap['fcm_token'] = fcmToken;
        print('[LOGIN] User map to save in Firestore:');
        userMap.forEach((k, v) => print('  $k: $v'));
        await _firestoreService.saveUserFromApi(userMap, _token!);
        print('[LOGIN] Saved user in Firestore.');
        await saveUserToPrefs(
            id, _token!, fcmToken); // Always use local fcmToken
        print(
            '[LOGIN] Saved user in SharedPreferences: id=$id, auth_token=$_token, fcm_token=$fcmToken');
        return true;
      } else {
        throw Exception(data['message'] ?? 'Login failed');
      }
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  Future<bool> signup(String name, String email, String password,
      String confirmPassword) async {
    try {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) throw Exception('Unable to get FCM token');
      final response = await http.post(
        Uri.parse('https://etalk.mtai.live/api/user/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'confirm_password': confirmPassword,
          'fcm_token': fcmToken, // Always send FCM token to backend
        }),
      );
      final data = jsonDecode(response.body);
      print('[SIGNUP] Backend response:');
      print(data);
      if (data['status'] == 'success') {
        _token = data['token'];
        String id = data['user']['id'].toString();
        _currentUser = data['user'];
        // Always use local FCM token for Firestore
        final userMap = Map<String, dynamic>.from(data['user']);
        userMap['fcm_token'] = fcmToken;
        print('[SIGNUP] User map to save in Firestore:');
        userMap.forEach((k, v) => print('  $k: $v'));
        await _firestoreService.saveUserFromApi(userMap, _token!);
        print('[SIGNUP] Saved user in Firestore.');
        await saveUserToPrefs(
            id, _token!, fcmToken); // Always use local fcmToken
        print(
            '[SIGNUP] Saved user in SharedPreferences: id=$id, auth_token=$_token, fcm_token=$fcmToken');
        return true;
      } else {
        throw Exception(data['message'] ?? 'Signup failed');
      }
    } catch (e) {
      print('Signup error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    _token = null;
    _currentUser = null;
    await clearUserPrefs(); // Clear from SharedPreferences
  }
}
