import 'dart:convert';
import 'package:http/http.dart' as http;
import 'fire_store.dart';

class AuthService {
  final FirestoreService _firestoreService = FirestoreService();

  Map<String, dynamic>? _currentUser;
  String? _token;

  Map<String, dynamic>? get currentUser => _currentUser;
  String? get token => _token;

  Future<bool> login(String email, String password, String fcmToken) async {
    try {
      final response = await http.post(
        Uri.parse('https://etalk.mtai.live/api/user/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'fcm_token': fcmToken,
        }),
      );
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        _token = data['token'];
        _currentUser = data['user'];
        await _firestoreService.saveUserFromApi(data['user'], data['token']);
        return true;
      } else {
        throw Exception(data['message'] ?? 'Login failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> signup(String name, String email, String password,
      String confirmPassword) async {
    try {
      final response = await http.post(
        Uri.parse('https://etalk.mtai.live/api/user/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'confirm_password': confirmPassword,
        }),
      );
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        _token = data['token'];
        _currentUser = data['user'];
        await _firestoreService.saveUserFromApi(data['user'], data['token']);
        return true;
      } else {
        throw Exception(data['message'] ?? 'Signup failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    _token = null;
    _currentUser = null;
  }
}
