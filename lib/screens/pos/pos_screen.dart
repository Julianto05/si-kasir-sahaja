import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/product_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/store_settings_provider.dart';
import '../../widgets/barcode_scanner_modal.dart';
import '../admin/product/product_form_screen.dart';
import '../admin/widgets/admin_drawer.dart';
import '../cashier/closing/shift_closing_dialog.dart';
import 'checkout_dialog.dart';

/// Point of Sale (POS) Screen with responsive layout and high-performance retail catalog.
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProductProvider>().resetFilters();
        context.read<ProductProvider>().refreshProducts();
        context.read<CategoryProvider>().refreshCategories();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final barcode = await BarcodeScannerModal.show(context);
    if (barcode != null && barcode.isNotEmpty && mounted) {
      final product =
          await context.read<ProductProvider>().findByBarcode(barcode);
      if (product != null && mounted) {
        final added = context.read<PosProvider>().addToCart(product);
        if (added) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${product.name}" ditambahkan ke keranjang'),
              backgroundColor: AppTheme.secondary,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produk dengan barcode "$barcode" tidak ditemukan'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final shiftProvider = context.watch<ShiftProvider>();
    final isAdmin = authProvider.isAdmin;
    final isTabletOrDesktop = MediaQuery.of(context).size.width >= 850;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: const Icon(Icons.point_of_sale_rounded, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Kasir / POS'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan Barcode',
            onPressed: _scanBarcode,
          ),
          if (shiftProvider.hasActiveShift && shiftProvider.activeShift != null)
            IconButton(
              icon: const Icon(Icons.fact_check_rounded),
              tooltip: 'Tutup Shift Kasir (Closing)',
              onPressed: () => ShiftClosingDialog.show(
                  context, shiftProvider.activeShift!),
            ),
          Consumer<PosProvider>(
            builder: (context, pos, _) {
              if (pos.isCartEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep_rounded),
                tooltip: 'Kosongkan Keranjang',
                onPressed: () => _confirmClearCart(context),
              );
            },
          ),
        ],
      ),
      drawer: isAdmin ? const AdminDrawer(currentRoute: 'pos') : null,
      body: SafeArea(
        child: isTabletOrDesktop
            ? Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        _buildSearchAndCategoryBar(context),
                        Expanded(child: _buildProductGrid(context)),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    flex: 4,
                    child: _buildCartSection(context),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildSearchAndCategoryBar(context),
                  Expanded(child: _buildProductGrid(context)),
                  _buildMobileCartBar(context),
                ],
              ),
      ),
    );
  }

  Widget _buildSearchAndCategoryBar(BuildContext context) {
    return Container(
      color: AppTheme.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          // Search Input Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) =>
                      context.read<ProductProvider>().setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText: 'Cari produk, SKU, barcode...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              context
                                  .read<ProductProvider>()
                                  .setSearchQuery('');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _scanBarcode,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                tooltip: 'Scan Barcode',
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.secondary.withValues(alpha: 0.15),
                  foregroundColor: AppTheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Category Filter Pills
          Consumer2<CategoryProvider, ProductProvider>(
            builder: (context, catProvider, prodProvider, _) {
              final categories = catProvider.activeCategories;
              final selectedId = prodProvider.selectedCategoryId;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Semua'),
                      selected: selectedId == 'all',
                      selectedColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        color: selectedId == 'all'
                            ? Colors.white
                            : AppTheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      onSelected: (_) =>
                          prodProvider.setCategoryFilter('all'),
                    ),
                    const SizedBox(width: 6),
                    ...categories.map((cat) {
                      final isSelected = selectedId == cat.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
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

  Widget _buildProductGrid(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        if (provider.errorMessage != null && provider.allProducts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 48, color: AppTheme.error),
                  const SizedBox(height: 12),
                  Text(
                    provider.errorMessage!,
                    style: const TextStyle(color: AppTheme.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => provider.refreshProducts(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          );
        }

        final products = provider.filteredProducts
            .where((p) => p.isActive)
            .toList();

        if (products.isEmpty) {
          final isTotalEmpty = provider.allProducts.isEmpty;
          final isAdmin = context.read<AuthProvider>().isAdmin;

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppTheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isTotalEmpty
                          ? Icons.inventory_2_outlined
                          : Icons.search_off_rounded,
                      size: 48,
                      color: AppTheme.outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isTotalEmpty
                        ? 'Belum Ada Produk Terdaftar'
                        : 'Produk Tidak Ditemukan',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isTotalEmpty
                        ? 'Tambahkan produk di menu Master Data untuk mulai bertransaksi di kasir.'
                        : 'Coba ubah kata kunci pencarian atau pilih kategori lain.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.outline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (isTotalEmpty && isAdmin)
                    ElevatedButton.icon(
                      onPressed: () => ProductFormScreen.navigate(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Tambah Produk Pertama'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondary,
                      ),
                    )
                  else if (!isTotalEmpty)
                    OutlinedButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        provider.resetFilters();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reset Pencarian'),
                    ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await provider.refreshProducts();
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 190,
              childAspectRatio: 0.76,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _PosProductCard(
                product: product,
                onTap: () {
                  final pos = context.read<PosProvider>();
                  final added = pos.addToCart(product);
                  if (!added && pos.errorMessage != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(pos.errorMessage!),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCartSection(BuildContext context) {
    return Consumer2<PosProvider, StoreSettingsProvider>(
      builder: (context, posProvider, storeSettingsProvider, _) {
        final settings = storeSettingsProvider.settings;
        final cartItems = posProvider.cartItems;
        final total = posProvider.calculateTotal(settings);
        final tax = posProvider.calculateTax(settings);

        return Container(
          color: AppTheme.surfaceContainerLowest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cart Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_cart_outlined,
                        color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Keranjang Belanja',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        '${posProvider.totalItemCount} Item',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Items List
              Expanded(
                child: cartItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_shopping_cart_rounded,
                              size: 48,
                              color: AppTheme.outline.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Keranjang masih kosong',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppTheme.outline,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Ketuk produk untuk menambahkan ke keranjang',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.outline,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: cartItems.length,
                        separatorBuilder: (_, _) => const Divider(height: 12),
                        itemBuilder: (context, index) {
                          final item = cartItems[index];
                          return _CartItemRow(item: item);
                        },
                      ),
              ),

              // Pricing Summary Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Subtotal', posProvider.subtotal),
                    if (posProvider.discount > 0)
                      _buildSummaryRow('Diskon', -posProvider.discount,
                          isDiscount: true),
                    if (tax > 0)
                      _buildSummaryRow(
                          'PPN (${settings.taxPercentage}%)', tax),
                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL BAYAR',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          CurrencyFormatter.format(total),
                          style: AppTheme.numericStyle.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Pay Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: posProvider.isCartEmpty
                            ? null
                            : () => CheckoutDialog.show(context),
                        icon: const Icon(Icons.payments_rounded, size: 20),
                        label: const Text(
                          'Bayar Sekarang',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileCartBar(BuildContext context) {
    return Consumer2<PosProvider, StoreSettingsProvider>(
      builder: (context, posProvider, storeSettingsProvider, _) {
        final settings = storeSettingsProvider.settings;
        final total = posProvider.calculateTotal(settings);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Total & Item count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total (${posProvider.totalItemCount} item)',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.outline),
                    ),
                    Text(
                      CurrencyFormatter.format(total),
                      style: AppTheme.numericStyle.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // View Cart / Checkout Button
              ElevatedButton.icon(
                onPressed: posProvider.isCartEmpty
                    ? null
                    : () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(AppTheme.radiusXl),
                            ),
                          ),
                          builder: (ctx) => FractionallySizedBox(
                            heightFactor: 0.85,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppTheme.radiusXl),
                              ),
                              child: _buildCartSection(context),
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 20),
                label: Text(
                  posProvider.isCartEmpty
                      ? 'Keranjang'
                      : 'Keranjang (${posProvider.totalItemCount})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, double amount,
      {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            CurrencyFormatter.format(amount),
            style: AppTheme.numericSmallStyle.copyWith(
              color: isDiscount ? AppTheme.error : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearCart(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kosongkan Keranjang'),
        content: const Text('Hapus semua produk dari keranjang saat ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<PosProvider>().clearCart();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Kosongkan'),
          ),
        ],
      ),
    );
  }
}

class _PosProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;

  const _PosProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOut = product.stock <= 0;

    return Consumer<PosProvider>(
      builder: (context, posProvider, _) {
        final cartQty = posProvider.getItemQuantity(product.id);

        return Material(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          elevation: 1,
          child: InkWell(
            onTap: isOut ? null : onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: cartQty > 0
                      ? AppTheme.secondary
                      : (product.isLowStock
                          ? AppTheme.error.withValues(alpha: 0.4)
                          : AppTheme.outlineVariant.withValues(alpha: 0.4)),
                  width: cartQty > 0 ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image Container with Cart Quantity Badge
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerHigh,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            child: product.imageUrl != null &&
                                    product.imageUrl!.isNotEmpty
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
                        if (cartQty > 0)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.secondary,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusFull),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Text(
                                '${cartQty}x',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Title
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Price
                  Text(
                    CurrencyFormatter.format(product.sellingPrice),
                    style: AppTheme.numericSmallStyle.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Stock Status Tag
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product.categoryName,
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.outline),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isOut
                              ? AppTheme.errorContainer
                              : (product.isLowStock
                                  ? AppTheme.errorContainer
                                      .withValues(alpha: 0.5)
                                  : AppTheme.surfaceContainerHigh),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(
                          isOut
                              ? 'Habis'
                              : '${product.stock} ${product.unit}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isOut
                                ? AppTheme.error
                                : AppTheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final TransactionItemModel item;

  const _CartItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final posProvider = context.read<PosProvider>();

    return Material(
      color: Colors.transparent,
      child: Row(
        children: [
          // Name & Price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${CurrencyFormatter.format(item.price)} / ${item.unit}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: AppTheme.outline,
                      ),
                ),
              ],
            ),
          ),

          // Stepper Quantity Buttons
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => posProvider.decrementItem(item.productId),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${item.quantity}',
                  style: AppTheme.numericStyle.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () =>
                    posProvider.incrementItem(item.productId, 9999),
              ),
            ],
          ),
          const SizedBox(width: 8),

          // Subtotal
          SizedBox(
            width: 80,
            child: Text(
              CurrencyFormatter.format(item.subtotal),
              style: AppTheme.numericSmallStyle.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
