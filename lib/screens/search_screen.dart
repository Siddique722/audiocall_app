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
    final callerId = AuthService().currentUser?['id'].toString();
    final callerName = AuthService().currentUser?['name'] ?? '';
    if (callerId == null) {
      Get.snackbar('Error', 'User not logged in');
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

    try {
      await firestoreService.makeCall(call);
      await notificationService.sendCallNotification(
        receiver.id,
        callerName,
        callId,
      );
      Get.toNamed('/call', arguments: {
        'call': call,
        'channelName': channelName,
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to initiate call: $e');
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