import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stour/screens/main_screen.dart';
import 'package:stour/services/auth_service.dart';
import 'package:stour/util/const.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'package:stour/model/place.dart';
import 'firebase_options.dart';
import 'package:stour/screens/sign_in.dart';
import 'package:stour/screens/sign_up.dart';
import 'package:stour/screens/role_selection.dart';
import 'package:stour/screens/profile.dart';
import 'package:stour/screens/coupon_screen.dart';
import 'package:stour/screens/forgot_password.dart';
import 'package:stour/screens/dashboardBusiness_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:stour/screens/dashboardAdmin_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

// Import collection event screens
import 'package:stour/screens/create_collection_event.dart';
import 'package:stour/screens/collection_event_details_screen.dart';
import 'package:stour/screens/event_submission_widget.dart';
import 'package:stour/screens/collection_events.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ✅ BACKGROUND NOTIFICATION HANDLER
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // App Check tạm thời bị vô hiệu hóa - Cấu hình trên Firebase Console nếu muốn sử dụng
  // await FirebaseAppCheck.instance.activate(
  //   androidProvider: AndroidProvider.debug,
  //   appleProvider: AppleProvider.debug,
  // );
  await FirebaseMessaging.instance.requestPermission();

  FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings();

  const WindowsInitializationSettings windowsSettings =
      WindowsInitializationSettings(
    appName: 'WeGoTour',
    appUserModelId: 'com.wegotour.app',
    guid: 'b3ea77c3-e332-4bc6-9e61-59c91d63e85d',
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: iosSettings,
    windows: windowsSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.notification != null) {
      flutterLocalNotificationsPlugin.show(
        message.hashCode,
        message.notification!.title,
        message.notification!.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'default_channel',
            'Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }
  });

  getAllPlaceFoodStream('stourplace1');
  getAllPlaceFoodStream('food');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
    refreshFCMToken();
  }

  Future<void> refreshFCMToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('uid');
      if (uid == null) return;

      await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .update({
        "fcmToken": token,
      });

      print("Refreshed FCM Token: $token");
    } catch (e) {
      print("Lỗi lấy FCM Token: $e");
    }
  }

  void checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    String? role = prefs.getString('role');

    if (isLoggedIn && role != null) {
      if (role == 'business') {
        Navigator.pushReplacementNamed(context, '/menuBusiness');
      } else if (role == 'traveler') {
        Navigator.pushReplacementNamed(context, '/home');
      } else if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/menuAdmin');
      }
    } else {
      setState(() {
        _isLoggedIn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: Constants.appName,
      navigatorKey: navigatorKey,
      home:
      _isLoggedIn ? const SizedBox() : const SplashScreen(),
      theme: ThemeData(
        fontFamily: 'Montserrat',
      ),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/home':
            return MaterialPageRoute(builder: (_) => const MainScreen());
          case '/signin':
            return MaterialPageRoute(builder: (_) => const SignInScreen());
          case '/signup':
            return MaterialPageRoute(builder: (_) => const SignUpScreen());
          case '/role':
            return MaterialPageRoute(
                builder: (_) => const RoleSelectionScreen());
          case '/profile':
            return MaterialPageRoute(builder: (_) => Profile(profileId: AuthService.getCurrentUserId()!, ));
          case '/coupon':
            return MaterialPageRoute(builder: (_) => const CouponScreen());
          case '/forgot':
            return MaterialPageRoute(
                builder: (_) => const ForgotPasswordScreen());
          case '/menuBusiness':
            return MaterialPageRoute(builder: (_) => const MenuBusiness());
          case '/menuAdmin':
            return MaterialPageRoute(builder: (_) => const MenuAdmin());

          case '/create_collection_event':
            return MaterialPageRoute(
              builder: (_) => const CreateCollectionEvent(),
            );

          case '/collection_events':
            // Danh sách tất cả events
            return MaterialPageRoute(
              builder: (_) => const CollectionEventsList(),
            );

          case '/event_collection':
            // Chi tiết event - cần eventId
            final eventId = settings.arguments as String?;
            if (eventId == null) {
              return MaterialPageRoute(
                builder: (_) => const Scaffold(
                  body: Center(child: Text('Event ID không hợp lệ')),
                ),
              );
            }
            return MaterialPageRoute(
              builder: (_) => CollectionEventDetailScreen(eventId: eventId),
            );

          case '/event_submit':
            // Đăng bài tham gia event - cần eventId và keywords
            final args = settings.arguments as Map<String, dynamic>?;
            if (args == null ||
                args['eventId'] == null ||
                args['keywords'] == null) {
              return MaterialPageRoute(
                builder: (_) => const Scaffold(
                  body: Center(child: Text('Thiếu thông tin event')),
                ),
              );
            }
            return MaterialPageRoute(
              builder: (_) => EventSubmissionScreen(
                eventId: args['eventId'] as String,
                keywords: List<String>.from(args['keywords']),
              ),
            );

          default:
            // Route không tồn tại
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('404')),
                body: const Center(child: Text('Trang không tồn tại')),
              ),
            );
        }
      },
    );
  }
}
