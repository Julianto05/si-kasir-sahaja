import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../widgets/motion_widgets.dart';
import '../admin/product/product_form_screen.dart';
import '../admin/widgets/admin_drawer.dart';
import '../cashier/closing/shift_closing_dialog.dart';
import 'checkout_dialog.dart';

/// Point of Sale (POS) Screen with modern mobile layout, tactile product cards,
/// and floating cart dock.
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
          HapticFeedback.mediumImpact();
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

  void _showMobileCartSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXl),
            ),
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                decoration: BoxDecoration(
                  color: AppTheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: _buildCartSection(
                  context,
                  isBottomSheet: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
              child: const Icon(Icons.point_of_sale_rounded, size: 19),
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
          if (shiftProvider.hasActiveShift &&
              shiftProvider.activeShift != null)
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
            : Stack(
                children: [
                  Column(
                    children: [
                      _buildSearchAndCategoryBar(context),
                      Expanded(
                        child: _buildProductGrid(
                          context,
                          bottomPadding: 92,
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildMobileCartBar(context),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSearchAndCategoryBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
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
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
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
              ScaleTap(
                onTap: _scanBarcode,
                child: Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.secondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppTheme.secondary,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Category Filter Pills
          Consumer2<CategoryProvider, ProductProvider>(
            builder: (context, catProvider, prodProvider, _) {
              final categories = catProvider.activeCategories;
              final selectedId = prodProvider.selectedCategoryId;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _CategoryPill(
                      label: 'Semua Produk',
                      isSelected: selectedId == 'all',
                      onTap: () => prodProvider.setCategoryFilter('all'),
                    ),
                    const SizedBox(width: 8),
                    ...categories.map((cat) {
                      final isSelected = selectedId == cat.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _CategoryPill(
                          label: cat.name,
                          isSelected: isSelected,
                          onTap: () => prodProvider.setCategoryFilter(cat.id),
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

  Widget _buildProductGrid(BuildContext context, {double bottomPadding = 14}) {
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

        final products =
            provider.filteredProducts.where((p) => p.isActive).toList();

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
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isTotalEmpty
                          ? Icons.inventory_2_outlined
                          : Icons.search_off_rounded,
                      size: 44,
                      color: AppTheme.outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isTotalEmpty
                        ? 'Belum Ada Produk Terdaftar'
                        : 'Produk Tidak Ditemukan',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
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
            padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
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

  Widget _buildCartSection(
    BuildContext context, {
    bool isBottomSheet = false,
  }) {
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
                  color: AppTheme.surfaceContainerLowest,
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: const Icon(
                        Icons.shopping_cart_rounded,
                        color: AppTheme.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Keranjang Belanja',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
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
                    if (isBottomSheet) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
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
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: AppTheme.surfaceContainerLow,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.add_shopping_cart_rounded,
                                size: 40,
                                color: AppTheme.outline.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Keranjang masih kosong',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Ketuk produk pada katalog untuk menambahkan',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.outline,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: cartItems.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 16),
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
                      color: AppTheme.outlineVariant.withValues(alpha: 0.7),
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
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL BAYAR',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        AnimatedCurrencyText(
                          value: total,
                          style: AppTheme.numericStyle.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
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
                            : () {
                                if (isBottomSheet) {
                                  Navigator.pop(context);
                                }
                                CheckoutDialog.show(context);
                              },
                        icon: const Icon(Icons.payments_rounded, size: 20),
                        label: const Text(
                          'Bayar Sekarang',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondary,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
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
        final itemCount = posProvider.totalItemCount;
        final isEmpty = posProvider.isCartEmpty;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isEmpty
                  ? AppTheme.surfaceContainerLowest
                  : AppTheme.primary,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(
                color: isEmpty
                    ? AppTheme.outlineVariant
                    : AppTheme.primaryContainer,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isEmpty ? Colors.black : AppTheme.primary)
                      .withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                // Tappable Cart Info (opens bottom sheet)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: isEmpty ? null : () => _showMobileCartSheet(context),
                    child: Row(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Container(
                            key: ValueKey<int>(itemCount),
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isEmpty
                                  ? AppTheme.surfaceContainerLow
                                  : Colors.white.withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_bag_rounded,
                                  color: isEmpty
                                      ? AppTheme.outline
                                      : Colors.white,
                                  size: 20,
                                ),
                                if (itemCount > 0)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.secondary,
                                        borderRadius: BorderRadius.circular(
                                            AppTheme.radiusFull),
                                      ),
                                      child: Text(
                                        '$itemCount',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    isEmpty
                                        ? 'Keranjang Kosong'
                                        : '$itemCount Item • Ketuk rincian',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: isEmpty
                                          ? AppTheme.outline
                                          : Colors.white
                                              .withValues(alpha: 0.8),
                                    ),
                                  ),
                                  if (!isEmpty) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_up_rounded,
                                      size: 14,
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ],
                                ],
                              ),
                              AnimatedCurrencyText(
                                value: total,
                                style: AppTheme.numericStyle.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isEmpty
                                      ? AppTheme.onSurface
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Checkout Button
                ScaleTap(
                  onTap: isEmpty ? null : () => CheckoutDialog.show(context),
                  child: ElevatedButton.icon(
                    onPressed:
                        isEmpty ? null : () => CheckoutDialog.show(context),
                    icon: const Icon(
                      Icons.payments_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'Bayar',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.surfaceContainerHigh,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.outline),
          ),
          Text(
            CurrencyFormatter.format(amount),
            style: AppTheme.numericSmallStyle.copyWith(
              color: isDiscount ? AppTheme.error : AppTheme.onSurface,
              fontWeight: FontWeight.w600,
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

class _CategoryPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.outlineVariant,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
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
        final isSelected = cartQty > 0;

        return ScaleTap(
          onTap: isOut ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.secondary.withValues(alpha: 0.03)
                  : AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: isSelected
                    ? AppTheme.secondary
                    : (product.isLowStock
                        ? AppTheme.error.withValues(alpha: 0.4)
                        : AppTheme.outlineVariant.withValues(alpha: 0.7)),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image Container with Animated Cart Badge
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
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
                                  errorBuilder: (_, _, _) =>
                                      _buildFallbackAvatar(product.name),
                                )
                              : _buildFallbackAvatar(product.name),
                        ),
                      ),

                      // Out of stock overlay
                      if (isOut)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.error,
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusFull),
                                ),
                                child: const Text(
                                  'HABIS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Animated Cart Quantity Badge
                      Positioned(
                        top: 6,
                        right: 6,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: cartQty > 0
                              ? Container(
                                  key: ValueKey<int>(cartQty),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.secondaryGradient,
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusFull),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.secondary
                                            .withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '${cartQty}x',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Title
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: AppTheme.onSurface,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // Price
                Text(
                  CurrencyFormatter.format(product.sellingPrice),
                  style: AppTheme.numericSmallStyle.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.secondary,
                  ),
                ),
                const SizedBox(height: 5),

                // Stock Status Tag
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.categoryName,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isOut
                            ? AppTheme.errorContainer
                            : (product.isLowStock
                                ? AppTheme.errorContainer
                                    .withValues(alpha: 0.6)
                                : AppTheme.surfaceContainerLow),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        isOut
                            ? 'Habis'
                            : '${product.stock} ${product.unit}',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: (isOut || product.isLowStock)
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
        );
      },
    );
  }

  Widget _buildFallbackAvatar(String name) {
    final initials = name.trim().isNotEmpty
        ? name
            .trim()
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join()
        : 'P';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.08),
            AppTheme.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final TransactionItemModel item;

  const _CartItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final posProvider = context.read<PosProvider>();

    return Row(
      children: [
        // Name & Price
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.onSurface,
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

        // Modern Stepper Quantity Buttons
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                onTap: () {
                  HapticFeedback.selectionClick();
                  posProvider.decrementItem(item.productId);
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.remove_rounded, size: 16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${item.quantity}',
                  style: AppTheme.numericSmallStyle.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                onTap: () {
                  HapticFeedback.selectionClick();
                  posProvider.incrementItem(item.productId, 9999);
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: AppTheme.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        // Subtotal
        SizedBox(
          width: 78,
          child: Text(
            CurrencyFormatter.format(item.subtotal),
            style: AppTheme.numericSmallStyle.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
