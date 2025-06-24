import 'package:agora/model/call_model.dart';
import 'package:agora/screens/login_screen/login_screen.dart';
import 'package:agora/screens/login_screen/signup_screen.dart';
import 'package:agora/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/call_screen.dart';
import 'screens/incoming_call_screen.dart';
import 'services/auth_services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final token = authService.token;
    final initialRoute =
        (token != null && token.isNotEmpty) ? '/home' : '/login';

    return GetMaterialApp(
      title: 'Audio Call App',
      theme: appTheme(),
      initialRoute: initialRoute, // Home if token, else login
      getPages: [
        GetPage(name: '/login', page: () => LoginScreen()),
        GetPage(name: '/signup', page: () => SignUpScreen()),
        GetPage(name: '/home', page: () => HomeScreen()),
        GetPage(name: '/search', page: () => const SearchScreen()),
        GetPage(
          name: '/call',
          page: () {
            final args = Get.arguments as Map<String, dynamic>;
            return CallScreen(
              call: args['call'] as CallModel,
              channelName: args['channelName'] as String,
            );
          },
        ),
        GetPage(
          name: '/incoming_call',
          page: () {
            final args = Get.arguments as Map<String, dynamic>;
            return IncomingCallScreen(
              callerName: args['callerName'] as String,
              onAccept: args['onAccept'] as VoidCallback,
              onDecline: args['onDecline'] as VoidCallback,
              errorMessage: args['errorMessage'] as String?,
            );
          },
        ),
        // Example notification screen route:
        // GetPage(
        //   name: '/notifications',
        //   page: () {
        //     final authService = AuthService();
        //     final userId = authService.currentUser?['id']?.toString();
        //     return NotificationScreen(userId: userId);
        //   },
        // ),
      ],
    );
  }
}
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return GetMaterialApp(
//       title: 'Audio Call App',
//       theme: appTheme(),
//       initialRoute: '/login',
//       getPages: [
//         GetPage(name: '/login', page: () => LoginScreen()),
//         GetPage(name: '/signup', page: () => SignUpScreen()),
//         GetPage(name: '/home', page: () => HomeScreen()),
//         GetPage(name: '/search', page: () => const SearchScreen()),
//         GetPage(
//           name: '/call',
//           page: () {
//             // Retrieve arguments passed during navigation
//             final args = Get.arguments as Map<String, dynamic>;
//             return CallScreen(
//               call: args['call'] as CallModel,
//               channelName: args['channelName'] as String,
//             );
//           },
//         ),
//       ],
//     );
//   }
// }