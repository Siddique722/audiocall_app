import 'package:agora/model/call_model.dart';
import 'package:agora/model/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<UserModel>> searchUsers(String query) {
    return _firestore
        .collection('users')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList());
  }

  Future<void> makeCall(CallModel call) async {
    // Store call with hasDialled=true for caller
    await _firestore.collection('calls').doc(call.callerId).set(call.toMap());

    // Store call with hasDialled=false for receiver
    final receiverCall = CallModel(
      callId: call.callId,
      callerId: call.callerId,
      callerName: call.callerName,
      receiverId: call.receiverId,
      receiverName: call.receiverName,
      hasDialled: false, // Set to false for receiver
    );
    await _firestore
        .collection('calls')
        .doc(call.receiverId)
        .set(receiverCall.toMap());
  }

  Future<void> endCall(String callerId, String receiverId) async {
    await _firestore.collection('calls').doc(callerId.toString()).delete();
    await _firestore.collection('calls').doc(receiverId.toString()).delete();
  }

  Stream<DocumentSnapshot> getCallStream(String uid) {
    return _firestore.collection('calls').doc(uid.toString()).snapshots();
  }

  Future<void> saveUserFromApi(Map<String, dynamic> user, String token) async {
    final userData = {
      'id': user['id'], // standardized
      'name': user['name'],
      'email': user['email'],
      'fcm_token': user['fcm_token'], // standardized
      'auth_token': token, // standardized to 'auth_token'
      'role': user['role'],
      'created_at': user['created_at'],
      'updated_at': user['updated_at'],
      'email_verified_at': user['email_verified_at'],
      'email_verification_code': user['email_verification_code'],
      'email_verification_expires_at': user['email_verification_expires_at'],
    };
    await _firestore
        .collection('users')
        .doc(user['id'].toString())
        .set(userData);
  }

  Future<void> saveUser(UserModel user) async {
    await _firestore.collection('users').doc(user.id).set(user.toMap());
  }

  Future<UserModel?> getUser(String id) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(id).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  Future<void> saveFcmToken(String id, String token) async {
    await _firestore.collection('users').doc(id).update({'fcm_token': token});
  }

  Future<void> updateFcmToken(String userId, String fcmToken) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .update({'fcm_token': fcmToken});
  }
}
