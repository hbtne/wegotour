import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stour/screens/main_screen.dart';
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

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings iosSettings =
  DarwinInitializationSettings();

  const WindowsInitializationSettings windowsSettings = WindowsInitializationSettings(
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

  getAllPlaceFoodStream('stourplace1');
  getAllPlaceFoodStream('food');
  // const GoogleMapsController();
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
        _isLoggedIn = false; // Show SplashScreen
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: Constants.appName,
      home: _isLoggedIn ? const SizedBox() : const SplashScreen(), // dùng SizedBox rỗng để chờ checkLoginStatus
      theme: ThemeData(
        fontFamily: 'Montserrat',
      ),
      routes: {
        '/home': (context) => const MainScreen(),
        '/signin': (context) => const SignInScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/role': (context) => const RoleSelectionScreen(),
        '/profile': (context) => const Profile(),
        '/coupon': (context) => const CouponScreen(),
        '/forgot': (context) => const ForgotPasswordScreen(),
        '/menuBusiness': (context) => const MenuBusiness(),
        '/menuAdmin': (context) => const MenuAdmin(),
      },
    );
  }
}
