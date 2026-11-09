import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/product_model.dart';
import '../../../models/stock_movement_model.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/stock_provider.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/motion_widgets.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/admin_drawer.dart';
import 'stock_adjustment_dialog.dart';

/// Screen for managing inventory stock, restock actions, per-product Stock Card, and movement logs (PRD Section 5.4).
class StockManagementScreen extends StatefulWidget {
  const StockManagementScreen({super.key});

  @override
  State<StockManagementScreen> createState() => _StockManagementScreenState();
}

class _StockManagementScreenState extends State<StockManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Manajemen Stok & Kartu Stok'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.secondaryContainer,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.inventory_2_outlined),
              text: 'Stok & Kartu Stok',
            ),
            Tab(icon: Icon(Icons.history_rounded), text: 'Riwayat Mutasi'),
          ],
        ),
      ),
      drawer: const AdminDrawer(currentRoute: 'stock'),
      bottomNavigationBar: const AdminBottomNav(currentRoute: 'stock'),
      body: AppBackground(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildCurrentStockTab(context),
            _buildMovementsTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStockTab(BuildContext context) {
    final prodProvider = context.watch<ProductProvider>();
    final expiringCount = prodProvider.expiringOrExpiredProducts.length;

    return Column(
      children: [
        // Top Search & Filter Bar
        Container(
          color: AppTheme.surfaceContainerLowest,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                onChanged: (val) => prodProvider.setSearchQuery(val),
                decoration: InputDecoration(
                  hintText: 'Cari nama produk, SKU, merek, barcode...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: prodProvider.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => prodProvider.setSearchQuery(''),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ActionChip(
                      avatar: Icon(
                        prodProvider.showOnlyLowStock
                            ? Icons.check_circle_rounded
                            : Icons.warning_amber_rounded,
                        size: 16,
                        color: prodProvider.showOnlyLowStock
                            ? Colors.white
                            : AppTheme.error,
                      ),
                      label: Text(
                        'Stok Menipis/Kosong (${prodProvider.lowStockCount})',
                        style: TextStyle(
                          color: prodProvider.showOnlyLowStock
                              ? Colors.white
                              : AppTheme.onSurface,
                          fontWeight: prodProvider.showOnlyLowStock
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: prodProvider.showOnlyLowStock
                          ? AppTheme.error
                          : AppTheme.surfaceContainerHigh,
                      side: BorderSide(
                        color: prodProvider.showOnlyLowStock
                            ? AppTheme.error
                            : AppTheme.outlineVariant,
                      ),
                      onPressed: () => prodProvider.toggleLowStockFilter(),
                    ),
                    if (expiringCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const PulseIndicator(
                              color: Color(0xFFD97706),
                              size: 6,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$expiringCount Produk Hampir/Sudah Expired',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Product Stock List
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
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: AppTheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tidak ada data produk',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                );
              }

              final width = MediaQuery.of(context).size.width;
              if (width >= 700) {
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    childAspectRatio: 2.1,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _StockProductCard(product: product);
                  },
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: products.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return _StockProductCard(product: product);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMovementsTab(BuildContext context) {
    return Column(
      children: [
        // Movement Type Filter Chips
        Container(
          color: AppTheme.surfaceContainerLowest,
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(context, 'all', 'Semua Mutasi'),
                _buildFilterChip(context, 'in', 'Stok Masuk'),
                _buildFilterChip(context, 'purchase_in', 'Pembelian Supplier'),
                _buildFilterChip(context, 'sale', 'Penjualan POS'),
                _buildFilterChip(context, 'adjustment', 'Penyesuaian Opname'),
                _buildFilterChip(context, 'damaged', 'Barang Rusak'),
                _buildFilterChip(context, 'expired', 'Kedaluwarsa'),
                _buildFilterChip(context, 'refund', 'Retur Penjualan'),
              ],
            ),
          ),
        ),

        // Movements List
        Expanded(
          child: Consumer<StockProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                );
              }

              final movements = provider.filteredMovements;

              if (movements.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.history_toggle_off_rounded,
                        size: 48,
                        color: AppTheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Belum ada riwayat pergerakan stok',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: movements.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final movement = movements[index];
                  return _StockMovementCard(movement: movement);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(BuildContext context, String type, String label) {
    final provider = context.watch<StockProvider>();
    final isSelected = provider.selectedType == type;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        showCheckmark: false,
        selectedColor: AppTheme.primary,
        backgroundColor: AppTheme.surfaceContainerLow,
        side: BorderSide(
          color: isSelected ? AppTheme.primary : AppTheme.outlineVariant,
        ),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          fontSize: 12,
        ),
        onSelected: (_) => provider.setTypeFilter(type),
      ),
    );
  }
}

class _StockProductCard extends StatelessWidget {
  final ProductModel product;

  const _StockProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: product.isLowStock || product.isExpired
              ? AppTheme.error.withValues(alpha: 0.4)
              : AppTheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (product.stock == 0 || product.isExpired)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: PulseIndicator(color: AppTheme.error, size: 7),
                      ),
                    Expanded(
                      child: Text(
                        product.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'SKU: ${product.code} • ${product.categoryName}${product.brand.isNotEmpty ? " (${product.brand})" : ""}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.outline,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: product.isLowStock
                            ? AppTheme.errorContainer
                            : AppTheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        product.stock == 0
                            ? 'STOK KOSONG (0 ${product.unit})'
                            : 'Stok: ${product.stock} ${product.unit}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: product.isLowStock
                              ? AppTheme.error
                              : AppTheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    Text(
                      'Min: ${product.minimumStock} ${product.unit}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.outline,
                      ),
                    ),
                    if (product.expiryDate != null)
                      Text(
                        'Exp: ${DateFormat("dd/MM/yy").format(product.expiryDate!)}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: product.isExpired
                              ? AppTheme.error
                              : AppTheme.outline,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.list_alt_rounded, size: 19),
                tooltip: 'Kartu Stok Produk',
                onPressed: () => _showStockCardDialog(context, product),
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                icon: const Icon(Icons.add_rounded, size: 19),
                tooltip: 'Restock',
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.secondaryContainer,
                  foregroundColor: AppTheme.onSecondaryContainer,
                ),
                onPressed: () {
                  StockAdjustmentDialog.show(
                    context,
                    product: product,
                    isRestock: true,
                  );
                },
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                icon: const Icon(Icons.tune_rounded, size: 19),
                tooltip: 'Penyesuaian / Rusak / Expired',
                onPressed: () {
                  StockAdjustmentDialog.show(
                    context,
                    product: product,
                    isRestock: false,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStockCardDialog(BuildContext context, ProductModel prod) {
    final movements = context.read<StockProvider>().getMovementsForProduct(
      prod.id,
    );

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.list_alt_rounded, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kartu Stok: ${prod.name}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'SKU: ${prod.code} • Saldo Saat Ini: ${prod.stock} ${prod.unit}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: movements.isEmpty
                      ? const Center(
                          child: Text(
                            'Belum ada histori keluar/masuk pada produk ini.',
                            style: TextStyle(color: AppTheme.outline),
                          ),
                        )
                      : ListView.separated(
                          itemCount: movements.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, idx) =>
                              _StockMovementCard(movement: movements[idx]),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StockMovementCard extends StatelessWidget {
  final StockMovementModel movement;

  const _StockMovementCard({required this.movement});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(movement.createdAt);
    final isIncrease = movement.isAddition && movement.quantity >= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  movement.productName,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isIncrease
                      ? AppTheme.secondaryContainer
                      : AppTheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  '${movement.quantity > 0 && isIncrease ? "+" : ""}${movement.quantity}',
                  style: AppTheme.numericSmallStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isIncrease
                        ? AppTheme.onSecondaryContainer
                        : AppTheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  movement.typeLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  movement.notes,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: AppTheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Oleh: ${movement.userName}',
                style: const TextStyle(fontSize: 10, color: AppTheme.outline),
              ),
              Text(
                dateStr,
                style: const TextStyle(fontSize: 10, color: AppTheme.outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
