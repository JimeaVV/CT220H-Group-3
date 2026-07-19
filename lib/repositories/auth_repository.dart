import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  AuthRepository({required FirebaseAuth auth, required Dio dio})
      : _auth = auth,
        _dio = dio;

  final FirebaseAuth _auth;
  final Dio _dio;
  bool _googleInitialized = false;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _syncUser(credential.user);
    return credential;
  }

  Future<UserCredential> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(displayName.trim());
    await credential.user?.sendEmailVerification();
    await credential.user?.reload();
    await _syncUser(_auth.currentUser);
    return credential;
  }

  Future<UserCredential> signInWithGoogle() async {
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleInitialized = true;
    }

    final googleUser = await GoogleSignIn.instance.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google không trả về ID token. Hãy kiểm tra cấu hình SHA-1.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _auth.signInWithCredential(credential);
    await _syncUser(result.user);
    return result;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> reloadUser() => _auth.currentUser?.reload() ?? Future.value();

  Future<void> signOut() async {
    await _auth.signOut();
    if (_googleInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Firebase đã đăng xuất thành công; lỗi Google ở đây không nên chặn luồng.
      }
    }
  }

  Future<void> _syncUser(User? user) async {
    if (user == null) return;
    try {
      await _dio.post(
        '/users/${user.uid}',
        data: {
          'email': user.email ?? '',
          'displayName': user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : (user.email?.split('@').first ?? 'Người dùng'),
        },
      );
    } on DioException {
      // Đăng nhập vẫn hợp lệ khi backend tạm thời offline. Các màn hình dữ liệu
      // sẽ hiển thị lỗi kết nối và cho phép tải lại sau.
    }
  }
}
