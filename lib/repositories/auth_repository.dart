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

  Stream<User?> authStateChanges() => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail(
      {required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.reload();
    await _auth.currentUser?.reload();
    final user = _auth.currentUser ?? credential.user;
    await _syncUser(user);
    return credential;
  }

  Future<UserCredential> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final cleanName = displayName.trim();
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user != null) {
      await user.updateDisplayName(cleanName);
      await user.sendEmailVerification();
      await user.reload();
    }
    await _auth.currentUser?.reload();
    final updatedUser = _auth.currentUser ?? user;
    await _syncUser(updatedUser, customDisplayName: cleanName);
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
    await result.user?.reload();
    await _auth.currentUser?.reload();
    await _syncUser(_auth.currentUser ?? result.user);
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

  Future<void> _syncUser(User? user, {String? customDisplayName}) async {
    if (user == null) return;

    String resolvedName = '';
    if (customDisplayName != null && customDisplayName.trim().isNotEmpty) {
      resolvedName = customDisplayName.trim();
    } else if (user.displayName != null &&
        user.displayName!.trim().isNotEmpty) {
      resolvedName = user.displayName!.trim();
    }

    // Nếu Firebase Auth chưa có displayName, thử đọc tên đã lưu ở Backend
    if (resolvedName.isEmpty) {
      try {
        final response = await _dio.get('/users/${user.uid}');
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data['data'];
          if (data != null &&
              data['displayName'] != null &&
              (data['displayName'] as String).trim().isNotEmpty) {
            resolvedName = (data['displayName'] as String).trim();
          }
        }
      } catch (_) {
        // Backend GET lỗi hoặc không phản hồi
      }
    }

    // Giá trị dự phòng nếu cả Firebase và Backend chưa lưu tên
    if (resolvedName.isEmpty) {
      resolvedName = user.email?.split('@').first ?? 'Người dùng';
    }

    // Nếu trong Firebase Auth của SDK chưa có displayName, cập nhật lại
    if (resolvedName.isNotEmpty &&
        (user.displayName == null || user.displayName!.trim().isEmpty)) {
      try {
        await user.updateDisplayName(resolvedName);
        await user.reload();
      } catch (_) {}
    }

    try {
      await _dio.post(
        '/users/${user.uid}',
        data: {
          'email': user.email ?? '',
          'displayName': resolvedName,
        },
      );
    } on DioException {
      // Đăng nhập vẫn hợp lệ khi backend tạm thời offline. Các màn hình dữ liệu
      // sẽ hiển thị lỗi kết nối và cho phép tải lại sau.
    }
  }
}
