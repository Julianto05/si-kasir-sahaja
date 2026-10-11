import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/category_model.dart';
import '../../../providers/category_provider.dart';
import '../widgets/admin_drawer.dart';
import 'category_form_dialog.dart';

/// Screen for displaying and managing categories in SiKasirSahaja.
class CategoryListScreen extends StatelessWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Kelola Kategori'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Tambah Kategori',
            onPressed: () => CategoryFormDialog.show(context),
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: 'categories'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CategoryFormDialog.show(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Kategori'),
        backgroundColor: AppTheme.primary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar & Stats Header
            _buildTopBar(context),

            // Category Cards List
            Expanded(
              child: Consumer<CategoryProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    );
                  }

                  final categories = provider.filteredCategories;

                  if (categories.isEmpty) {
                    return _buildEmptyState(context, provider.searchQuery);
                  }

                  final width = MediaQuery.of(context).size.width;
                  if (width >= 700) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        await context.read<CategoryProvider>().refreshCategories();
                      },
                      child: GridView.builder(
                        padding:
                            const EdgeInsets.all(AppTheme.containerPadding),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 360,
                          childAspectRatio: 2.6,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          return _CategoryCard(category: category);
                        },
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      await context.read<CategoryProvider>().refreshCategories();
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppTheme.containerPadding),
                      itemCount: categories.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppTheme.spacingMd),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return _CategoryCard(category: category);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.containerPadding),
      color: AppTheme.surfaceContainerLowest,
      child: Column(
        children: [
          // Search input
          TextField(
            onChanged: (val) =>
                context.read<CategoryProvider>().setSearchQuery(val),
            decoration: InputDecoration(
              hintText: 'Cari nama kategori atau deskripsi...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: Consumer<CategoryProvider>(
                builder: (context, provider, _) {
                  if (provider.searchQuery.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () => provider.setSearchQuery(''),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Total count chip
          Consumer<CategoryProvider>(
            builder: (context, provider, _) {
              final total = provider.allCategories.length;
              final active = provider.activeCategories.length;
              return Row(
                children: [
                  Text(
                    'Total Kategori ($total)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      '$active Aktif',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String searchQuery) {
    final isSearching = searchQuery.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching
                  ? Icons.search_off_rounded
                  : Icons.category_outlined,
              size: 64,
              color: AppTheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              isSearching
                  ? 'Tidak ada kategori cocok dengan "$searchQuery"'
                  : 'Belum ada kategori',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Coba gunakan kata kunci pencarian yang berbeda.'
                  : 'Tambahkan kategori pertama Anda untuk mengelompokkan produk.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (!isSearching) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => CategoryFormDialog.show(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah Kategori'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryModel category;

  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: category.isActive
              ? AppTheme.outlineVariant.withValues(alpha: 0.5)
              : AppTheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: category.isActive
                ? AppTheme.primary.withValues(alpha: 0.1)
                : AppTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Icon(
            Icons.category_rounded,
            color: category.isActive ? AppTheme.primary : AppTheme.outline,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                category.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      decoration:
                          category.isActive ? null : TextDecoration.lineThrough,
                    ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: category.isActive
                    ? AppTheme.secondaryContainer
                    : AppTheme.errorContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                category.isActive ? 'Aktif' : 'Nonaktif',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: category.isActive
                      ? AppTheme.onSecondaryContainer
                      : AppTheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
        subtitle: category.description.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  category.description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : null,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) => _handleAction(context, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(
                    category.isActive
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(category.isActive ? 'Nonaktifkan' : 'Aktifkan'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
                  SizedBox(width: 8),
                  Text('Hapus', style: TextStyle(color: AppTheme.error)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, String action) {
    final provider = context.read<CategoryProvider>();

    if (action == 'edit') {
      CategoryFormDialog.show(context, category: category);
    } else if (action == 'toggle') {
      provider.toggleCategoryStatus(category);
    } else if (action == 'delete') {
      _confirmDelete(context);
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text(
          'Apakah Anda yakin ingin menghapus kategori "${category.name}"?\n\n'
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CategoryProvider>().deleteCategory(category.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
