import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/utils/currency_formatter.dart';
import '../models/finance_model.dart';
import '../models/store_settings_model.dart';
import '../models/transaction_model.dart';

/// DTO for holding aggregated reporting metrics for PDF & Excel exports.
class ReportExportData {
  final StoreSettingsModel settings;
  final DateTime? startDate;
  final DateTime? endDate;
  final double totalRevenue;
  final double totalCost;
  final double grossProfit;
  final double operationalExpenses;
  final double netProfit;
  final List<TransactionModel> transactions;
  final Map<String, double> paymentBreakdown;
  final Map<String, double> cashierSales;
  final List<MapEntry<String, int>> topProducts;
  final List<DebtModel> debts;

  const ReportExportData({
    required this.settings,
    this.startDate,
    this.endDate,
    required this.totalRevenue,
    required this.totalCost,
    required this.grossProfit,
    required this.operationalExpenses,
    required this.netProfit,
    required this.transactions,
    required this.paymentBreakdown,
    required this.cashierSales,
    required this.topProducts,
    this.debts = const [],
  });
}

/// Service handling the generation and file export of Financial Reports in Excel (.xlsx) and PDF (.pdf).
class ReportExportService {
  static Future<Directory> _getExportDirectory() async {
    if (Platform.isAndroid) {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) return extDir;
    }
    return await getApplicationDocumentsDirectory();
  }

  /// Menuliskan Header Identitas Toko yang lengkap dan rapi di bagian atas sheet Excel
  static void _writeStoreHeader(
    Sheet sheet,
    StoreSettingsModel settings,
    String sheetTitle,
    String periodStr,
    String generatedAt,
  ) {
    sheet.appendRow([TextCellValue(settings.storeName.toUpperCase())]);
    if (settings.storeAddress.isNotEmpty) {
      sheet.appendRow([TextCellValue(settings.storeAddress)]);
    }
    if (settings.storePhone.isNotEmpty) {
      sheet.appendRow([TextCellValue('Telp/WhatsApp: ${settings.storePhone}')]);
    }
    if (settings.receiptFooter.isNotEmpty) {
      sheet.appendRow([TextCellValue(settings.receiptFooter)]);
    }
    sheet.appendRow([TextCellValue('DOKUMEN: $sheetTitle')]);
    sheet.appendRow([
      TextCellValue('Periode: $periodStr | Tanggal Cetak: $generatedAt'),
    ]);
    sheet.appendRow([TextCellValue('')]); // Baris kosong pemisah
  }

  /// Exports financial reports into Microsoft Excel (.xlsx) format and opens it.
  static Future<String?> exportToExcel(ReportExportData data) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.delete(defaultSheet);
    }

    final dateFmt = DateFormat('dd/MM/yyyy');
    final periodStr = (data.startDate != null && data.endDate != null)
        ? '${dateFmt.format(data.startDate!)} - ${dateFmt.format(data.endDate!)}'
        : 'Semua Periode';
    final generatedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // ─── Sheet 1: Ringkasan Eksekutif ───────────────────────────
    final s1 = excel['Ringkasan'];
    excel.setDefaultSheet('Ringkasan');

    _writeStoreHeader(
      s1,
      data.settings,
      'RINGKASAN LABA & RUGI (P&L)',
      periodStr,
      generatedAt,
    );
    s1.appendRow([
      TextCellValue('Metrik Keuangan'),
      TextCellValue('Nominal (Rp)'),
    ]);
    s1.appendRow([
      TextCellValue('Total Omset Penjualan (Revenue)'),
      DoubleCellValue(data.totalRevenue),
    ]);
    s1.appendRow([
      TextCellValue('Total Harga Pokok Penjualan (HPP)'),
      DoubleCellValue(data.totalCost),
    ]);
    s1.appendRow([
      TextCellValue('Laba Kotor (Gross Profit)'),
      DoubleCellValue(data.grossProfit),
    ]);
    s1.appendRow([
      TextCellValue('Biaya Operasional (Expenses)'),
      DoubleCellValue(data.operationalExpenses),
    ]);
    s1.appendRow([
      TextCellValue('Laba Bersih Usaha (Net Profit)'),
      DoubleCellValue(data.netProfit),
    ]);
    s1.appendRow([
      TextCellValue('Total Transaksi Berhasil'),
      IntCellValue(data.transactions.length),
    ]);

    // ─── Sheet 2: Metode Pembayaran ─────────────────────────────
    final s2 = excel['Metode Pembayaran'];
    _writeStoreHeader(
      s2,
      data.settings,
      'REKAPITULASI METODE PEMBAYARAN',
      periodStr,
      generatedAt,
    );
    s2.appendRow([
      TextCellValue('Metode Pembayaran'),
      TextCellValue('Total Penjualan (Rp)'),
    ]);
    data.paymentBreakdown.forEach((method, total) {
      s2.appendRow([TextCellValue(method), DoubleCellValue(total)]);
    });

    // ─── Sheet 3: Penjualan Kasir ───────────────────────────────
    final s3 = excel['Penjualan Kasir'];
    _writeStoreHeader(
      s3,
      data.settings,
      'REKAPITULASI PENJUALAN PER KASIR',
      periodStr,
      generatedAt,
    );
    s3.appendRow([
      TextCellValue('Nama Kasir'),
      TextCellValue('Total Penjualan (Rp)'),
    ]);
    data.cashierSales.forEach((cashier, total) {
      s3.appendRow([TextCellValue(cashier), DoubleCellValue(total)]);
    });

    // ─── Sheet 4: Top Produk Terlaris ───────────────────────────
    final s4 = excel['Top Produk'];
    _writeStoreHeader(
      s4,
      data.settings,
      'PRODUK TERLARIS (TOP PRODUK)',
      periodStr,
      generatedAt,
    );
    s4.appendRow([
      TextCellValue('Peringkat'),
      TextCellValue('Nama Produk'),
      TextCellValue('Jumlah Terjual (Qty)'),
    ]);
    for (int i = 0; i < data.topProducts.length; i++) {
      final entry = data.topProducts[i];
      s4.appendRow([
        IntCellValue(i + 1),
        TextCellValue(entry.key),
        IntCellValue(entry.value),
      ]);
    }

    // ─── Sheet 5: Rincian Transaksi ─────────────────────────────
    final s5 = excel['Daftar Transaksi'];
    _writeStoreHeader(
      s5,
      data.settings,
      'DAFTAR RINCIAN TRANSAKSI PENJUALAN',
      periodStr,
      generatedAt,
    );
    s5.appendRow([
      TextCellValue('No. Nota'),
      TextCellValue('Tanggal & Waktu'),
      TextCellValue('Kasir'),
      TextCellValue('Pelanggan'),
      TextCellValue('Status'),
      TextCellValue('Metode Bayar'),
      TextCellValue('Total Tagihan (Rp)'),
      TextCellValue('Nominal Terbayar (Rp)'),
    ]);
    final dtFmt = DateFormat('dd/MM/yyyy HH:mm');
    for (final tx in data.transactions) {
      s5.appendRow([
        TextCellValue(tx.invoiceNumber),
        TextCellValue(dtFmt.format(tx.createdAt)),
        TextCellValue(tx.cashierName),
        TextCellValue(tx.customerName ?? 'Pelanggan Umum'),
        TextCellValue(tx.status == 'completed' ? 'Lunas' : tx.status),
        TextCellValue(tx.paymentMethod),
        DoubleCellValue(tx.total),
        DoubleCellValue(tx.paidAmount),
      ]);
    }

    // ─── Sheet 6: Utang & Piutang ───────────────────────────────
    final s6 = excel['Utang & Piutang'];
    _writeStoreHeader(
      s6,
      data.settings,
      'LAPORAN PIUTANG PELANGGAN & UTANG SUPPLIER',
      periodStr,
      generatedAt,
    );

    // 1. Piutang Pelanggan Table
    s6.appendRow([TextCellValue('--- DAFTAR PIUTANG PELANGGAN (KASBON) ---')]);
    s6.appendRow([
      TextCellValue('No. Nota/Ref'),
      TextCellValue('Nama Pelanggan'),
      TextCellValue('No. WhatsApp/HP'),
      TextCellValue('Alamat'),
      TextCellValue('Total Piutang (Rp)'),
      TextCellValue('Sudah Terbayar (Rp)'),
      TextCellValue('Sisa Piutang (Rp)'),
      TextCellValue('Jatuh Tempo'),
      TextCellValue('Status'),
    ]);

    final customerReceivables =
        data.debts.where((d) => d.type == 'piutang').toList();
    if (customerReceivables.isEmpty) {
      s6.appendRow([TextCellValue('Tidak ada data piutang pelanggan.')]);
    } else {
      for (final d in customerReceivables) {
        final dueStr =
            d.dueDate != null ? dateFmt.format(d.dueDate!) : 'Belum Ditentukan';
        final statusStr = d.isPaid
            ? 'Lunas'
            : (d.paidAmount > 0 ? 'Sedang Dicicil' : 'Belum Lunas');
        s6.appendRow([
          TextCellValue(d.referenceNo),
          TextCellValue(d.partyName),
          TextCellValue(d.phone.isNotEmpty ? d.phone : '-'),
          TextCellValue(d.address.isNotEmpty ? d.address : '-'),
          DoubleCellValue(d.amount),
          DoubleCellValue(d.paidAmount),
          DoubleCellValue(d.remainingAmount),
          TextCellValue(dueStr),
          TextCellValue(statusStr),
        ]);
      }
    }

    s6.appendRow([TextCellValue('')]);
    s6.appendRow([TextCellValue('')]);

    // 2. Utang Supplier Table
    s6.appendRow([TextCellValue('--- DAFTAR UTANG KEPADA SUPPLIER ---')]);
    s6.appendRow([
      TextCellValue('No. Pembelian/Ref'),
      TextCellValue('Nama Supplier'),
      TextCellValue('Total Utang (Rp)'),
      TextCellValue('Sudah Dibayar (Rp)'),
      TextCellValue('Sisa Utang (Rp)'),
      TextCellValue('Jatuh Tempo'),
      TextCellValue('Status'),
    ]);

    final supplierDebts = data.debts.where((d) => d.type == 'utang').toList();
    if (supplierDebts.isEmpty) {
      s6.appendRow([TextCellValue('Tidak ada data utang supplier.')]);
    } else {
      for (final d in supplierDebts) {
        final dueStr =
            d.dueDate != null ? dateFmt.format(d.dueDate!) : 'Belum Ditentukan';
        final statusStr = d.isPaid
            ? 'Lunas'
            : (d.paidAmount > 0 ? 'Sedang Dicicil' : 'Belum Lunas');
        s6.appendRow([
          TextCellValue(d.referenceNo),
          TextCellValue(d.partyName),
          DoubleCellValue(d.amount),
          DoubleCellValue(d.paidAmount),
          DoubleCellValue(d.remainingAmount),
          TextCellValue(dueStr),
          TextCellValue(statusStr),
        ]);
      }
    }

    final bytes = excel.save();
    if (bytes == null) return null;

    final fileName =
        'Laporan_Keuangan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    final dir = await _getExportDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    await OpenFilex.open(file.path);
    return file.path;
  }

  /// Exports financial reports into a clean, professional PDF document via Printing.
  static Future<void> exportToPdf(ReportExportData data) async {
    final pdf = pw.Document();
    final dateFmt = DateFormat('dd/MM/yyyy');
    final periodStr = (data.startDate != null && data.endDate != null)
        ? '${dateFmt.format(data.startDate!)} - ${dateFmt.format(data.endDate!)}'
        : 'Semua Periode';
    final generatedAtStr = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(DateTime.now());

    final customerReceivables =
        data.debts.where((d) => d.type == 'piutang').toList();
    final supplierDebts = data.debts.where((d) => d.type == 'utang').toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Kop / Header Toko
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    data.settings.storeName,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (data.settings.storeAddress.isNotEmpty)
                    pw.Text(
                      data.settings.storeAddress,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  if (data.settings.storePhone.isNotEmpty)
                    pw.Text(
                      'Telp/WA: ${data.settings.storePhone}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'LAPORAN KEUANGAN',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo900,
                    ),
                  ),
                  pw.Text(
                    'Periode: $periodStr',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    'Dicetak: $generatedAtStr',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 1.5, color: PdfColors.indigo),
          pw.SizedBox(height: 14),

          // 1. Ringkasan Laba Rugi
          pw.Text(
            '1. RINGKASAN LABA & RUGI (P&L)',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Deskripsi Indikator', 'Nominal (Rp)'],
            data: [
              [
                'Total Penjualan Kotor (Omset)',
                CurrencyFormatter.format(data.totalRevenue),
              ],
              [
                'Total Harga Pokok Penjualan (HPP)',
                CurrencyFormatter.format(data.totalCost),
              ],
              [
                'Laba Kotor (Gross Profit)',
                CurrencyFormatter.format(data.grossProfit),
              ],
              [
                'Total Biaya Operasional / Beban Usaha',
                CurrencyFormatter.format(data.operationalExpenses),
              ],
              [
                'Laba Bersih Usaha (Net Profit)',
                CurrencyFormatter.format(data.netProfit),
              ],
              [
                'Jumlah Transaksi Berhasil',
                '${data.transactions.length} Transaksi',
              ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 10,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.indigo700,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9.5),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {1: pw.Alignment.centerRight},
          ),
          pw.SizedBox(height: 18),

          // 2. Rekapitulasi Kasir & Metode Pembayaran
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '2. METODE PEMBAYARAN',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.TableHelper.fromTextArray(
                      headers: ['Metode', 'Total'],
                      data: data.paymentBreakdown.entries
                          .map(
                            (e) => [
                              e.key,
                              CurrencyFormatter.format(e.value),
                            ],
                          )
                          .toList(),
                      headerStyle: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        fontSize: 9,
                      ),
                      headerDecoration: const pw.BoxDecoration(
                        color: PdfColors.blueGrey800,
                      ),
                      cellStyle: const pw.TextStyle(fontSize: 8.5),
                      cellAlignments: {1: pw.Alignment.centerRight},
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '3. PENJUALAN PER KASIR',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.TableHelper.fromTextArray(
                      headers: ['Kasir', 'Total'],
                      data: data.cashierSales.entries
                          .map(
                            (e) => [
                              e.key,
                              CurrencyFormatter.format(e.value),
                            ],
                          )
                          .toList(),
                      headerStyle: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        fontSize: 9,
                      ),
                      headerDecoration: const pw.BoxDecoration(
                        color: PdfColors.blueGrey800,
                      ),
                      cellStyle: const pw.TextStyle(fontSize: 8.5),
                      cellAlignments: {1: pw.Alignment.centerRight},
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),

          // 3. Top Produk Terlaris
          pw.Text(
            '4. PRODUK TERLARIS (TOP PRODUK)',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['No', 'Nama Produk', 'Jumlah Terjual'],
            data: data.topProducts.take(10).toList().asMap().entries.map((e) {
              return ['${e.key + 1}', e.value.key, '${e.value.value} pcs'];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 9,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignments: {
              0: pw.Alignment.center,
              2: pw.Alignment.centerRight,
            },
          ),

          // 4. Utang & Piutang Section in PDF
          if (customerReceivables.isNotEmpty || supplierDebts.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              '5. DAFTAR PIUTANG PELANGGAN & UTANG SUPPLIER',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            if (customerReceivables.isNotEmpty) ...[
              pw.Text(
                '• Piutang Pelanggan (Kasbon Belum Lunas)',
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.amber900,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.TableHelper.fromTextArray(
                headers: ['Ref Nota', 'Nama Pelanggan', 'Total', 'Sisa Piutang', 'Status'],
                data: customerReceivables.take(8).map((d) {
                  return [
                    d.referenceNo,
                    d.partyName,
                    CurrencyFormatter.format(d.amount),
                    CurrencyFormatter.format(d.remainingAmount),
                    d.isPaid ? 'Lunas' : (d.paidAmount > 0 ? 'Dicicil' : 'Belum Lunas'),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 8.5,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignments: {2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight},
              ),
              pw.SizedBox(height: 8),
            ],
            if (supplierDebts.isNotEmpty) ...[
              pw.Text(
                '• Utang Kepada Supplier',
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red900,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.TableHelper.fromTextArray(
                headers: ['Ref Beli', 'Nama Supplier', 'Total', 'Sisa Utang', 'Status'],
                data: supplierDebts.take(8).map((d) {
                  return [
                    d.referenceNo,
                    d.partyName,
                    CurrencyFormatter.format(d.amount),
                    CurrencyFormatter.format(d.remainingAmount),
                    d.isPaid ? 'Lunas' : (d.paidAmount > 0 ? 'Dicicil' : 'Belum Lunas'),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 8.5,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.red800),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignments: {2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight},
              ),
            ],
          ],
        ],
      ),
    );

    final fileName =
        'Laporan_Keuangan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: fileName,
    );
  }
}
