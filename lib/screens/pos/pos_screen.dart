import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/customer_model.dart';
import '../../models/discount_model.dart';
import '../../models/product_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/discount_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/store_settings_provider.dart';
import '../../widgets/app_background.dart';
import '../../widgets/barcode_scanner_modal.dart';
import '../../widgets/motion_widgets.dart';
import '../admin/product/product_form_screen.dart';
import '../admin/widgets/admin_drawer.dart';
import '../cashier/closing/shift_closing_dialog.dart';
import '../cashier/closing/start_shift_dialog.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context.read<ProductProvider>().resetFilters();
      context.read<ProductProvider>().refreshProducts();
      context.read<CategoryProvider>().refreshCategories();

      final user = context.read<AuthProvider>().currentUser;
      final shiftProv = context.read<ShiftProvider>();
      if (user != null) {
        await shiftProv.loadActiveShift(user.id);
      }
      if (mounted && !shiftProv.hasActiveShift) {
        StartShiftDialog.show(context);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final shiftProv = context.read<ShiftProvider>();
    if (!shiftProv.hasActiveShift) {
      StartShiftDialog.show(context);
      return;
    }
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: const Icon(Icons.point_of_sale_rounded, size: 19),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Kasir / POS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Consumer<PosProvider>(
            builder: (context, pos, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.pause_circle_outline_rounded),
                    tooltip: 'Daftar Transaksi Tersimpan (Hold Order)',
                    onPressed: () => _showHeldOrdersDialog(context),
                  ),
                  if (pos.heldOrdersCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.error,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                        ),
                        child: Text(
                          '${pos.heldOrdersCount}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
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
            )
          else
            IconButton(
              icon: const Icon(Icons.lock_open_rounded),
              tooltip: 'Buka Shift Kasir',
              onPressed: () => StartShiftDialog.show(context),
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
      body: AppBackground(
        child: SafeArea(
          child: !shiftProvider.hasActiveShift
              ? _buildShiftRequiredLockView(context, isAdmin)
              : (isTabletOrDesktop
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
                    )),
        ),
      ),
    );
  }

  Widget _buildShiftRequiredLockView(BuildContext context, bool isAdmin) {
    final userName =
        context.read<AuthProvider>().currentUser?.name ?? (isAdmin ? 'Admin' : 'Kasir');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(
                color: AppTheme.outlineVariant.withValues(alpha: 0.7),
              ),
              boxShadow: AppTheme.elevatedShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_clock_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Text(
                    'SHIFT KASIR BELUM AKTIF',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.amber.shade900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Wajib Buka Shift Terlebih Dahulu',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Halo $userName (${isAdmin ? "Admin" : "Kasir"}), sebelum memilih barang dan melakukan transaksi penjualan di Kasir / POS, Anda diwajibkan membuka shift kasir dan mengisi modal awal laci kasir terlebih dahulu.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => StartShiftDialog.show(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    icon: const Icon(Icons.lock_open_rounded, size: 20),
                    label: const Text(
                      'Buka Shift Kasir Sekarang',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                if (Navigator.canPop(context)) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Kembali ke Dashboard'),
                    ),
                  ),
                ],
              ],
            ),
          ),
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
                  final shiftProv = context.read<ShiftProvider>();
                  if (!shiftProv.hasActiveShift) {
                    StartShiftDialog.show(context);
                    return;
                  }
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

              // Customer & Promo Quick Selector Strip (PRD Section 5.2)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    Expanded(
                      child: InkWell(
                        onTap: () => _showSelectCustomerDialog(context),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: posProvider.selectedCustomer != null
                                ? AppTheme.secondaryContainer
                                : AppTheme.surfaceContainerLowest,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                            border: Border.all(
                              color: AppTheme.outlineVariant
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_pin_rounded,
                                size: 15,
                                color: posProvider.selectedCustomer != null
                                    ? AppTheme.secondary
                                    : AppTheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  posProvider.selectedCustomer?.name ??
                                      'Pelanggan Umum',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: posProvider.selectedCustomer != null
                                        ? AppTheme.onSecondaryContainer
                                        : AppTheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _showPromoDiscountDialog(context),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: (posProvider.appliedPromo != null ||
                                    posProvider.discount > 0)
                                ? AppTheme.primary.withValues(alpha: 0.1)
                                : AppTheme.surfaceContainerLowest,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                            border: Border.all(
                              color: AppTheme.outlineVariant
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.discount_outlined,
                                size: 15,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  posProvider.appliedPromo?.name ??
                                      (posProvider.discount > 0
                                          ? 'Diskon Aktif'
                                          : 'Diskon / Promo'),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
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
                    if (posProvider.calculateTotalDiscount(settings) > 0)
                      _buildSummaryRow(
                          'Total Diskon',
                          -posProvider.calculateTotalDiscount(settings),
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

                    // Hold & Pay Buttons Row
                    Row(
                      children: [
                        SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: posProvider.isCartEmpty
                                ? null
                                : () {
                                    final user = context
                                        .read<AuthProvider>()
                                        .currentUser;
                                    if (user == null) return;
                                    posProvider.holdCurrentOrder(
                                      cashier: user,
                                      settings: settings,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Transaksi disimpan sementara (Hold Order)'),
                                        backgroundColor: AppTheme.primary,
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.pause_rounded, size: 18),
                            label: const Text('Hold'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: posProvider.isCartEmpty
                                  ? null
                                  : () {
                                      final shiftProv =
                                          context.read<ShiftProvider>();
                                      if (!shiftProv.hasActiveShift) {
                                        StartShiftDialog.show(context);
                                        return;
                                      }
                                      if (isBottomSheet) {
                                        Navigator.pop(context);
                                      }
                                      CheckoutDialog.show(context);
                                    },
                              icon:
                                  const Icon(Icons.payments_rounded, size: 20),
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
                        ),
                      ],
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

  void _showHeldOrdersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer<PosProvider>(
        builder: (ctx, pos, _) {
          final orders = pos.heldOrders;
          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 500),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Transaksi Tersimpan (Hold Order)',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: orders.isEmpty
                          ? const Center(
                              child: Text(
                                'Belum ada transaksi yang di-hold.',
                                style: TextStyle(color: AppTheme.outline),
                              ),
                            )
                          : ListView.separated(
                              itemCount: orders.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, idx) {
                                final h = orders[idx];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMd),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              h.label,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13),
                                            ),
                                            Text(
                                              '${h.items.length} produk • Total: ${CurrencyFormatter.format(h.subtotal)}',
                                              style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: AppTheme.outline),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: AppTheme.error),
                                        onPressed: () =>
                                            pos.removeHeldOrder(h.id),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          pos.resumeHeldOrder(h.id);
                                          Navigator.pop(ctx);
                                        },
                                        child: const Text('Lanjutkan'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSelectCustomerDialog(BuildContext context) {
    final searchCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Consumer2<CustomerProvider, PosProvider>(
        builder: (ctx, custProv, posProv, _) {
          final customers = custProv.filteredCustomers;
          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 540),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pilih / Daftar Pelanggan POS',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        if (posProv.selectedCustomer != null)
                          TextButton(
                            onPressed: () {
                              posProv.selectCustomer(null);
                              Navigator.pop(ctx);
                            },
                            child: const Text('Reset Umum'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: searchCtrl,
                      onChanged: (v) => custProv.setSearchQuery(v),
                      decoration: const InputDecoration(
                        hintText: 'Cari nama atau No. HP member...',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        itemCount: customers.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final CustomerModel c = customers[idx];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: c.isMember
                                  ? AppTheme.secondaryContainer
                                  : AppTheme.surfaceContainerHigh,
                              child: Icon(
                                c.isMember
                                    ? Icons.workspace_premium_rounded
                                    : Icons.person_outline,
                                size: 16,
                                color: c.isMember
                                    ? AppTheme.secondary
                                    : AppTheme.primary,
                              ),
                            ),
                            title: Text(
                              '${c.name}${c.isMember ? " (MEMBER)" : ""}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle:
                                Text('${c.phone} • ${c.points} Poin Loyalitas'),
                            onTap: () {
                              posProv.selectCustomer(c);
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    const Text(
                      'Daftar Cepat Member Baru:',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Nama',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: 'No. HP',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: () async {
                            if (nameCtrl.text.trim().isEmpty) return;
                            final created = await custProv.saveCustomer(
                              name: nameCtrl.text.trim(),
                              phone: phoneCtrl.text.trim(),
                              isMember: true,
                            );
                            if (created != null && ctx.mounted) {
                              posProv.selectCustomer(created);
                              Navigator.pop(ctx);
                            }
                          },
                          child: const Text('Pilih'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPromoDiscountDialog(BuildContext context) {
    final posProv = context.read<PosProvider>();

    showDialog(
      context: context,
      builder: (ctx) => Consumer<DiscountProvider>(
        builder: (ctx, discProv, _) {
          final promos = discProv.validDiscounts;
          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Pilih Voucher & Promo Resmi Toko',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Diskon hanya dapat diterapkan melalui promo/voucher resmi yang telah dibuat oleh Admin di sistem.',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.outline),
                    ),
                    const SizedBox(height: 14),
                    if (promos.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: const Text(
                          'Tidak ada promo atau voucher diskon yang sedang aktif.',
                          style: TextStyle(color: AppTheme.outline),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else ...[
                      ...promos.map((DiscountModel p) {
                        final selected = posProv.appliedPromo?.id == p.id;
                        return ListTile(
                          dense: true,
                          tileColor: selected
                              ? AppTheme.secondaryContainer
                              : AppTheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          leading: const Icon(Icons.local_offer_rounded,
                              color: AppTheme.primary, size: 18),
                          title: Text(
                            '${p.name} (${p.code})',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 12.5),
                          ),
                          subtitle: Text(
                            p.type == 'percentage'
                                ? 'Diskon ${p.value.toStringAsFixed(0)}% • Min. ${CurrencyFormatter.format(p.minPurchase)}'
                                : 'Potongan ${CurrencyFormatter.format(p.value)} • Min. ${CurrencyFormatter.format(p.minPurchase)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_circle,
                                  color: AppTheme.secondary)
                              : null,
                          onTap: () {
                            posProv.applyPromo(selected ? null : p);
                            Navigator.pop(ctx);
                          },
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        if (posProv.appliedPromo != null)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                posProv.setDiscount(0);
                                posProv.applyPromo(null);
                                Navigator.pop(ctx);
                              },
                              child: const Text('Hapus Promo'),
                            ),
                          ),
                        if (posProv.appliedPromo != null)
                          const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Tutup'),
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
          onTap: onTap,
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
                '${CurrencyFormatter.format(item.price)} / ${item.unit}'
                '${item.itemDiscount > 0 ? " (Diskon -${CurrencyFormatter.format(item.itemDiscount)})" : ""}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: item.itemDiscount > 0
                          ? AppTheme.error
                          : AppTheme.outline,
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
              InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                onTap: () => _showEditQuantityDialog(context, item),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    '${item.quantity}',
                    style: AppTheme.numericSmallStyle.copyWith(
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.dotted,
                    ),
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

  void _showEditQuantityDialog(BuildContext context, TransactionItemModel item) {
    final controller = TextEditingController(text: item.quantity.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Ubah Jumlah: ${item.productName}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan kuantitas item yang dibeli:',
              style: TextStyle(fontSize: 12, color: AppTheme.outline),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Jumlah (${item.unit})',
                suffixText: item.unit,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val >= 0) {
                context.read<PosProvider>().setItemQuantity(
                      item.productId,
                      val,
                      999999,
                    );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
