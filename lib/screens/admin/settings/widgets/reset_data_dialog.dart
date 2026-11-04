import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../providers/product_provider.dart';
import '../../../../services/data_reset_service.dart';

enum ResetPeriod { oneDay, weekly, monthly, custom }

/// Dialog for resetting operational store data with granular checkboxes for each module.
class ResetDataDialog extends StatefulWidget {
  const ResetDataDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ResetDataDialog(),
    );
  }

  @override
  State<ResetDataDialog> createState() => _ResetDataDialogState();
}

class _ResetDataDialogState extends State<ResetDataDialog> {
  final DataResetService _resetService = DataResetService();

  ResetPeriod _selectedPeriod = ResetPeriod.oneDay;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 1));
  DateTime _endDate = DateTime.now();

  // Individual Checklist items
  bool _deleteTransactions = true;
  bool _deleteShifts = true;
  bool _deleteStockMovements = true;
  bool _deleteExpenses = false;
  bool _deletePurchases = false;
  bool _deleteDebts = false;
  bool _deleteAttendanceLogs = false;
  bool _deleteActivityLogs = false;
  bool _deletePointLogs = false;
  bool _resetCustomerPoints = false;
  bool _resetProductStock = false;

  bool _isProcessing = false;
  final TextEditingController _confirmController = TextEditingController();
  final String _confirmKeyword = 'HAPUS';

  @override
  void initState() {
    super.initState();
    _applyPeriodPreset(ResetPeriod.oneDay);
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  void _applyPeriodPreset(ResetPeriod period) {
    final now = DateTime.now();
    setState(() {
      _selectedPeriod = period;
      switch (period) {
        case ResetPeriod.oneDay:
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = now;
          break;
        case ResetPeriod.weekly:
          _startDate = now.subtract(const Duration(days: 7));
          _endDate = now;
          break;
        case ResetPeriod.monthly:
          _startDate = DateTime(now.year, now.month - 1, now.day);
          _endDate = now;
          break;
        case ResetPeriod.custom:
          // Keep existing dates
          break;
      }
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: _startDate.isBefore(DateTime(2020))
            ? DateTime(2020)
            : _startDate,
        end: _endDate,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.error,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = ResetPeriod.custom;
        _startDate = picked.start;
        _endDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
    }
  }

  bool get _hasAnySelected =>
      _deleteTransactions ||
      _deleteShifts ||
      _deleteStockMovements ||
      _deleteExpenses ||
      _deletePurchases ||
      _deleteDebts ||
      _deleteAttendanceLogs ||
      _deleteActivityLogs ||
      _deletePointLogs ||
      _resetCustomerPoints ||
      _resetProductStock;

  void _selectAll(bool select) {
    setState(() {
      _deleteTransactions = select;
      _deleteShifts = select;
      _deleteStockMovements = select;
      _deleteExpenses = select;
      _deletePurchases = select;
      _deleteDebts = select;
      _deleteAttendanceLogs = select;
      _deleteActivityLogs = select;
      _deletePointLogs = select;
      _resetCustomerPoints = select;
      _resetProductStock = select;
    });
  }

  Future<void> _handleExecuteReset() async {
    if (_confirmController.text.trim().toUpperCase() != _confirmKeyword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ketik kata "HAPUS" untuk konfirmasi tindakan ini.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (!_hasAnySelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu tipe data yang ingin direset.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final totalWiped = await _resetService.resetData(
        startDate: _startDate,
        endDate: _endDate,
        deleteTransactions: _deleteTransactions,
        deleteShifts: _deleteShifts,
        deleteStockMovements: _deleteStockMovements,
        deleteExpenses: _deleteExpenses,
        deletePurchases: _deletePurchases,
        deleteDebts: _deleteDebts,
        deleteAttendanceLogs: _deleteAttendanceLogs,
        deleteActivityLogs: _deleteActivityLogs,
        deletePointLogs: _deletePointLogs,
        resetCustomerPoints: _resetCustomerPoints,
        resetProductStock: _resetProductStock,
      );

      // Refresh providers
      if (mounted) {
        if (_resetProductStock) {
          context.read<ProductProvider>().refreshProducts();
        }

        Navigator.of(context).pop(true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reset data berhasil! $totalWiped entitas data operasional telah dibersihkan.',
            ),
            backgroundColor: AppTheme.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal melakukan reset data: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.errorContainer,
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusDefault,
                      ),
                    ),
                    child: const Icon(
                      Icons.restore_page_rounded,
                      color: AppTheme.error,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reset Data Operasional Toko',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.error,
                              ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Pilih rentang waktu & centang data yang akan direset',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _isProcessing
                        ? null
                        : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Warning Note Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: AppTheme.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppTheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Perhatian: Tindakan ini permanen. Master data akun, produk, supplier, pelanggan, & diskon tetap aman (hanya data riwayat transaksi/operasional yang dipilih yang dihapus).',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.error.withValues(alpha: 0.9),
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Period Selection Chips
                    const Text(
                      'PILIH RENTANG WAKTU RESET',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.outline,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPeriodChip(
                          label: '1 Hari (Hari Ini)',
                          period: ResetPeriod.oneDay,
                        ),
                        _buildPeriodChip(
                          label: 'Mingguan (7 Hari)',
                          period: ResetPeriod.weekly,
                        ),
                        _buildPeriodChip(
                          label: 'Bulanan (30 Hari)',
                          period: ResetPeriod.monthly,
                        ),
                        _buildPeriodChip(
                          label: 'Kustom (Pilih Tanggal)',
                          period: ResetPeriod.custom,
                          onCustomTap: _pickDateRange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Date Range Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusDefault,
                        ),
                        border: Border.all(
                          color: AppTheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.date_range_rounded,
                            size: 18,
                            color: AppTheme.outline,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${dateFormat.format(_startDate)}  s/d  ${dateFormat.format(_endDate)}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_selectedPeriod == ResetPeriod.custom)
                            TextButton(
                              onPressed: _isProcessing ? null : _pickDateRange,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Ubah',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Data Checkboxes Header with Select All / Deselect All
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'PILIH MODUL OPERASIONAL (CENTANG SATU PER SATU)',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.outline,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: _isProcessing
                                  ? null
                                  : () => _selectAll(true),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Pilih Semua',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                            const Text(
                              ' | ',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.outline,
                              ),
                            ),
                            TextButton(
                              onPressed: _isProcessing
                                  ? null
                                  : () => _selectAll(false),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Batal Semua',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // 1. Transactions
                    _buildCheckboxItem(
                      title: '1. Riwayat Transaksi Penjualan & Nota POS',
                      subtitle:
                          'Menghapus seluruh invoice transaksi POS dan detail item belanja pada rentang tanggal',
                      value: _deleteTransactions,
                      onChanged: (val) =>
                          setState(() => _deleteTransactions = val),
                    ),

                    // 2. Shifts
                    _buildCheckboxItem(
                      title: '2. Riwayat Shift & Closing Kasir',
                      subtitle:
                          'Menghapus catatan buku shift, kas awal, kas masuk/keluar kasir, dan rekapan closing',
                      value: _deleteShifts,
                      onChanged: (val) => setState(() => _deleteShifts = val),
                    ),

                    // 3. Stock movements
                    _buildCheckboxItem(
                      title: '3. Riwayat Mutasi & Pergerakan Stok',
                      subtitle:
                          'Menghapus log penyesuaian stok, barang masuk, barang keluar, opname, dan retur',
                      value: _deleteStockMovements,
                      onChanged: (val) =>
                          setState(() => _deleteStockMovements = val),
                    ),

                    // 4. Expenses & Capital
                    _buildCheckboxItem(
                      title: '4. Biaya Operasional & Suntikan Modal Kas',
                      subtitle:
                          'Menghapus catatan pengeluaran beban/biaya toko dan setoran modal tambahan',
                      value: _deleteExpenses,
                      onChanged: (val) => setState(() => _deleteExpenses = val),
                    ),

                    // 5. Purchases & Supplier Returns
                    _buildCheckboxItem(
                      title: '5. Faktur Pembelian ke Supplier & Retur Beli',
                      subtitle:
                          'Menghapus riwayat transaksi pembelian restock barang ke supplier dan nota retur',
                      value: _deletePurchases,
                      onChanged: (val) =>
                          setState(() => _deletePurchases = val),
                    ),

                    // 6. Debts & Receivables
                    _buildCheckboxItem(
                      title: '6. Catatan Buku Hutang & Piutang Pelanggan',
                      subtitle:
                          'Menghapus riwayat hutang piutang usaha dan log pembayaran cicilan/pelunasan',
                      value: _deleteDebts,
                      onChanged: (val) => setState(() => _deleteDebts = val),
                    ),

                    // 7. Attendance
                    _buildCheckboxItem(
                      title: '7. Log Presensi & Absensi Karyawan',
                      subtitle:
                          'Menghapus riwayat check-in/out, keterlambatan, dan jam kerja pegawai',
                      value: _deleteAttendanceLogs,
                      onChanged: (val) =>
                          setState(() => _deleteAttendanceLogs = val),
                    ),

                    // 8. Activity Audit Logs
                    _buildCheckboxItem(
                      title: '8. Log Audit Aktivitas Pengguna (User Activity)',
                      subtitle:
                          'Menghapus jejak audit login, perubahan harga, hapus data, dan aksi kasir/admin',
                      value: _deleteActivityLogs,
                      onChanged: (val) =>
                          setState(() => _deleteActivityLogs = val),
                    ),

                    // 9. Point mutation logs
                    _buildCheckboxItem(
                      title: '9. Log Riwayat Perolehan/Tukar Poin Member',
                      subtitle:
                          'Menghapus histori mutasi poin reward pelanggan pada rentang tanggal',
                      value: _deletePointLogs,
                      onChanged: (val) =>
                          setState(() => _deletePointLogs = val),
                    ),

                    // 10. Reset customer points
                    _buildCheckboxItem(
                      title: '10. Nol-kan (0) Saldo Poin Seluruh Pelanggan',
                      subtitle:
                          'Mereset total poin loyalitas member kembali ke 0 (berlaku untuk semua pelanggan)',
                      value: _resetCustomerPoints,
                      onChanged: (val) =>
                          setState(() => _resetCustomerPoints = val),
                    ),

                    // 11. Reset product stock
                    _buildCheckboxItem(
                      title:
                          '11. Nol-kan (0) Stok Fisik Seluruh Katalog Produk',
                      subtitle:
                          'Mengubah nilai stok katalog produk menjadi 0 untuk persiapan stock opname baru',
                      value: _resetProductStock,
                      onChanged: (val) =>
                          setState(() => _resetProductStock = val),
                    ),

                    const SizedBox(height: 16),

                    // Type "HAPUS" Confirmation Input
                    const Text(
                      'KONFIRMASI TINDAKAN',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.error,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _confirmController,
                      decoration: const InputDecoration(
                        hintText: 'Ketik "HAPUS" untuk menyetujui',
                        prefixIcon: Icon(
                          Icons.security_rounded,
                          color: AppTheme.error,
                        ),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

            // Action Buttons Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _handleExecuteReset,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Reset Sekarang'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: value
            ? AppTheme.error.withValues(alpha: 0.04)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: CheckboxListTile(
        value: value,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        activeColor: AppTheme.error,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: value ? AppTheme.error : AppTheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 10.5, color: AppTheme.outline),
        ),
        onChanged: _isProcessing ? null : (val) => onChanged(val ?? false),
      ),
    );
  }

  Widget _buildPeriodChip({
    required String label,
    required ResetPeriod period,
    VoidCallback? onCustomTap,
  }) {
    final isSelected = _selectedPeriod == period;

    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppTheme.onSurface,
      ),
      selected: isSelected,
      selectedColor: AppTheme.error,
      backgroundColor: AppTheme.surfaceContainerLow,
      side: BorderSide(
        color: isSelected ? AppTheme.error : AppTheme.outlineVariant,
      ),
      onSelected: (selected) {
        if (selected) {
          if (period == ResetPeriod.custom && onCustomTap != null) {
            onCustomTap();
          } else {
            _applyPeriodPreset(period);
          }
        }
      },
    );
  }
}
