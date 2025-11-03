import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 🔹 Lấy user hiện tại (nếu đã đăng nhập)
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// 🔹 Lấy UID của user hiện tại
  static String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// 🔹 Lấy displayName của user hiện tại
  static String? getCurrentUserName() {
    return _auth.currentUser?.displayName;
  }

  static String? getCurrentUserAvatar() {
    return _auth.currentUser?.photoURL;
  }

  /// 🔹 Lấy email của user hiện tại
  static String? getCurrentUserEmail() {
    return _auth.currentUser?.email;
  }

  /// 🔹 Đăng xuất user hiện tại
  static Future<void> signOut() async {
    await _auth.signOut();
  }
}
