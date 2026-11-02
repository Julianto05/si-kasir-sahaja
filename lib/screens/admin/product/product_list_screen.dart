import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/product_model.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../widgets/barcode_scanner_modal.dart';
import '../../../widgets/motion_widgets.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/admin_drawer.dart';
import 'product_form_screen.dart';

/// Screen for displaying and searching products in SiKasirSahaja Admin.
class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Kelola Produk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan Barcode Produk',
            onPressed: () async {
              final barcode = await BarcodeScannerModal.show(context);
              if (barcode != null && context.mounted) {
                context.read<ProductProvider>().setSearchQuery(barcode);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Tambah Produk Baru',
            onPressed: () => ProductFormScreen.navigate(context),
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: 'products'),
      bottomNavigationBar: const AdminBottomNav(currentRoute: 'products'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ProductFormScreen.navigate(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Produk'),
        backgroundColor: AppTheme.primary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Search & Category Filter Section
            _buildSearchAndFilters(context),

            // Products Grid / List
            Expanded(
              child: Consumer<ProductProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    );
                  }

                  final products = provider.filteredProducts;

                  if (products.isEmpty) {
                    return _buildEmptyState(context, provider);
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      await provider.refreshProducts();
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth > 700;
                        if (isDesktop) {
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(
                              AppTheme.containerPadding,
                              AppTheme.containerPadding,
                              AppTheme.containerPadding,
                              80,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 360,
                              childAspectRatio: 2.2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              return _ProductGridCard(product: products[index]);
                            },
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppTheme.containerPadding,
                            AppTheme.containerPadding,
                            AppTheme.containerPadding,
                            80,
                          ),
                          itemCount: products.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _ProductListCard(product: products[index]);
                          },
                        );
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

  Widget _buildSearchAndFilters(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) =>
                      context.read<ProductProvider>().setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText: 'Cari produk, SKU, atau barcode...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    suffixIcon: Consumer<ProductProvider>(
                      builder: (context, provider, _) {
                        if (provider.searchQuery.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => provider.setSearchQuery(''),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ScaleTap(
                onTap: () async {
                  final barcode = await BarcodeScannerModal.show(context);
                  if (barcode != null && context.mounted) {
                    context.read<ProductProvider>().setSearchQuery(barcode);
                  }
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Low Stock Alert Banner (if any)
          Consumer<ProductProvider>(
            builder: (context, provider, _) {
              final lowStockCount = provider.lowStockCount;
              if (lowStockCount == 0) return const SizedBox.shrink();

              final isFiltering = provider.showOnlyLowStock;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ScaleTap(
                  onTap: () => provider.toggleLowStockFilter(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isFiltering
                          ? AppTheme.errorContainer
                          : AppTheme.errorContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: AppTheme.error.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const PulseIndicator(
                          color: AppTheme.error,
                          size: 7,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$lowStockCount produk memiliki stok menipis!',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: AppTheme.onErrorContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        Text(
                          isFiltering
                              ? 'Tampilkan Semua'
                              : 'Filter Stok Menipis',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Category Chips Filter Bar
          Consumer2<CategoryProvider, ProductProvider>(
            builder: (context, catProvider, prodProvider, _) {
              final categories = catProvider.activeCategories;
              final selectedId = prodProvider.selectedCategoryId;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Semua Kategori'),
                      selected: selectedId == 'all',
                      selectedColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        color: selectedId == 'all'
                            ? Colors.white
                            : AppTheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      onSelected: (_) => prodProvider.setCategoryFilter('all'),
                    ),
                    const SizedBox(width: 8),
                    ...categories.map((cat) {
                      final isSelected = selectedId == cat.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat.name),
                          selected: isSelected,
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppTheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          onSelected: (_) =>
                              prodProvider.setCategoryFilter(cat.id),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ProductProvider provider) {
    final isFiltering = provider.searchQuery.isNotEmpty ||
        provider.selectedCategoryId != 'all' ||
        provider.showOnlyLowStock;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltering
                    ? Icons.search_off_rounded
                    : Icons.inventory_2_outlined,
                size: 48,
                color: AppTheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isFiltering
                  ? 'Tidak ada produk sesuai filter'
                  : 'Belum ada produk terdaftar',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isFiltering
                  ? 'Coba atur ulang kata kunci atau filter kategori.'
                  : 'Tambahkan produk pertama Anda untuk mulai berjualan.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (isFiltering)
              OutlinedButton(
                onPressed: () => provider.resetFilters(),
                child: const Text('Reset Filter'),
              )
            else
              ElevatedButton.icon(
                onPressed: () => ProductFormScreen.navigate(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah Produk Pertama'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductListCard extends StatelessWidget {
  final ProductModel product;

  const _ProductListCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: () => ProductFormScreen.navigate(context, product: product),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: product.isLowStock
                ? AppTheme.error.withValues(alpha: 0.4)
                : AppTheme.outlineVariant.withValues(alpha: 0.7),
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.inventory_2_outlined,
                          color: AppTheme.outline,
                        ),
                      )
                    : const Icon(
                        Icons.inventory_2_outlined,
                        color: AppTheme.outline,
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!product.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.errorContainer,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: const Text(
                            'Nonaktif',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onErrorContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Code & Category
                  Row(
                    children: [
                      Text(
                        product.code,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                              fontSize: 11.5,
                            ),
                      ),
                      if (product.categoryName.isNotEmpty) ...[
                        const Text(
                          ' • ',
                          style: TextStyle(color: AppTheme.outline),
                        ),
                        Expanded(
                          child: Text(
                            product.categoryName,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Price & Stock Tag Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        CurrencyFormatter.format(product.sellingPrice),
                        style: AppTheme.numericStyle.copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.secondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: product.isLowStock
                              ? AppTheme.errorContainer
                              : AppTheme.surfaceContainerLow,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(
                          'Stok: ${product.stock} ${product.unit}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: product.isLowStock
                                ? AppTheme.error
                                : AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions Menu
            PopupMenuButton<String>(
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
                        product.isActive
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(product.isActive ? 'Nonaktifkan' : 'Aktifkan'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          size: 20, color: AppTheme.error),
                      SizedBox(width: 8),
                      Text('Hapus', style: TextStyle(color: AppTheme.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, String action) {
    final provider = context.read<ProductProvider>();

    if (action == 'edit') {
      ProductFormScreen.navigate(context, product: product);
    } else if (action == 'toggle') {
      provider.toggleProductStatus(product);
    } else if (action == 'delete') {
      _confirmDelete(context);
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: Text(
          'Apakah Anda yakin ingin menghapus produk "${product.name}"?\n\n'
          'Tindakan ini juga akan menghapus foto produk dari storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ProductProvider>().deleteProduct(product);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

class _ProductGridCard extends StatelessWidget {
  final ProductModel product;

  const _ProductGridCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return _ProductListCard(product: product);
  }
}
