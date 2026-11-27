import 'package:flutter/material.dart';

import 'pages/add_product_page.dart';
import 'pages/employees_page.dart';
import 'pages/expenses_page.dart';
import 'pages/home_page.dart';
import 'pages/inventory_page.dart' show InventoryPage, routeObserver;
import 'pages/inventory_report_page.dart';
import 'pages/layby_page.dart';
import 'pages/landing_page.dart';
import 'pages/login_page.dart';
import 'pages/reports_page.dart';
import 'pages/sale_success_page.dart';
import 'pages/sales_page.dart';
import 'pages/settings_page.dart';
import 'pages/shop_registration_page.dart';
import 'pages/suppliers_page.dart';
import 'services/urban7_branding.dart';
import 'widgets/shop_ui.dart';

void main() => runApp(const Urban7App());

class Urban7App extends StatelessWidget {
  const Urban7App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Urban7.appName,
      debugShowCheckedModeBanner: false,
       theme: ThemeData(
         useMaterial3: true,
         brightness: Brightness.light,
         scaffoldBackgroundColor: ShopColors.surface,
         colorScheme: ColorScheme.fromSeed(
           seedColor: ShopColors.primary,
           primary: ShopColors.primary,
           secondary: ShopColors.orange,
           surface: ShopColors.surface,
           brightness: Brightness.light,
         ),
         // No fontFamily here on purpose: Roboto is not bundled in
         // pubspec.yaml and is not installed on Windows, so declaring it
         // forces a fallback font with synthesized (fuzzy) bold weights.
         // Omitting it uses each platform's crisp native font.
textTheme: TextTheme(
            headlineLarge: TextStyle(
              color: ShopColors.text,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
            headlineMedium: TextStyle(
              color: ShopColors.text,
              fontWeight: FontWeight.w800,
              letterSpacing: -.4,
            ),
            titleLarge: TextStyle(
              color: ShopColors.text,
              fontWeight: FontWeight.w700,
              letterSpacing: -.2,
            ),
            titleMedium: TextStyle(
              color: ShopColors.text,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: TextStyle(
              color: ShopColors.text,
              height: 1.4,
            ),
            bodyMedium: TextStyle(
              color: ShopColors.text,
              height: 1.4,
            ),
            labelLarge: TextStyle(
              color: ShopColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          titleTextStyle: const TextStyle(
            color: ShopColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -.2,
          ),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(Colors.white),
            elevation: WidgetStatePropertyAll(12),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            padding: WidgetStatePropertyAll(
              const EdgeInsets.symmetric(vertical: 6),
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: ShopColors.text,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          showDragHandle: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
        ),
      ),
         darkTheme: ThemeData(
         useMaterial3: true,
         brightness: Brightness.dark,
         colorScheme: ColorScheme.fromSeed(
           seedColor: ShopColors.primary,
           primary: ShopColors.primary,
           secondary: ShopColors.orange,
           brightness: Brightness.dark,
         ),
       ),
       // Force the light theme: this POS is designed light-only, and with
       // ThemeMode.system the app turns dark on Windows machines that use
       // dark mode, which makes buttons/nav labels look washed out and
       // typed text appear grey instead of black.
       themeMode: ThemeMode.light,
       initialRoute: '/welcome',
      navigatorObservers: [routeObserver],
      routes: {
        '/welcome': (_) => const LandingPage(),
        '/register': (_) => const ShopRegistrationPage(),
        '/login': (_) => const LoginPage(),
        '/home': (_) => const HomePage(),
        '/inventory': (_) => const InventoryPage(),
        '/inventory/report': (_) => const InventoryReportPage(),
        '/product/new': (_) => const AddProductPage(),
        '/sales': (_) => const SalesPage(),
        '/laybys': (_) => const LaybyPage(),
        '/sale/success': (_) => const SaleSuccessPage(),
        '/reports': (_) => const ReportsPage(),
        '/settings': (_) => const SettingsPage(),
        '/suppliers': (_) => const SuppliersPage(),
        '/expenses': (_) => const ExpensesPage(),
        '/employees': (_) => const EmployeesPage(),
      },
    );
  }
}
