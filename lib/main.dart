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

  // ✅ INIT FIREBASE
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ XIN QUYỀN THÔNG BÁO (BẮT BUỘC)
  await FirebaseMessaging.instance.requestPermission();

  // ✅ BACKGROUND HANDLER
  FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler);

  // ✅ LOCAL NOTIFICATION INIT
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

  // ✅ LẮNG NGHE THÔNG BÁO KHI APP ĐANG MỞ (FOREGROUND)
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
    refreshFCMToken(); // ✅ TỰ ĐỘNG REFRESH TOKEN
  }

  // ✅ REFRESH & LƯU FCM TOKEN KHI MỞ APP
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

      print("✅ Refreshed FCM Token: $token");
    } catch (e) {
      print("❌ Lỗi lấy FCM Token: $e");
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
      routes: {
        '/home': (context) => const MainScreen(),
        '/signin': (context) => const SignInScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/role': (context) => const RoleSelectionScreen(),
        '/profile': (context) =>
            Profile(profileId: AuthService.getCurrentUserId()!),
        '/coupon': (context) => const CouponScreen(),
        '/forgot': (context) => const ForgotPasswordScreen(),
        '/menuBusiness': (context) => const MenuBusiness(),
        '/menuAdmin': (context) => const MenuAdmin(),
      },
    );
  }
}
