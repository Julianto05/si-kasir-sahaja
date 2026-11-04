/// Application-wide constants for SiKasirSahaja POS.
///
/// Centralizes string literals, collection names, and configuration
/// values to avoid magic strings throughout the codebase.
library;

class AppConstants {
  AppConstants._();

  // ─── App Info ───────────────────────────────────────────────
  static const String appName = 'SiKasirSahaja';
  static const String appVersion = '1.1.0';

  // ─── User Roles ─────────────────────────────────────────────
  static const String roleAdmin = 'admin';
  static const String roleCashier = 'kasir';

  // ─── Granular Permissions (PRD Section 3) ───────────────────
  static const String permManageStock = 'manage_stock';
  static const String permViewReports = 'view_reports';
  static const String permManagePurchases = 'manage_purchases';
  static const String permManageCustomers = 'manage_customers';
  static const String permManageFinance = 'manage_finance';
  static const String permManageDiscounts = 'manage_discounts';

  static const Map<String, String> permissionLabels = {
    permManageStock: 'Kelola Stok & Inventaris',
    permViewReports: 'Lihat Laporan & Analitik',
    permManagePurchases: 'Kelola Pembelian & Supplier',
    permManageCustomers: 'Kelola Pelanggan & Member',
    permManageFinance: 'Kelola Pengeluaran & Keuangan',
    permManageDiscounts: 'Kelola Diskon & Promo',
  };

  static const List<String> allPermissions = [
    permManageStock,
    permViewReports,
    permManagePurchases,
    permManageCustomers,
    permManageFinance,
    permManageDiscounts,
  ];

  static String permissionLabel(String key) => permissionLabels[key] ?? key;

  // ─── Firestore Collections ──────────────────────────────────
  static const String usersCollection = 'users';
  static const String categoriesCollection = 'categories';
  static const String productsCollection = 'products';
  static const String transactionsCollection = 'transactions';
  static const String transactionItemsSubcollection = 'items';
  static const String stockMovementsCollection = 'stock_movements';
  static const String storeSettingsCollection = 'store_settings';
  static const String shiftsCollection = 'shifts';

  // New Collections (PRD v1.1.0 Section 8.1)
  static const String suppliersCollection = 'suppliers';
  static const String purchasesCollection = 'purchases';
  static const String purchaseReturnsCollection = 'purchase_returns';
  static const String customersCollection = 'customers';
  static const String pointLogsCollection = 'point_logs';
  static const String expensesCollection = 'expenses';
  static const String capitalEntriesCollection = 'capital_entries';
  static const String debtsCollection = 'debts';
  static const String debtPaymentsCollection = 'debt_payments';
  static const String attendanceLogsCollection = 'attendance_logs';
  static const String workSchedulesCollection = 'work_schedules';
  static const String activityLogsCollection = 'activity_logs';
  static const String discountsCollection = 'discounts';

  // ─── Storage Paths ──────────────────────────────────────────
  static const String productImagesPath = 'products';
  static const String storeLogoPath = 'store';

  // ─── Transaction Status ─────────────────────────────────────
  static const String statusCompleted = 'completed'; // Lunas
  static const String statusUnpaid = 'unpaid'; // Belum Lunas
  static const String statusHold = 'hold';
  static const String statusCancelled = 'cancelled';
  static const String statusRefunded = 'refunded';

  // ─── Payment Methods ────────────────────────────────────────
  static const List<String> defaultPaymentMethods = [
    'Cash',
    'QRIS',
    'Transfer',
    'Debit',
    'Kredit',
    'Piutang',
  ];

  // ─── Stock Movement Types (PRD Section 8.2) ─────────────────
  static const String stockIn = 'in';
  static const String stockOut = 'out';
  static const String stockAdjustment = 'adjustment';
  static const String stockSale = 'sale';
  static const String stockRefund = 'refund';
  static const String stockDamaged = 'damaged';
  static const String stockExpired = 'expired';
  static const String stockPurchaseIn = 'purchase_in';
  static const String stockPurchaseReturn = 'purchase_return';

  // ─── Expense Categories (PRD Section 5.9) ───────────────────
  static const List<String> expenseCategories = [
    'operasional',
    'listrik_air',
    'transportasi',
    'gaji',
    'lainnya',
  ];

  static String expenseCategoryLabel(String key) {
    switch (key) {
      case 'operasional':
        return 'Biaya Operasional';
      case 'listrik_air':
        return 'Listrik & Air';
      case 'transportasi':
        return 'Transportasi';
      case 'gaji':
        return 'Gaji Karyawan';
      case 'lainnya':
      default:
        return 'Lainnya';
    }
  }
}
