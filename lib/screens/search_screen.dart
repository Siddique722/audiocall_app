import 'package:agora/model/call_model.dart';
import 'package:agora/model/user_model.dart';
import 'package:agora/screens/call_screen.dart';
import 'package:agora/services/auth_services.dart';
import 'package:agora/services/fire_store.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/agora_service.dart';
import '../../services/notification_service.dart';
import 'package:uuid/uuid.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchController = TextEditingController();
  final FirestoreService firestoreService = FirestoreService();
  final AgoraService agoraService = AgoraService();
  final NotificationService notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Search Users'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(children: [
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Enter user name',
                suffixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() {}),
            ),
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: firestoreService.searchUsers(searchController.text),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No users found'));
                  }
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final user = snapshot.data![index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(user.name),
                        subtitle: Text(user.email),
                        trailing: IconButton(
                          icon: const Icon(Icons.call),
                          color: Colors.teal,
                          onPressed: () => initiateCall(user),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ]),
        ));
  }

  void initiateCall(UserModel receiver) async {
    // Debug log: receiver object
    print('[DEBUG] initiateCall called with receiver:');
    receiver.toMap().forEach((k, v) => print('  $k: $v'));

    // Validate receiver ID and name (only check for empty)
    if (receiver.id.isEmpty) {
      print('[ERROR] Receiver ID is empty.');
      Get.snackbar(
          'Error', 'Receiver information is invalid. Please try again.',
          backgroundColor: Colors.white, colorText: Colors.red);
      return;
    }
    if (receiver.name.isEmpty) {
      print('[ERROR] Receiver name is empty.');
      Get.snackbar(
          'Error', 'Receiver information is incomplete. Please try again.',
          backgroundColor: Colors.white, colorText: Colors.red);
      return;
    }

    final callerId = await AuthService().getUserId(); // standardized to 'id'
    final callerName = AuthService().currentUser?['name'] ?? '';
    final fcmToken =
        await AuthService().getFcmToken(); // standardized to 'fcm_token'
    print('[DEBUG] Caller info:');
    print('  id: $callerId');
    print('  name: $callerName');
    print('  fcm_token: $fcmToken');

    if (callerId == null || callerId.isEmpty) {
      print('[ERROR] Caller ID is missing.');
      Get.snackbar('Error', 'User not logged in',
          backgroundColor: Colors.white, colorText: Colors.red);
      return;
    }
    if (fcmToken == null || fcmToken.isEmpty) {
      print('[ERROR] Caller FCM token is missing.');
      Get.snackbar('Error', 'Your FCM token is missing. Please try again.',
          backgroundColor: Colors.white, colorText: Colors.red);
      return;
    }

    // Always update your FCM token in Firestore before making a call
    try {
      await FirestoreService().updateFcmToken(callerId, fcmToken);
      print('[DEBUG] Updated caller FCM token in Firestore.');
    } catch (e) {
      print('[ERROR] Failed to update FCM token in Firestore: $e');
      Get.snackbar(
          'Error', 'Failed to update your FCM token. Please try again.',
          backgroundColor: Colors.white, colorText: Colors.red);
      return;
    }

    final callId = const Uuid().v1();
    final channelName = callId;
    final call = CallModel(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      receiverId: receiver.id,
      receiverName: receiver.name,
      hasDialled: true,
    );
    print('[DEBUG] CallModel created:');
    call.toMap().forEach((k, v) => print('  $k: $v'));

    try {
      // Check if receiver has FCM token
      final receiverUser = await FirestoreService().getUser(receiver.id);
      if (receiverUser == null) {
        print(
            '[ERROR] Receiver user document not found in Firestore for id: ${receiver.id}');
        Get.snackbar('Error',
            'Receiver is not registered or available for calls. Please try again later.',
            backgroundColor: Colors.white, colorText: Colors.red);
        return;
      }
      print('[DEBUG] Receiver Firestore user document:');
      receiverUser.toMap().forEach((k, v) => print('  $k: $v'));
      final receiverFcmToken =
          receiverUser.toMap()['fcm_token']; // standardized to 'fcm_token'
      print('[DEBUG] Receiver FCM token: $receiverFcmToken');
      if (receiverFcmToken == null || receiverFcmToken.isEmpty) {
        print('[ERROR] Receiver FCM token is missing.');
        Get.snackbar('Error',
            'Receiver is not available for calls right now. Please try again later. (No FCM token)',
            backgroundColor: Colors.white, colorText: Colors.red);
        return;
      }
      await FirestoreService().makeCall(call);
      print('[DEBUG] Call document created in Firestore.');
      await NotificationService().sendCallNotification(
        receiver.id,
        callerName,
        callId,
      );
      print('[DEBUG] Call notification sent to receiver.');
      Get.toNamed('/call', arguments: {
        'call': call,
        'channelName': channelName,
      });
    } catch (e, stack) {
      print('[ERROR] Failed to initiate call: $e\n$stack');
      Get.snackbar('Error', 'Failed to initiate call. Please try again later.',
          backgroundColor: Colors.white, colorText: Colors.red);
    }
  }
}
// class SearchScreen extends StatefulWidget {
//   const SearchScreen({super.key});
//
//   @override
//   _SearchScreenState createState() => _SearchScreenState();
// }
//
// class _SearchScreenState extends State<SearchScreen> {
//   final TextEditingController searchController = TextEditingController();
//   final FirestoreService firestoreService = FirestoreService();
//   final AgoraService agoraService = AgoraService();
//   final NotificationService notificationService = NotificationService();
//   final AuthService authService=AuthService();
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Search Users'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             TextField(
//               controller: searchController,
//               decoration: const InputDecoration(
//                 labelText: 'Enter user name',
//                 suffixIcon: Icon(Icons.search),
//               ),
//               onChanged: (value) => setState(() {}),
//             ),
//             const SizedBox(height: 20),
//             Expanded(
//               child: StreamBuilder<List<UserModel>>(
//                 stream: firestoreService.searchUsers(searchController.text),
//                 builder: (context, snapshot) {
//                   if (snapshot.connectionState == ConnectionState.waiting) {
//                     return const Center(child: CircularProgressIndicator());
//                   }
//                   if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                     return const Center(child: Text('No users found'));
//                   }
//                   return ListView.builder(
//                     itemCount: snapshot.data!.length,
//                     itemBuilder: (context, index) {
//                       final user = snapshot.data![index];
//                       return ListTile(
//                           leading: const CircleAvatar(child: Icon(Icons.person)),
//                           title: Text(user.name),
//                           subtitle: Text(user.email),
//                           trailing: IconButton(
//                               icon:  Icon(Icons.call),
//                               color: Colors.teal,
//                                onPressed: () => initiateCall(user),
//                       ),
//                       );
//                     },
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void initiateCall(UserModel receiver) async {
//     final caller = await firestoreService.getUser(authService.currentUser!.uid);
//     final callId = const Uuid().v1();
//     final channelName = callId;
//     final call = CallModel(
//       callId: callId,
//       callerId: caller!.uid,
//       callerName: caller.name,
//       receiverId: receiver.uid,
//       receiverName: receiver.name,
//       hasDialled: true,
//     );
//
//     await firestoreService.makeCall(call);
//     await notificationService.sendCallNotification(
//       receiver.email, // Replace with FCM token in production
//       caller.name,
//       callId,
//     );
//
//     Get.to(() => CallScreen(call: call, channelName: channelName));
//   }
// }