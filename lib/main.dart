import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/attendance_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/category_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/discount_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/pos_provider.dart';
import 'providers/product_provider.dart';
import 'providers/purchase_provider.dart';
import 'providers/shift_provider.dart';
import 'providers/stock_provider.dart';
import 'providers/store_settings_provider.dart';
import 'providers/supplier_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/user_provider.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/cashier/cashier_dashboard_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'widgets/loading_overlay.dart';

/// SiKasirSahaja — Point of Sale Application (v1.1.0 Gabungan Pusaka Rinjani).
///
/// Entry point that initializes Firebase, sets up Provider-based state
/// management, and routes users based on authentication state and role:
///
/// - Unauthenticated → [LoginScreen]
/// - Admin → [AdminDashboardScreen]
/// - Kasir → [CashierDashboardScreen]
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Indonesian locale data for date formatting
  await initializeDateFormatting('id_ID', null);

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Allow all orientations (portrait and landscape)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surfaceContainerLowest,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const SiKasirSahajaApp());
}

class SiKasirSahajaApp extends StatelessWidget {
  const SiKasirSahajaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => PosProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => StockProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => StoreSettingsProvider()),
        ChangeNotifierProvider(create: (_) => ShiftProvider()),
        // PRD v1.1.0 Section 4 New Providers:
        ChangeNotifierProvider(create: (_) => SupplierProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => DiscountProvider()),
      ],
      child: MaterialApp(
        title: 'SiKasirSahaja',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}

/// Routes users based on authentication state and role with smooth transitions.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    Widget screen;
    switch (authProvider.status) {
      case AuthStatus.uninitialized:
        screen = const LoadingOverlay(
          key: ValueKey('uninitialized'),
          message: 'Memuat aplikasi...',
        );

      case AuthStatus.authenticating:
        screen = const LoadingOverlay(
          key: ValueKey('authenticating'),
          message: 'Sedang masuk...',
        );

      case AuthStatus.authenticated:
        if (authProvider.isAdmin) {
          screen = const AdminDashboardScreen(key: ValueKey('admin'));
        } else {
          screen = const CashierDashboardScreen(key: ValueKey('cashier'));
        }

      case AuthStatus.unauthenticated:
        screen = const LoginScreen(key: ValueKey('login'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: screen,
    );
  }
}
