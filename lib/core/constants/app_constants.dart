/// Application-wide constants for SiKasirSahaja POS.
///
/// Centralizes string literals, collection names, and configuration
/// values to avoid magic strings throughout the codebase.
library;

class AppConstants {
  AppConstants._();

  // ─── App Info ───────────────────────────────────────────────
  static const String appName = 'SiKasirSahaja';
  static const String appVersion = '1.0.0';

  // ─── User Roles ─────────────────────────────────────────────
  static const String roleAdmin = 'admin';
  static const String roleCashier = 'kasir';

  // ─── Firestore Collections ──────────────────────────────────
  static const String usersCollection = 'users';
  static const String categoriesCollection = 'categories';
  static const String productsCollection = 'products';
  static const String transactionsCollection = 'transactions';
  static const String transactionItemsSubcollection = 'items';
  static const String stockMovementsCollection = 'stock_movements';
  static const String storeSettingsCollection = 'store_settings';

  // ─── Storage Paths ──────────────────────────────────────────
  static const String productImagesPath = 'products';
  static const String storeLogoPath = 'store';

  // ─── Transaction Status ─────────────────────────────────────
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';
  static const String statusRefunded = 'refunded';

  // ─── Payment Methods ────────────────────────────────────────
  static const List<String> defaultPaymentMethods = [
    'Cash',
    'QRIS',
    'Transfer',
    'Debit',
    'Kredit',
  ];

  // ─── Stock Movement Types ───────────────────────────────────
  static const String stockIn = 'in';
  static const String stockOut = 'out';
  static const String stockAdjustment = 'adjustment';
  static const String stockSale = 'sale';
  static const String stockRefund = 'refund';
}
