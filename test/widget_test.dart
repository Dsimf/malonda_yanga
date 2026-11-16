import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:malonda_yanga/main.dart';
import 'package:malonda_yanga/pages/add_product_page.dart';
import 'package:malonda_yanga/pages/login_page.dart' show LoginPage, loginPrefsDisabledForTests;
import 'package:malonda_yanga/pages/employees_page.dart';
import 'package:malonda_yanga/pages/layby_page.dart';
import 'package:malonda_yanga/pages/reports_page.dart';
import 'package:malonda_yanga/pages/sale_success_page.dart';
import 'package:malonda_yanga/pages/sales_page.dart';
import 'package:malonda_yanga/pages/shop_registration_page.dart';
import 'package:malonda_yanga/services/api_client.dart';
import 'package:malonda_yanga/widgets/shop_ui.dart';

void main() {
  setUp(() async {
    loginPrefsDisabledForTests = true;
    _lastLoginRequest = null;
    _lastRegisterRequest = null;
    _lastProductRequest = null;
    _lastSupplierRequest = null;
    ApiClient.configureForTesting(MockClient(_mockApi));
    await ApiClient.login('owner@example.com', 'demo-password');
  });

  test('API login sends credentials and receives the shop session', () async {
    final result = await ApiClient.login('owner@example.com', 'secret123');

    expect(jsonDecode(_lastLoginRequest!.body), {
      'email': 'owner@example.com',
      'password': 'secret123',
    });
    expect(result['shop']['id'], _shop['id']);
    expect(result['access_token'], 'test-access-token');
  });

  test('registration sends shop details to the backend', () async {
    final result = await ApiClient.register({
      'shop_name': 'Test Shop',
      'owner_name': 'Test Owner',
      'email': 'owner@example.com',
      'password': 'secret123',
      'location': 'Lusaka',
      'business_type': 'Boutique',
    });

    expect(result['requires_email_confirmation'], isFalse);
    final request = jsonDecode(_lastRegisterRequest!.body) as Map;
    expect(request['shop_name'], 'Test Shop');
    expect(request['owner_name'], 'Test Owner');
  });

  test('supplier create request sends supplier details', () async {
    final result = await ApiClient.createSupplier({
      'name': 'Textile House',
      'contact_name': 'A. Supplier',
      'phone': '+260 97 000 0000',
    });

    expect(result['name'], 'Textile House');
    final request = jsonDecode(_lastSupplierRequest!.body) as Map;
    expect(request['contact_name'], 'A. Supplier');
  });

  testWidgets('login form rejects empty credentials', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: const LoginPage(),
        routes: {'/home': (_) => const Scaffold(body: Text('Signed in'))},
      ),
    );

    await tester.ensureVisible(find.text('Sign In to Shop'));
    await tester.tap(find.text('Sign In to Shop'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('loginError')), findsOneWidget);
    expect(find.text('Signed in'), findsNothing);
  });

  testWidgets('login remember-me checkbox toggles', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: const LoginPage(),
        routes: {'/home': (_) => const Scaffold(body: Text('Signed in'))},
      ),
    );

    final checkbox = tester.widget<Checkbox>(
      find.byKey(const Key('rememberMeCheckbox')),
    );
    expect(checkbox.value, isFalse);

    await tester.tap(find.byKey(const Key('rememberMeCheckbox')));
    await tester.pump();

    expect(
      tester
          .widget<Checkbox>(find.byKey(const Key('rememberMeCheckbox')))
          .value,
      isTrue,
    );
  });

  testWidgets('landing page opens login and cashier routes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const Urban7App());

    expect(
      find.textContaining('Run Your Fashion Store'),
      findsOneWidget,
    );
    final background = tester.widget<Image>(
      find.byKey(const Key('landingBackgroundImage')),
    );
    expect(background.fit, BoxFit.cover);
    // The hero panel no longer paints a decoration; just check the key exists.
    expect(find.byKey(const Key('landingHeroPanel')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('landingSignInButton')));
    await tester.tap(find.byKey(const Key('landingSignInButton')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Welcome back!'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('loginEmailField')),
      'owner@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('loginPasswordField')),
      'demo-password',
    );
    await tester.ensureVisible(find.text('Sign In to Shop'));
    await tester.tap(find.text('Sign In to Shop'));
    await tester.pumpAndSettle();
    expect(find.text('Start Sales / Cashier'), findsOneWidget);

    Navigator.of(tester.element(find.text('Start Sales / Cashier')))
        .pushNamed('/sales');
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(
      find.text('Your cart is empty. Add a product to begin.'),
      findsOneWidget,
    );
    expect(find.text('Men’s T-Shirt (K120)'), findsOneWidget);
  });

  testWidgets('all ten page routes build', (WidgetTester tester) async {
    await tester.pumpWidget(const Urban7App());

    const routes = [
      '/welcome',
      '/register',
      '/login',
      '/home',
      '/inventory',
      '/product/new',
      '/sales',
      '/sale/success',
      '/reports',
      '/settings',
      '/suppliers',
    ];

    for (final route in routes) {
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Route $route failed');
      navigator.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('sales supports variants and percentage discounts', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: const SalesPage(),
        routes: {'/sale/success': (_) => const SaleSuccessPage()},
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Men’s T-Shirt (K120)'));
    await tester.tap(find.text('Men’s T-Shirt (K120)'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hoodie Jacket (K350)'));
    await tester.tap(find.text('Hoodie Jacket (K350)'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('options-Men’s T-Shirt')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saleSizeDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('32').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saleColorDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cobalt Blue').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save options'));
    await tester.pumpAndSettle();
    expect(find.text('32 · Cobalt Blue'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('discountPercentField')));
    await tester.enterText(find.byKey(const Key('discountPercentField')), '10');
    await tester.pumpAndSettle();
    expect(find.text('-K47'), findsOneWidget);
    expect(find.text('Complete Sale (K423)'), findsOneWidget);

    await tester.ensureVisible(find.text('Complete Sale (K423)'));
    await tester.tap(find.text('Complete Sale (K423)'));
    await tester.pumpAndSettle();
    expect(find.text('K423.00'), findsWidgets);
    expect(find.text('-K47.00'), findsOneWidget);
    expect(
      find.text('Size 32 • Color: Cobalt Blue (1 × K120.00)'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('add product supports numeric sizes', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AddProductPage()));
    await tester.pumpAndSettle();

    final size32 = find.byKey(const Key('productSize32'));
    await tester.ensureVisible(size32);
    await tester.tap(size32);
    await tester.pumpAndSettle();

    final sizeMaterial = tester.widget<Material>(
      find.descendant(of: size32, matching: find.byType(Material)).first,
    );
    expect(sizeMaterial.color, ShopColors.primary);
  });

  testWidgets('add product accepts comma decimals and submits valid details', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: const AddProductPage(),
        routes: {'/inventory': (_) => const Scaffold(body: Text('Inventory'))},
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('addProductNameField')),
      'Test Shirt',
    );
    await tester.enterText(
      find.byKey(const Key('addProductCostPriceField')),
      '12,50',
    );
    await tester.enterText(
      find.byKey(const Key('addProductRetailPriceField')),
      '19.99',
    );
    await tester.enterText(
      find.byKey(const Key('addProductSkuField')),
      'TEST-SHIRT-001',
    );
    await tester.tap(find.text('Save Product'));
    await tester.pumpAndSettle();

    expect(find.text('Inventory'), findsOneWidget);
    final request = jsonDecode(_lastProductRequest!.body) as Map;
    expect(request['name'], 'Test Shirt');
    expect(request['sku'], 'TEST-SHIRT-001');
    expect(request['cost'], 12.5);
    expect(request['price'], 19.99);
  });

  testWidgets(
    'reports supports period, date, product filter and chart selection',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: ReportsPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reportPeriodWeekly')));
      await tester.pumpAndSettle();
      expect(find.text('This Week’s Summary'), findsOneWidget);
      expect(find.text('K6480'), findsOneWidget);

      await tester.tap(find.byKey(const Key('reportPeriodCustom')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reportActiveDateRange')), findsOneWidget);
      await tester.tap(find.byKey(const Key('reportPresetLast 7 Days')));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('reportCategoryHoodies')),
      );
      await tester.tap(find.byKey(const Key('reportCategoryHoodies')));
      await tester.pumpAndSettle();
      expect(find.text('Showing 1 items'), findsOneWidget);
      expect(find.text('Hoodie Jacket'), findsOneWidget);
      expect(find.text("Men's T-Shirt"), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Fri'));
      await tester.tap(find.text('Fri'));
      await tester.pumpAndSettle();
      expect(find.text('Fri Revenue: K980'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('registration location dropdown fits a narrow screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ShopRegistrationPage()));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shopLocationDropdown')), findsOneWidget);
    expect(find.byKey(const Key('ownerEmailField')), findsOneWidget);
    expect(find.byKey(const Key('ownerPasswordField')), findsOneWidget);
    expect(find.textContaining('Phone Number'), findsNothing);
    final exception = tester.takeException();
    expect(exception, isNull, reason: '$exception');
  });

  testWidgets('registration password visibility can be toggled', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ShopRegistrationPage()));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('ownerPasswordField')),
              matching: find.byType(TextField),
            ),
          )
          .obscureText,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('toggleRegistrationPassword')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('ownerPasswordField')),
              matching: find.byType(TextField),
            ),
          )
          .obscureText,
      isFalse,
    );
  });

  // Regression: tapping Cancel or Confirm in the layby dialog must close the
  // dialog and resume the sale flow — never leave the app stuck on a modal.
  testWidgets('layby confirmation dialog closes on cancel and confirm', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: const SalesPage(),
        routes: {
          '/sale/success': (_) =>
              const Scaffold(body: Text('Sale success screen')),
        },
      ),
    );
    await tester.pumpAndSettle();

    Future<void> startLaybySale() async {
      await tester.ensureVisible(find.text('Men’s T-Shirt (K120)'));
      await tester.tap(find.text('Men’s T-Shirt (K120)'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Layby'));
      await tester.tap(find.textContaining('Layby').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Complete Sale'));
      await tester.pumpAndSettle();
      final completeButton = find.ancestor(
        of: find.textContaining('Complete Sale'),
        matching: find.byType(FilledButton),
      );
      await tester.ensureVisible(completeButton);
      await tester.pumpAndSettle();
      await tester.tap(completeButton, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    // Cancel path: dialog closes, no navigation happens, and the dialog can
    // be opened again (proof the app is not stuck).
    await startLaybySale();
    expect(find.text('Confirm layby sale'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Customer name *'),
      'Chanda Mwale',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm layby sale'), findsNothing);
    expect(find.text('Sale success screen'), findsNothing);

    // Confirm path: dialog closes and the success screen pushes.
    final completeButton = find.ancestor(
      of: find.textContaining('Complete Sale'),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(completeButton);
    await tester.pumpAndSettle();
    await tester.tap(completeButton, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Confirm layby sale'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Customer name *'),
      'Chanda Mwale',
    );
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm layby sale'), findsNothing);
    expect(find.text('Sale success screen'), findsOneWidget);
  });

  // Regression: the layby payment dialog on the Laybys page must close on
  // Cancel and Record without a disposed-controller crash freezing the page.
  testWidgets('layby payment dialog closes on cancel and record', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LaybyPage()));
    await tester.pumpAndSettle();

    Future<void> openPaymentDialog() async {
      await tester.ensureVisible(find.text('Record Payment'));
      final recordButton = find.ancestor(
        of: find.text('Record Payment'),
        matching: find.byType(FilledButton),
      );
      await tester.ensureVisible(recordButton);
      await tester.pumpAndSettle();
      await tester.tap(recordButton, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    // Cancel path.
    await openPaymentDialog();
    expect(find.text('Record payment'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Record payment'), findsNothing);

    // Record path.
    await openPaymentDialog();
    expect(find.text('Record payment'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Amount paid (K)'),
      '50',
    );
    await tester.tap(find.text('Record').last);
    await tester.pumpAndSettle();
    expect(find.text('Record payment'), findsNothing);
    // A payment receipt dialog shows what was paid and what remains.
    expect(find.textContaining('Paid this time'), findsOneWidget);
    expect(find.text('K50'), findsWidgets);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Paid this time'), findsNothing);

    // History tab lists the layby with its payment history.
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('OPEN · K250'), findsOneWidget);
    expect(find.text('Payment history'), findsOneWidget);
  });

  // Error bodies of every shape the API can produce must turn into a
  // readable ApiException — never a Dart type error masking the status.
  test('API errors map every response body shape to a readable message', () async {
    Future<void> expectMessage(Object? body, int status, String expected) async {
      ApiClient.configureForTesting(
        MockClient(
          (request) async => http.Response(
            body == null ? '' : jsonEncode(body),
            status,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      try {
        await ApiClient.products();
        fail('Expected an ApiException');
      } on ApiException catch (error) {
        expect(error.statusCode, status);
        expect(error.message, expected);
      }
    }

    await expectMessage({'detail': 'Sale not found.'}, 404, 'Sale not found.');
    await expectMessage(
      {
        'detail': [
          {'loc': ['body', 'amount'], 'msg': 'Input should be a valid number'},
        ],
      },
      422,
      'Input should be a valid number',
    );
    await expectMessage({'message': 'Something else'}, 400, 'Something else');
    await expectMessage('plain text error', 400, 'plain text error');
    await expectMessage(['unexpected', 'array'], 500, 'unexpected');
    await expectMessage({'unrelated': true}, 400, 'Request failed.');
    await expectMessage(null, 502, 'Request failed.');
  });
}

http.Request? _lastLoginRequest;
http.Request? _lastRegisterRequest;
http.Request? _lastProductRequest;
http.Request? _lastSupplierRequest;

Future<http.Response> _mockApi(http.Request request) async {
  final path = request.url.path;
  final dynamic body;
  if (path == '/auth/login') {
    _lastLoginRequest = request;
    body = _authResponse;
  } else if (path == '/auth/register') {
    _lastRegisterRequest = request;
    body = _authResponse;
  } else if (path == '/auth/me' || path == '/settings') {
    body = _shop;
  } else if (path == '/dashboard') {
    body = {
      'product_count': _products.length,
      'stock_count': 125,
      'low_stock_count': 0,
      'today_sales': 0,
    };
  } else if (path == '/products') {
    if (request.method == 'POST') {
      _lastProductRequest = request;
      body = {
        ...jsonDecode(request.body) as Map<String, dynamic>,
        'id': '00000000-0000-0000-0000-000000000003',
        'shop_id': _shop['id'],
        'created_at': DateTime.now().toIso8601String(),
      };
    } else {
      final search = request.url.queryParameters['search']?.toLowerCase();
      body = search == null
          ? _products
          : _products
                .where(
                  (product) => (product['name'] as String)
                      .toLowerCase()
                      .contains(search),
                )
                .toList();
    }
  } else if (path == '/suppliers') {
    if (request.method == 'POST') {
      _lastSupplierRequest = request;
      body = {
        ...jsonDecode(request.body) as Map<String, dynamic>,
        'id': 'supplier-id',
        'shop_id': _shop['id'],
      };
    } else {
      body = <Map<String, dynamic>>[];
    }
  } else if (path == '/sales' && request.method == 'POST') {
    final saleRequest = jsonDecode(request.body) as Map<String, dynamic>;
    final cartItems = saleRequest['items'] as List;
    final subtotal = cartItems.fold<double>(0, (total, rawItem) {
      final item = rawItem as Map<String, dynamic>;
      final product = _products.firstWhere(
        (candidate) => candidate['id'] == item['product_id'],
      );
      return total +
          (product['price'] as num).toDouble() *
              (item['quantity'] as num).toInt();
    });
    final discount =
        subtotal * (saleRequest['discount_percent'] as num).toDouble() / 100;
    body = {
      'id': 'sale-new',
      'subtotal': subtotal,
      'discount': discount,
      'total': subtotal - discount,
      'payment_method': saleRequest['payment_method'],
    };
  } else if (path == '/laybys' && request.method == 'GET') {
    body = [
      {
        'id': 'sale-layby-1',
        'total': 350,
        'layby_deposit': 100,
        'layby_balance': 250,
        'layby_settled': false,
        'payment_method': 'Layby',
        'customer_name': 'Chanda Mwale',
        'customer_phone': '+260970000001',
      },
    ];
  } else if (path == '/laybys/history') {
    body = [
      {
        ..._laybySale,
        'layby_settled': false,
        'payments': [
          {'id': 'pay-1', 'sale_id': 'sale-layby-1', 'amount': 100, 'paid_at': '2026-11-10T09:00:00+00:00'},
          {'id': 'pay-2', 'sale_id': 'sale-layby-1', 'amount': 50, 'paid_at': '2026-11-12T14:30:00+00:00'},
        ],
      },
    ];
  } else if (path.startsWith('/laybys/') && path.endsWith('/payments')) {
    body = {
      ..._laybySale,
      'layby_deposit': 150,
      'layby_balance': 200,
    };
  } else if (path == '/reports') {
    body = _mockReport(
      request.url.queryParameters['start_date']!,
      request.url.queryParameters['end_date']!,
    );
  } else if (path == '/settings' && request.method == 'PATCH') {
    body = {..._shop, ...jsonDecode(request.body) as Map<String, dynamic>};
  } else {
    return http.Response(
      jsonEncode({'detail': 'Not found'}),
      404,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
    request: request,
  );
}

Map<String, dynamic> _mockReport(String startText, String endText) {
  final start = DateTime.parse(startText);
  final end = DateTime.parse(endText);
  final selectedSales = _sales.where((sale) {
    final day = DateTime.parse(sale['sold_at'] as String);
    return !day.isBefore(start) && !day.isAfter(end);
  }).toList();
  final selectedIds = selectedSales.map((sale) => sale['id']).toSet();
  final items = _saleItems
      .where((item) => selectedIds.contains(item['sale_id']))
      .toList();
  final totalSales = selectedSales.fold<double>(
    0,
    (total, sale) => total + (sale['total'] as num).toDouble(),
  );
  final paymentTotals = <String, double>{};
  final dailyTotals = <String, double>{};
  for (final sale in selectedSales) {
    final total = (sale['total'] as num).toDouble();
    final method = sale['payment_method'] as String;
    final day = (sale['sold_at'] as String).substring(0, 10);
    paymentTotals[method] = (paymentTotals[method] ?? 0) + total;
    dailyTotals[day] = (dailyTotals[day] ?? 0) + total;
  }
  final productTotals = <String, Map<String, dynamic>>{};
  var totalCost = 0.0;
  for (final item in items) {
    final productId = item['product_id'] as String;
    final product = _products.firstWhere(
      (candidate) => candidate['id'] == productId,
    );
    final quantity = item['quantity'] as int;
    final total = productTotals.putIfAbsent(
      productId,
      () => {
        'product_id': productId,
        'name': product['name'],
        'category': product['category'],
        'stock': product['quantity'],
        'quantity': 0,
        'revenue': 0.0,
      },
    );
    total['quantity'] = (total['quantity'] as int) + quantity;
    total['revenue'] =
        (total['revenue'] as double) +
        (item['unit_price'] as num).toDouble() * quantity;
    totalCost += (item['unit_cost'] as num).toDouble() * quantity;
  }
  return {
    'sales': selectedSales,
    'items': items,
    'total_sales': totalSales,
    'total_cost': totalCost,
    'net_profit': totalSales - totalCost,
    'sale_count': selectedSales.length,
    'payment_totals': paymentTotals,
    'daily_totals':
        (dailyTotals.entries.toList()
              ..sort((left, right) => left.key.compareTo(right.key)))
            .map((entry) => {'date': entry.key, 'total': entry.value})
            .toList(),
    'top_products': productTotals.values.toList()
      ..sort(
        (left, right) =>
            (right['revenue'] as double).compareTo(left['revenue'] as double),
      ),
  };
}

const _shop = {
  'id': '00000000-0000-0000-0000-000000000010',
  'owner_id': '00000000-0000-0000-0000-000000000099',
  'name': 'Lusaka Fashion Hub',
  'owner_name': 'Test Owner',
  'phone': '',
  'location': 'Lusaka',
  'business_type': 'Boutique',
};

const _laybySale = {
  'id': 'sale-layby-1',
  'total': 350,
  'layby_deposit': 100,
  'layby_balance': 250,
  'layby_settled': false,
  'payment_method': 'Layby',
  'customer_name': 'Chanda Mwale',
  'customer_phone': '+260970000001',
};

const _products = [
  {
    'id': '00000000-0000-0000-0000-000000000001',
    'name': 'Men’s T-Shirt',
    'category': 'T-Shirts & Polos',
    'sku': 'TEE-001',
    'size': 'M',
    'color': 'Black',
    'cost': 80,
    'price': 120,
    'quantity': 50,
  },
  {
    'id': '00000000-0000-0000-0000-000000000002',
    'name': 'Hoodie Jacket',
    'category': 'Jackets & Hoodies',
    'sku': 'HOODIE-001',
    'size': 'L',
    'color': 'Crimson Red',
    'cost': 220,
    'price': 350,
    'quantity': 30,
  },
  {
    'id': '00000000-0000-0000-0000-000000000003',
    'name': 'Classic Jeans',
    'category': 'Jeans',
    'sku': 'JEANS-001',
    'size': '32',
    'color': 'Blue',
    'cost': 280,
    'price': 500,
    'quantity': 20,
  },
  {
    'id': '00000000-0000-0000-0000-000000000004',
    'name': 'Leather Belt',
    'category': 'Accessories',
    'sku': 'BELT-001',
    'size': 'M',
    'color': 'Black',
    'cost': 15,
    'price': 40,
    'quantity': 25,
  },
];

List<Map<String, dynamic>> get _sales {
  final today = DateUtils.dateOnly(DateTime.now());
  final weekDays = List.generate(
    7,
    (index) => today.subtract(Duration(days: 6 - index)),
  );
  final friday = weekDays.firstWhere((day) => day.weekday == DateTime.friday);
  final otherDays = weekDays.where((day) => day != friday).toList();
  final saleDays = <DateTime>[
    otherDays[0],
    otherDays[1],
    otherDays[2],
    friday,
    otherDays[3],
    otherDays[4],
  ];
  const entries = [
    (1100, 'Cash'),
    (1100, 'Cash'),
    (1200, 'Cash'),
    (980, 'Airtel / MTN'),
    (1100, 'Card POS'),
    (1000, 'Cash'),
  ];
  return [
    for (var index = 0; index < entries.length; index++)
      {
        'id': 'sale-$index',
        'shop_id': _shop['id'],
        'subtotal': entries[index].$1,
        'discount': 0,
        'total': entries[index].$1,
        'payment_method': entries[index].$2,
        'sold_at': saleDays[index]
            .add(const Duration(hours: 10))
            .toIso8601String(),
      },
  ];
}

List<Map<String, dynamic>> get _saleItems {
  const entries = [
    [('jeans', 1), ('tee', 5)],
    [('jeans', 1), ('tee', 5)],
    [('tee', 10)],
    [('hoodie', 2), ('tee', 2), ('belt', 1)],
    [('jeans', 1), ('tee', 5)],
    [('jeans', 2)],
  ];
  const ids = {
    'tee': '00000000-0000-0000-0000-000000000001',
    'hoodie': '00000000-0000-0000-0000-000000000002',
    'jeans': '00000000-0000-0000-0000-000000000003',
    'belt': '00000000-0000-0000-0000-000000000004',
  };
  final productsById = {
    for (final product in _products) product['id']: product,
  };
  return [
    for (var index = 0; index < entries.length; index++)
      for (final (key, quantity) in entries[index])
        {
          'sale_id': 'sale-$index',
          'product_id': ids[key],
          'product_name': productsById[ids[key]]!['name'],
          'quantity': quantity,
          'unit_price': productsById[ids[key]]!['price'],
          'unit_cost': productsById[ids[key]]!['cost'],
        },
  ];
}

const _authResponse = {
  'user': {
    'id': '00000000-0000-0000-0000-000000000099',
    'email': 'owner@example.com',
  },
  'access_token': 'test-access-token',
  'refresh_token': 'test-refresh-token',
  'shop': _shop,
  'requires_email_confirmation': false,
};
