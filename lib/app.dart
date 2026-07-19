import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/fintrack_logo.dart';
import 'features/auth/auth_gate.dart';
import 'features/auth/register_screen.dart';
import 'features/budgets/budgets_screen.dart';
import 'features/categories/categories_screen.dart';
import 'features/recurring/recurring_screen.dart';
import 'features/transactions/transaction_form_screen.dart';
import 'features/wallets/wallets_screen.dart';
import 'models/transaction_model.dart';
import 'providers/app_providers.dart';

class FinTrackApp extends ConsumerStatefulWidget {
  const FinTrackApp({
    super.key,
    required this.firebaseReady,
    this.firebaseError,
  });

  final bool firebaseReady;
  final Object? firebaseError;

  @override
  ConsumerState<FinTrackApp> createState() => _FinTrackAppState();
}

class _FinTrackAppState extends ConsumerState<FinTrackApp> {
  late final GoRouter _router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const AuthGate()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/transaction/new',
        builder: (_, __) => const TransactionFormScreen(),
      ),
      GoRoute(
        path: '/transaction/edit',
        builder: (_, state) => TransactionFormScreen(
          transaction: state.extra as TransactionModel?,
        ),
      ),
      GoRoute(path: '/categories', builder: (_, __) => const CategoriesScreen()),
      GoRoute(path: '/wallets', builder: (_, __) => const WalletsScreen()),
      GoRoute(path: '/budgets', builder: (_, __) => const BudgetsScreen()),
      GoRoute(path: '/recurring', builder: (_, __) => const RecurringScreen()),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);

    if (!widget.firebaseReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppConfig.appName,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        home: FirebaseSetupScreen(error: widget.firebaseError),
      );
    }

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      routerConfig: _router,
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key, this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                children: [
                  const FinTrackLogo(size: 84, showName: true),
                  const SizedBox(height: 36),
                  Text(
                    'Cần cấu hình Firebase Android',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Thêm ứng dụng Android com.ct220h.fintrack trong Firebase, đặt google-services.json vào android/app rồi chạy lại ứng dụng.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: SelectableText(
                        error?.toString() ?? 'Firebase.initializeApp() chưa thành công.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Hướng dẫn chi tiết có trong README.md và docs/FIREBASE_SETUP.md.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
