import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/product_model.dart';
import '../../../models/stock_movement_model.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/stock_provider.dart';
import '../widgets/admin_drawer.dart';
import 'stock_adjustment_dialog.dart';

/// Screen for managing inventory stock, restock actions, and movement logs.
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
        title: const Text('Manajemen Stok'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.secondaryContainer,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Stok Saat Ini'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Riwayat Mutasi'),
          ],
        ),
      ),
      drawer: const AdminDrawer(currentRoute: 'stock'),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCurrentStockTab(context),
          _buildMovementsTab(context),
        ],
      ),
    );
  }

  Widget _buildCurrentStockTab(BuildContext context) {
    final prodProvider = context.watch<ProductProvider>();

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
                  hintText: 'Cari nama produk, SKU, barcode...',
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

              Row(
                children: [
                  ActionChip(
                    avatar: Icon(
                      prodProvider.showOnlyLowStock
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      size: 16,
                      color: AppTheme.error,
                    ),
                    label: Text(
                        'Stok Menipis (${prodProvider.lowStockCount})'),
                    backgroundColor: prodProvider.showOnlyLowStock
                        ? AppTheme.errorContainer
                        : AppTheme.surfaceContainerHigh,
                    onPressed: () => prodProvider.toggleLowStockFilter(),
                  ),
                ],
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
                      const Icon(Icons.inventory_2_outlined,
                          size: 48, color: AppTheme.outline),
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
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 380,
                    childAspectRatio: 2.2,
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
                _buildFilterChip(context, 'sale', 'Penjualan POS'),
                _buildFilterChip(context, 'adjustment', 'Penyesuaian'),
                _buildFilterChip(context, 'refund', 'Pengembalian'),
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
                      const Icon(Icons.history_toggle_off_rounded,
                          size: 48, color: AppTheme.outline),
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
    final provider = context.read<StockProvider>();
    final isSelected = provider.selectedType == type;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
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
          color: product.isLowStock
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
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'SKU: ${product.code} • ${product.categoryName}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.outline,
                        fontSize: 11,
                      ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: product.isLowStock
                            ? AppTheme.errorContainer
                            : AppTheme.secondaryContainer,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        'Stok: ${product.stock} ${product.unit}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: product.isLowStock
                              ? AppTheme.error
                              : AppTheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Min: ${product.minimumStock} ${product.unit}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.outline),
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
                icon: const Icon(Icons.add_rounded, size: 20),
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
              const SizedBox(width: 6),
              IconButton.filledTonal(
                icon: const Icon(Icons.tune_rounded, size: 20),
                tooltip: 'Penyesuaian',
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
}

class _StockMovementCard extends StatelessWidget {
  final StockMovementModel movement;

  const _StockMovementCard({required this.movement});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('dd/MM/yyyy HH:mm').format(movement.createdAt);
    final isIncrease =
        movement.type == 'in' || movement.type == 'refund';

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
              Text(
                movement.productName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isIncrease
                      ? AppTheme.secondaryContainer
                      : AppTheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  '${isIncrease ? "+" : ""}${movement.quantity}',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
              Text(
                movement.notes,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: AppTheme.onSurfaceVariant,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
