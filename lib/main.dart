import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/presentation/dashboard_page.dart';
import 'features/customers/presentation/customers_page.dart';
import 'features/financings/presentation/financings_page.dart';
import 'features/payments/presentation/payments_page.dart';
import 'features/backup/presentation/backup_settings_page.dart';
import 'features/orders/presentation/orders_page.dart';

final routerProvider = Provider<GoRouter>((ref) => GoRouter(
      initialLocation: '/dashboard',
      routes: [
        ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                  path: '/dashboard',
                  builder: (_, state) => DashboardPage(
                        key: ValueKey(
                          state.uri.queryParameters['reload'] ?? 'default',
                        ),
                      )),
              GoRoute(
                  path: '/customers',
                  builder: (_, __) => const CustomersPage()),
              GoRoute(
                  path: '/financings',
                  builder: (_, state) => FinancingsPage(
                        orderId: state.uri.queryParameters['orderId'],
                      )),
              GoRoute(path: '/orders', builder: (_, __) => const OrdersPage()),
              GoRoute(
                  path: '/payments', builder: (_, __) => const PaymentsPage()),
              GoRoute(
                  path: '/settings',
                  builder: (_, __) => const BackupSettingsPage()),
            ])
      ],
    ));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  runApp(const ProviderScope(child: SyariFinanceApp()));
}

class SyariFinanceApp extends ConsumerWidget {
  const SyariFinanceApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'Syari Finance',
        theme: AppTheme.light,
        routerConfig: ref.watch(routerProvider),
        debugShowCheckedModeBanner: false,
      );
}

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});
  final Widget child;
  static const destinations = [
    ('Dashboard', Icons.dashboard_outlined, '/dashboard'),
    ('Nasabah', Icons.people_outline, '/customers'),
    ('Pembiayaan', Icons.account_balance_wallet_outlined, '/financings'),
    ('Pembayaran', Icons.payments_outlined, '/payments'),
  ];
  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = destinations
        .indexWhere((item) => location == item.$3)
        .clamp(0, destinations.length - 1);
    return Scaffold(
      appBar: AppBar(
          leadingWidth: 40,
          titleSpacing: 4,
          leading: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 2, 10),
              child: Image.asset('assets/branding/syari-finance-logo.png')),
          title: Text('Syari Finance',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2)),
          actions: [
            IconButton(
              tooltip: 'Pemesanan',
              onPressed: () => context.push('/orders'),
              icon: const Icon(Icons.shopping_bag_outlined),
            ),
            IconButton(
              tooltip: 'Data dan backup',
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ]),
      body: child,
      bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => context.go(destinations[value].$3),
          destinations: [
            for (final item in destinations)
              NavigationDestination(icon: Icon(item.$2), label: item.$1)
          ]),
    );
  }
}
