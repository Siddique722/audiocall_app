import 'package:agora/model/call_model.dart';
import 'package:agora/services/auth_services.dart';
import 'package:agora/services/fire_store.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService authService = AuthService();
  final FirestoreService firestoreService = FirestoreService();
  final NotificationService notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    notificationService.initialize();
    // Listen for incoming calls
    final userId = authService.currentUser?['id'].toString();
    if (userId == null) return;
    firestoreService.getCallStream(userId).listen((snapshot) {
      if (snapshot.exists) {
        final call = CallModel.fromMap(snapshot.data() as Map<String, dynamic>);
        // Check if we are the receiver
        if (call.receiverId == userId && !call.hasDialled) {
          // Show incoming call screen for receiver
          Get.toNamed('/incoming_call', arguments: {
            'callerName': call.callerName,
            'onAccept': () {
              Get.back(); // Close incoming call screen
              Get.toNamed('/call', arguments: {
                'call': call,
                'channelName': call.callId,
              });
            },
            'onDecline': () async {
              await firestoreService.endCall(call.callerId, call.receiverId);
              Get.back(); // Close incoming call screen
            },
          });
        } else if (call.callerId == userId && call.hasDialled) {
          // Caller should go directly to call screen
          Get.toNamed('/call', arguments: {
            'call': call,
            'channelName': call.callId,
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Call App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              Get.offAllNamed('/login');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome to Audio Call App!',
                style: TextStyle(fontSize: 24)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Get.toNamed('/search'),
              child: const Text('Search Users to Call'),
            ),
          ],
        ),
      ),
    );
  }
}
// class HomeScreen extends StatelessWidget {
//   final AuthService authService = AuthService();
//   final NotificationService notificationService = NotificationService();
//
//   HomeScreen({super.key}) {
//     notificationService.initialize();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Audio Call App'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.logout),
//             onPressed: () async {
//               await authService.signOut();
//               Get.offAllNamed('/login');
//             },
//           ),
//         ],
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Text('Welcome to Audio Call App!', style: TextStyle(fontSize: 24)),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: () => Get.toNamed('/search'),
//               child: const Text('Search Users to Call'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }