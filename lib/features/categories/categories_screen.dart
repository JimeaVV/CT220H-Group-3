import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  String _type = 'Chi';
  bool _initializing = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final userId = user.uid;
    final categories = ref.watch(categoriesProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh mục'),
        actions: [
          IconButton(
            onPressed: _initializing ? null : () => _initializeDefaults(userId),
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: 'Khởi tạo danh mục mặc định',
          ),
          IconButton(
            onPressed: () => _showCategoryDialog(userId),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Chi', label: Text('Khoản chi')),
                ButtonSegment(value: 'Thu', label: Text('Khoản thu')),
              ],
              selected: {_type},
              onSelectionChanged: (value) => setState(() => _type = value.first),
            ),
          ),
          Expanded(
            child: categories.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(18),
                child: ErrorCard(error: error, onRetry: () => ref.invalidate(categoriesProvider(userId))),
              ),
              data: (items) {
                final filtered = items.where((item) => item.type == _type).toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.category_outlined,
                    title: 'Chưa có danh mục $_type',
                    message: 'Khởi tạo danh mục mặc định hoặc tạo danh mục riêng.',
                    actionLabel: 'Tạo danh mục',
                    onAction: () => _showCategoryDialog(userId),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final category = filtered[index];
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(category.icon.trim().isEmpty ? (_type == 'Chi' ? '↘' : '↗') : category.icon, style: const TextStyle(fontSize: 21)),
                        ),
                        title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(category.isDefault ? 'Danh mục mặc định' : 'Danh mục của bạn'),
                        trailing: category.isDefault
                            ? const Icon(Icons.lock_outline_rounded, size: 19)
                            : const Icon(Icons.person_outline_rounded, size: 19),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryDialog(userId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Danh mục'),
      ),
    );
  }

  Future<void> _initializeDefaults(String userId) async {
    setState(() => _initializing = true);
    try {
      await ref.read(financeRepositoryProvider).initializeDefaultCategories();
      ref.invalidate(categoriesProvider(userId));
      if (mounted) showAppSnackBar(context, 'Đã kiểm tra và khởi tạo danh mục mặc định.');
    } catch (error) {
      if (mounted) showAppSnackBar(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _showCategoryDialog(String userId) async {
    final nameController = TextEditingController();
    final iconController = TextEditingController(text: _type == 'Chi' ? '🧾' : '💰');
    final formKey = GlobalKey<FormState>();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tạo danh mục $_type'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Tên danh mục'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Hãy nhập tên danh mục' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: iconController,
                decoration: const InputDecoration(labelText: 'Biểu tượng emoji', hintText: '🍜'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );

    if (submitted != true) {
      return;
    }

    try {
      await ref.read(financeRepositoryProvider).createCategory(
            userId: userId,
            name: nameController.text.trim(),
            type: _type,
            icon: iconController.text.trim(),
          );
      ref.invalidate(categoriesProvider(userId));
      if (mounted) showAppSnackBar(context, 'Đã tạo danh mục.');
    } catch (error) {
      if (mounted) showAppSnackBar(context, error.toString(), isError: true);
    } finally {
    }
  }
}
