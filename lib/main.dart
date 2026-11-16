import 'package:flutter/material.dart';

import 'pages/add_product_page.dart';
import 'pages/employees_page.dart';
import 'pages/expenses_page.dart';
import 'pages/home_page.dart';
import 'pages/inventory_page.dart' show InventoryPage, routeObserver;
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
        scaffoldBackgroundColor: ShopColors.surface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ShopColors.primary,
          primary: ShopColors.primary,
          secondary: ShopColors.orange,
          surface: ShopColors.surface,
        ),
        fontFamily: 'Roboto',
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
      initialRoute: '/welcome',
      navigatorObservers: [routeObserver],
      routes: {
        '/welcome': (_) => const LandingPage(),
        '/register': (_) => const ShopRegistrationPage(),
        '/login': (_) => const LoginPage(),
        '/home': (_) => const HomePage(),
        '/inventory': (_) => const InventoryPage(),
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
