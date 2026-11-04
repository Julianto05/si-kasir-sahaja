import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/product_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stock_provider.dart';

/// Modal dialog for restock, manual stock adjustment, or recording damaged/expired stock (PRD Section 5.4).
class StockAdjustmentDialog extends StatefulWidget {
  final ProductModel product;
  final bool isRestock;

  const StockAdjustmentDialog({
    super.key,
    required this.product,
    this.isRestock = true,
  });

  static Future<void> show(
    BuildContext context, {
    required ProductModel product,
    required bool isRestock,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          StockAdjustmentDialog(product: product, isRestock: isRestock),
    );
  }

  @override
  State<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _qtyController;
  late final TextEditingController _notesController;
  String _adjustmentMode = 'opname'; // 'opname', 'damaged', 'expired'
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: widget.isRestock ? '' : widget.product.stock.toString(),
    );
    _notesController = TextEditingController(
      text: widget.isRestock
          ? 'Restock dari supplier'
          : 'Penyesuaian stok fisik',
    );
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final stockProvider = context.read<StockProvider>();
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      setState(() => _isSubmitting = false);
      return;
    }

    final qty = int.tryParse(_qtyController.text) ?? 0;
    bool success;

    if (widget.isRestock) {
      success = await stockProvider.restockProduct(
        product: widget.product,
        addQuantity: qty,
        notes: _notesController.text.trim(),
        user: user,
      );
    } else if (_adjustmentMode == 'damaged' || _adjustmentMode == 'expired') {
      success = await stockProvider.recordDamagedOrExpired(
        product: widget.product,
        removeQuantity: qty,
        type: _adjustmentMode,
        notes: _notesController.text.trim(),
        user: user,
      );
    } else {
      success = await stockProvider.adjustStock(
        product: widget.product,
        newStock: qty,
        reason: _notesController.text.trim(),
        user: user,
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isRestock
                ? 'Berhasil menambah $qty ${widget.product.unit} pada "${widget.product.name}"'
                : 'Mutasi stok "${widget.product.name}" berhasil disimpan',
          ),
          backgroundColor: AppTheme.secondary,
        ),
      );
    } else if (stockProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(stockProvider.errorMessage!),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDamageOrExpired =
        !widget.isRestock &&
        (_adjustmentMode == 'damaged' || _adjustmentMode == 'expired');

    return Dialog(
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.containerPadding),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isRestock
                            ? AppTheme.secondaryContainer
                            : AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusDefault,
                        ),
                      ),
                      child: Icon(
                        widget.isRestock
                            ? Icons.add_business_rounded
                            : Icons.tune_rounded,
                        color: widget.isRestock
                            ? AppTheme.onSecondaryContainer
                            : AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.isRestock
                            ? 'Tambah Stok Masuk'
                            : 'Penyesuaian / Rusak / Kedaluwarsa',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Product Card Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'SKU: ${widget.product.code}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Stok Saat Ini',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.outline,
                            ),
                          ),
                          Text(
                            '${widget.product.stock} ${widget.product.unit}',
                            style: AppTheme.numericStyle.copyWith(
                              fontWeight: FontWeight.bold,
                              color: widget.product.isLowStock
                                  ? AppTheme.error
                                  : AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Mode Selector when not restock
                if (!widget.isRestock) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _adjustmentMode,
                    decoration: const InputDecoration(
                      labelText: 'Jenis Mutasi Stok',
                      prefixIcon: Icon(Icons.swap_horiz_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'opname',
                        child: Text('Koreksi Stok Opname (Set Nilai Fisik)'),
                      ),
                      DropdownMenuItem(
                        value: 'damaged',
                        child: Text('Barang Rusak (Kurangi Stok)'),
                      ),
                      DropdownMenuItem(
                        value: 'expired',
                        child: Text('Barang Kedaluwarsa (Kurangi Stok)'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _adjustmentMode = v;
                        if (v == 'opname') {
                          _qtyController.text = widget.product.stock.toString();
                          _notesController.text = 'Penyesuaian stok fisik';
                        } else if (v == 'damaged') {
                          _qtyController.text = '1';
                          _notesController.text =
                              'Barang rusak / cacat kemasan';
                        } else {
                          _qtyController.text = '1';
                          _notesController.text =
                              'Barang melewati tanggal kedaluwarsa';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Quantity Input
                TextFormField(
                  controller: _qtyController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: widget.isRestock
                        ? 'Jumlah Stok Ditambahkan (${widget.product.unit}) *'
                        : isDamageOrExpired
                        ? 'Jumlah Barang Rusak/Expired (${widget.product.unit}) *'
                        : 'Total Stok Fisik Terbaru (${widget.product.unit}) *',
                    hintText: widget.isRestock ? 'e.g. 50' : 'e.g. 120',
                    prefixIcon: const Icon(Icons.numbers_rounded),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Jumlah wajib diisi';
                    }
                    final numVal = int.tryParse(val);
                    if (numVal == null ||
                        ((widget.isRestock || isDamageOrExpired) &&
                            numVal <= 0)) {
                      return 'Jumlah harus lebih dari 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Notes / Reason
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: widget.isRestock
                        ? 'Keterangan Supplier'
                        : 'Alasan / Catatan Mutasi *',
                    hintText: widget.isRestock
                        ? 'e.g. Pembelian dari PT Maju Jaya'
                        : 'e.g. Hasil Stock Opname akhir bulan',
                    prefixIcon: const Icon(Icons.notes_rounded),
                  ),
                  validator: (val) {
                    if (!widget.isRestock &&
                        (val == null || val.trim().isEmpty)) {
                      return 'Alasan wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isRestock
                              ? AppTheme.secondary
                              : (isDamageOrExpired
                                    ? AppTheme.error
                                    : AppTheme.primary),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(widget.isRestock ? 'Tambah Stok' : 'Simpan'),
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
}
