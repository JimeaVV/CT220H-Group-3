import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/fintrack_logo.dart';
import '../../providers/app_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).register(
            displayName: _nameController.text,
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (!mounted) return;
      showAppSnackBar(context, 'Đăng ký thành công. FinTrack đã gửi email xác minh.');
      context.go('/');
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'email-already-in-use' => 'Email này đã được sử dụng.',
        'weak-password' => 'Mật khẩu chưa đủ mạnh.',
        'invalid-email' => 'Email không hợp lệ.',
        _ => error.message ?? 'Không thể đăng ký.',
      };
      showAppSnackBar(context, message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FinTrackLogo(size: 54, showName: true),
                    const SizedBox(height: 34),
                    Text(
                      'Tạo tài khoản mới.',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 26),
                    TextFormField(
                      controller: _nameController,
                      validator: (value) => Validators.requiredText(value, field: 'Tên hiển thị'),
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Tên hiển thị', prefixIcon: Icon(Icons.person_outline_rounded)),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      validator: Validators.email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      validator: Validators.password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscure,
                      validator: (value) {
                        if (value != _passwordController.text) return 'Mật khẩu nhập lại không khớp';
                        return null;
                      },
                      onFieldSubmitted: (_) => _register(),
                      decoration: const InputDecoration(
                        labelText: 'Nhập lại mật khẩu',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _register,
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Tạo tài khoản'),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Bằng việc đăng ký, bạn đồng ý lưu dữ liệu tài chính cá nhân trên Firebase của dự án.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
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
