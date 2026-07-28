import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_config.dart';
import '../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final mode = ref.watch(themeModeProvider);
    final effectiveDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      appBar: AppBar(title: const Text('Cá nhân')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 110),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 31,
                    backgroundImage: user.photoURL == null
                        ? null
                        : NetworkImage(user.photoURL!),
                    child: user.photoURL == null
                        ? Text(
                            (user.displayName?.trim().isNotEmpty == true
                                    ? user.displayName!.trim()[0]
                                    : 'F')
                                .toUpperCase(),
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w900),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName?.trim().isNotEmpty == true
                              ? user.displayName!.trim()
                              : 'Người dùng FinTrack',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(user.email ?? '',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              user.emailVerified
                                  ? Icons.verified_rounded
                                  : Icons.info_outline_rounded,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              user.emailVerified
                                  ? 'Email đã xác minh'
                                  : 'Email chưa xác minh',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!user.emailVerified) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.mark_email_unread_outlined),
                title: const Text('Xác minh email'),
                subtitle:
                    const Text('Gửi lại thư xác minh đến email hiện tại.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  try {
                    await ref
                        .read(authRepositoryProvider)
                        .sendVerificationEmail();
                    if (context.mounted)
                      showAppSnackBar(context, 'Đã gửi email xác minh.');
                  } catch (error) {
                    if (context.mounted)
                      showAppSnackBar(context, error.toString(), isError: true);
                  }
                },
              ),
            ),
          ],
          const SizedBox(height: 24),
          const SectionHeader(title: 'Quản lý'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                _SettingsTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Ví tiền',
                    subtitle: 'Tạo, chỉnh sửa và chuyển tiền giữa các ví',
                    onTap: () => context.push('/wallets')),
                const Divider(height: 1),
                _SettingsTile(
                    icon: Icons.category_outlined,
                    title: 'Danh mục',
                    subtitle: 'Danh mục thu, chi mặc định và tùy chỉnh',
                    onTap: () => context.push('/categories')),
                const Divider(height: 1),
                _SettingsTile(
                    icon: Icons.savings_outlined,
                    title: 'Ngân sách',
                    subtitle: 'Theo dõi hạn mức từng danh mục',
                    onTap: () => context.push('/budgets')),
                const Divider(height: 1),
                _SettingsTile(
                    icon: Icons.autorenew_rounded,
                    title: 'Giao dịch lặp lại',
                    subtitle: 'Tiền nhà, tiền mạng, lương hàng tháng',
                    onTap: () => context.push('/recurring')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Giao diện và hệ thống'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(effectiveDark
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined),
                  title: const Text('Giao diện'),
                  subtitle: const Text('Đen trắng tối giản'),
                  trailing: DropdownButton<ThemeMode>(
                    value: mode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                          value: ThemeMode.system, child: Text('Hệ thống')),
                      DropdownMenuItem(
                          value: ThemeMode.light, child: Text('Sáng')),
                      DropdownMenuItem(
                          value: ThemeMode.dark, child: Text('Tối')),
                    ],
                    onChanged: (value) {
                      if (value != null)
                        ref.read(themeModeProvider.notifier).setMode(value);
                    },
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.dns_outlined),
                  title: Text('Backend API'),
                  subtitle: SelectableText(AppConfig.apiBaseUrl),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.fingerprint_rounded),
                  title: const Text('Firebase UID'),
                  subtitle: SelectableText(user.uid),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Đăng xuất'),
          ),
          const SizedBox(height: 16),
          Text(
            'FinTrack 1.0.0 • CT220H Group 3',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
