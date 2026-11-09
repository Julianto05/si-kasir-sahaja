import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/product_model.dart';
import '../../../models/supplier_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/purchase_provider.dart';
import '../../../providers/supplier_provider.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/motion_widgets.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/admin_drawer.dart';

/// Module 5.7: Supplier & Pembelian Barang (Purchasing & Goods Receipt).
class PurchaseManagementScreen extends StatefulWidget {
  const PurchaseManagementScreen({super.key});

  @override
  State<PurchaseManagementScreen> createState() =>
      _PurchaseManagementScreenState();
}

class _PurchaseManagementScreenState extends State<PurchaseManagementScreen>
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
    final purchaseProv = context.watch<PurchaseProvider>();
    final supplierProv = context.watch<SupplierProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Pembelian & Supplier'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: const Icon(Icons.shopping_bag_rounded, size: 18),
              text: 'Pembelian (${purchaseProv.allPurchases.length})',
            ),
            Tab(
              icon: const Icon(Icons.local_shipping_rounded, size: 18),
              text: 'Data Supplier (${supplierProv.allSuppliers.length})',
            ),
          ],
        ),
      ),
      drawer: const AdminDrawer(currentRoute: 'purchases'),
      bottomNavigationBar: const AdminBottomNav(currentRoute: 'purchases'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _showCreatePurchaseBottomSheet(context);
          } else {
            _showSupplierFormDialog(context);
          }
        },
        backgroundColor: AppTheme.secondary,
        icon: const Icon(Icons.add_rounded),
        label: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) => Text(
            _tabController.index == 0 ? 'Buat Pembelian' : 'Tambah Supplier',
          ),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPurchasesTab(context, purchaseProv, supplierProv),
              _buildSuppliersTab(context, supplierProv),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurchasesTab(
    BuildContext context,
    PurchaseProvider purchaseProv,
    SupplierProvider supplierProv,
  ) {
    final purchases = purchaseProv.filteredPurchases;

    return Column(
      children: [
        // Top Summary & Search
        Container(
          padding: const EdgeInsets.all(AppTheme.containerPadding),
          color: AppTheme.surfaceContainerLowest,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMiniStat(
                      'Total Pembelian',
                      CurrencyFormatter.format(
                        purchaseProv.totalPurchasesAmount,
                      ),
                      AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMiniStat(
                      'Utang Belum Lunas',
                      CurrencyFormatter.format(
                        purchaseProv.totalUnpaidPurchases,
                      ),
                      AppTheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: purchaseProv.setSearchQuery,
                decoration: const InputDecoration(
                  hintText: 'Cari nomor PO atau nama supplier...',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: purchases.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada riwayat pembelian barang dari supplier.',
                    style: TextStyle(color: AppTheme.outline),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: purchases.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final po = purchases[index];
                    final dateStr = DateFormat(
                      'dd MMM yyyy, HH:mm',
                    ).format(po.date);
                    return ScaleTap(
                      onTap: () => _showPurchaseDetailDialog(context, po),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLg,
                          ),
                          border: Border.all(
                            color: AppTheme.outlineVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  po.purchaseNo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: po.isPaid
                                        ? AppTheme.secondaryContainer
                                        : AppTheme.errorContainer,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSm,
                                    ),
                                  ),
                                  child: Text(
                                    po.paymentStatusLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: po.isPaid
                                          ? AppTheme.onSecondaryContainer
                                          : AppTheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Supplier: ${po.supplierName} • $dateStr',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.outline,
                              ),
                            ),
                            const Divider(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${po.items.length} Jenis Barang',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    CurrencyFormatter.format(po.total),
                                    style: AppTheme.numericStyle.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primary,
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
                ),
        ),
      ],
    );
  }

  Widget _buildSuppliersTab(
    BuildContext context,
    SupplierProvider supplierProv,
  ) {
    final suppliers = supplierProv.filteredSuppliers;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.containerPadding),
          color: AppTheme.surfaceContainerLowest,
          child: TextField(
            onChanged: supplierProv.setSearchQuery,
            decoration: const InputDecoration(
              hintText: 'Cari nama supplier, telepon, atau alamat...',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: suppliers.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada data supplier terdaftar.',
                    style: TextStyle(color: AppTheme.outline),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isLandscape ? 2 : 1,
                    mainAxisExtent: 92,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: suppliers.length,
                  itemBuilder: (context, index) {
                    final s = suppliers[index];
                    return ScaleTap(
                      onTap: () =>
                          _showSupplierFormDialog(context, supplier: s),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLg,
                          ),
                          border: Border.all(
                            color: AppTheme.outlineVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusDefault,
                                ),
                              ),
                              child: const Icon(
                                Icons.local_shipping_rounded,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    s.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${s.phone.isNotEmpty ? s.phone : "-"} • ${s.address.isNotEmpty ? s.address : "Tanpa alamat"}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.outline,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppTheme.outline,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 10.5, color: AppTheme.outline),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPurchaseDetailDialog(BuildContext context, PurchaseModel po) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Detail Pembelian ${po.purchaseNo}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Supplier: ${po.supplierName}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.outline),
                ),
                const Divider(height: 20),
                ...po.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.productName} (${item.qty} ${item.unit} x ${CurrencyFormatter.format(item.buyPrice)})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(item.subtotal),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Pembelian',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      CurrencyFormatter.format(po.total),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sudah Dibayar'),
                    Text(CurrencyFormatter.format(po.paidAmount)),
                  ],
                ),
                if (!po.isPaid) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sisa Utang Supplier',
                        style: TextStyle(color: AppTheme.error),
                      ),
                      Text(
                        CurrencyFormatter.format(po.remainingDebt),
                        style: const TextStyle(
                          color: AppTheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSupplierFormDialog(
    BuildContext context, {
    SupplierModel? supplier,
  }) {
    final nameCtrl = TextEditingController(text: supplier?.name ?? '');
    final phoneCtrl = TextEditingController(text: supplier?.phone ?? '');
    final addrCtrl = TextEditingController(text: supplier?.address ?? '');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  supplier == null ? 'Tambah Supplier Baru' : 'Edit Supplier',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Supplier / PT *',
                    prefixIcon: Icon(Icons.business_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Telepon / WhatsApp',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addrCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Alamat Supplier',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          final prov = context.read<SupplierProvider>();
                          if (supplier == null) {
                            await prov.addSupplier(
                              name: nameCtrl.text,
                              phone: phoneCtrl.text,
                              address: addrCtrl.text,
                            );
                          } else {
                            await prov.updateSupplier(
                              supplier.copyWith(
                                name: nameCtrl.text,
                                phone: phoneCtrl.text,
                                address: addrCtrl.text,
                              ),
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Simpan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Scrollable Bottom Sheet for creating a Purchase Order (PRD Section 5.7 & Section 6).
  void _showCreatePurchaseBottomSheet(BuildContext context) {
    final suppliers = context.read<SupplierProvider>().activeSuppliers;
    final products = context.read<ProductProvider>().allProducts;

    SupplierModel? selectedSupplier = suppliers.isNotEmpty
        ? suppliers.first
        : null;
    final List<PurchaseItemModel> draftItems = [];
    final paidCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    ProductModel? selectedProduct = products.isNotEmpty ? products.first : null;
    final qtyCtrl = TextEditingController(text: '10');
    final buyPriceCtrl = TextEditingController(
      text: selectedProduct != null
          ? selectedProduct.costPrice.toInt().toString()
          : '0',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final totalPo = draftItems.fold(
              0.0,
              (sum, item) => sum + item.subtotal,
            );

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Buat Pembelian & Terima Barang',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Select Supplier
                    DropdownButtonFormField<SupplierModel>(
                      initialValue: selectedSupplier,
                      decoration: const InputDecoration(
                        labelText: 'Pilih Supplier *',
                        prefixIcon: Icon(Icons.local_shipping_outlined),
                        isDense: true,
                      ),
                      items: suppliers
                          .map(
                            (s) =>
                                DropdownMenuItem(value: s, child: Text(s.name)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setModalState(() => selectedSupplier = val),
                    ),
                    const SizedBox(height: 12),

                    // Add Product Item Row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Tambah Barang ke Daftar Pembelian',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<ProductModel>(
                            initialValue: selectedProduct,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Produk',
                              isDense: true,
                            ),
                            items: products
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text('${p.name} (Stok: ${p.stock})'),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setModalState(() {
                                selectedProduct = val;
                                if (val != null) {
                                  buyPriceCtrl.text = val.costPrice
                                      .toInt()
                                      .toString();
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: qtyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Jumlah Masuk',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: buyPriceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Harga Beli / HPP (Rp)',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  if (selectedProduct == null) return;
                                  final q = int.tryParse(qtyCtrl.text) ?? 0;
                                  final bp =
                                      double.tryParse(buyPriceCtrl.text) ?? 0.0;
                                  if (q <= 0) return;

                                  setModalState(() {
                                    draftItems.add(
                                      PurchaseItemModel(
                                        productId: selectedProduct!.id,
                                        productName: selectedProduct!.name,
                                        productCode: selectedProduct!.code,
                                        qty: q,
                                        buyPrice: bp,
                                        unit: selectedProduct!.unit,
                                      ),
                                    );
                                    final newTotal = draftItems.fold(
                                      0.0,
                                      (s, i) => s + i.subtotal,
                                    );
                                    paidCtrl.text = newTotal.toInt().toString();
                                  });
                                },
                                child: const Text('+ Tambah'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Draft Items List
                    if (draftItems.isNotEmpty) ...[
                      ...draftItems.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item.productName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${item.qty} ${item.unit} x ${CurrencyFormatter.format(item.buyPrice)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                CurrencyFormatter.format(item.subtotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppTheme.error,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setModalState(() => draftItems.removeAt(idx));
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL PEMBELIAN:',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            CurrencyFormatter.format(totalPo),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: paidCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText:
                              'Nominal Dibayar Sekarang (Rp) — Isi 0 jika Utang Penuh',
                          prefixIcon: Icon(Icons.payments_outlined),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Catatan / No. Faktur Supplier',
                          prefixIcon: Icon(Icons.notes_rounded),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (selectedSupplier == null || draftItems.isEmpty) {
                            return;
                          }
                          final user = context.read<AuthProvider>().currentUser;
                          final paid = double.tryParse(paidCtrl.text) ?? 0.0;
                          final ok = await context
                              .read<PurchaseProvider>()
                              .createPurchase(
                                supplierId: selectedSupplier!.id,
                                supplierName: selectedSupplier!.name,
                                items: draftItems,
                                paidAmount: paid,
                                notes: notesCtrl.text,
                                userId: user?.uid ?? 'admin',
                                userName: user?.name ?? 'Admin',
                              );
                          if (ok && ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Pembelian berhasil! Stok barang & HPP otomatis diperbarui.',
                                ),
                                backgroundColor: AppTheme.secondary,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondary,
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Simpan Pembelian & Terima Stok'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
