import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/fintrack_logo.dart';
import '../../providers/app_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithEmail(
            email: _emailController.text,
            password: _passwordController.text,
          );
    } on FirebaseAuthException catch (error) {
      if (mounted) showAppSnackBar(context, _authMessage(error), isError: true);
    } catch (error) {
      if (mounted)
        showAppSnackBar(context, mapApiException(error).message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on FirebaseAuthException catch (error) {
      if (mounted) showAppSnackBar(context, _authMessage(error), isError: true);
    } catch (error) {
      if (mounted) showAppSnackBar(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final controller =
        TextEditingController(text: _emailController.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khôi phục mật khẩu'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Gửi email'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty) return;

    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (mounted)
        showAppSnackBar(context, 'Đã gửi liên kết đặt lại mật khẩu.');
    } on FirebaseAuthException catch (error) {
      if (mounted) showAppSnackBar(context, _authMessage(error), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                        alignment: Alignment.centerLeft,
                        child: FinTrackLogo(size: 60, showName: true)),
                    const SizedBox(height: 46),
                    Text(
                      'Chào mừng trở lại.',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.1,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Theo dõi tiền bạc rõ ràng, không rườm rà.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      validator: Validators.email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      validator: Validators.password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _signIn(),
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed: _loading ? null : _resetPassword,
                          child: const Text('Quên mật khẩu?')),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _loading ? null : _signIn,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Đăng nhập'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('hoặc',
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _googleSignIn,
                      icon: const Text('G',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 18)),
                      label: const Text('Tiếp tục bằng Google'),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Chưa có tài khoản?'),
                        TextButton(
                            onPressed: () => context.push('/register'),
                            child: const Text('Đăng ký')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _authMessage(FirebaseAuthException error) {
  return switch (error.code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' =>
      'Email hoặc mật khẩu không đúng.',
    'invalid-email' => 'Email không hợp lệ.',
    'user-disabled' => 'Tài khoản này đã bị vô hiệu hóa.',
    'too-many-requests' => 'Thao tác quá nhiều lần. Hãy thử lại sau.',
    'network-request-failed' => 'Không có kết nối mạng.',
    'missing-google-id-token' => error.message ?? 'Thiếu Google ID token.',
    _ => error.message ?? 'Đăng nhập không thành công.',
  };
}
