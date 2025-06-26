import 'package:agora/model/call_model.dart';
import 'package:agora/services/auth_services.dart';
import 'package:agora/services/fire_store.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    _setupCallListener();
  }

  Future<void> _setupCallListener() async {
    final userId = await AuthService().getUserId();
    print('[CALL LISTENER] My userId: $userId');
    if (userId == null) return;
    firestoreService.getCallStream(userId).listen((snapshot) {
      print(
          '[CALL LISTENER] Firestore snapshot for userId=$userId: exists=${snapshot.exists}');
      if (snapshot.exists) {
        print('[CALL LISTENER] Call snapshot data:');
        print(snapshot.data());
        final call = CallModel.fromMap(snapshot.data() as Map<String, dynamic>);
        print('[CALL LISTENER] CallModel fields:');
        call.toMap().forEach((k, v) => print('  $k: $v'));
        // Check if we are the receiver
        if (call.receiverId == userId && !call.hasDialled) {
          print(
              '[CALL LISTENER] This device is the receiver. Showing incoming call screen.');
          // Show incoming call screen for receiver
          Get.toNamed('/incoming_call', arguments: {
            'callerName': call.callerName,
            'onAccept': () {
              print(
                  '[CALL LISTENER] Call accepted. Navigating to call screen.');
              Get.back(); // Close incoming call screen
              Get.toNamed('/call', arguments: {
                'call': call,
                'channelName': call.callId,
              });
            },
            'onDecline': () async {
              print('[CALL LISTENER] Call declined. Ending call.');
              await firestoreService.endCall(call.callerId, call.receiverId);
              Get.back(); // Close incoming call screen
            },
          });
        } else if (call.callerId == userId && call.hasDialled) {
          print(
              '[CALL LISTENER] This device is the caller. Navigating to call screen.');
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
    return FutureBuilder<Map<String, dynamic>?>(
      future: authService.getUserId().then((id) async {
        if (id == null) return null;
        final user = await firestoreService.getUser(id);
        return user;
      }),
      builder: (context, snapshot) {
        final user = snapshot.data;
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Home',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            centerTitle: true,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFff9800), Color(0xFFff5722)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFff9800), Color(0xFFff5722)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 60, color: Colors.orange[700]),
                ),
                const SizedBox(height: 16),
                Text(
                  user?['name'] ?? 'User',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  user?['email'] ?? '',
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 32),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.search, color: Colors.orange[700]),
                          title: const Text('Search Users',
                              style:
                                  TextStyle(fontWeight: FontWeight.bold)),
                          trailing:
                              Icon(Icons.arrow_forward_ios, color: Colors.orange[700]),
                          onTap: () => Get.toNamed('/search'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Icon(Icons.logout, color: Colors.red[400]),
                          title: const Text('Logout',
                              style:
                                  TextStyle(fontWeight: FontWeight.bold)),
                          trailing:
                              Icon(Icons.exit_to_app, color: Colors.red[400]),
                          onTap: () async {
                            await authService.logout();
                            Get.offAllNamed('/login');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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