import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/pos/screens/pos_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/inventory/screens/add_medicine_screen.dart';
import '../../features/inventory/screens/categories_units_screen.dart';
import '../../features/purchases/screens/purchases_screen.dart';
import '../../features/purchases/screens/add_purchase_screen.dart';
import '../../features/customers/screens/customers_screen.dart';
import '../../features/suppliers/screens/suppliers_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/expenses/screens/expenses_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: auth.isLoggedIn ? '/dashboard' : '/login',
    redirect: (context, state) {
      final isLoggedIn = ref.read(authProvider).isLoggedIn;
      final isLoginPage = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginPage) return '/login';
      if (isLoggedIn && isLoginPage) return '/dashboard';
      return null;
    },
    refreshListenable: GoRouterRefreshStream(ref.watch(authProvider.notifier).stream),
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/pos', builder: (_, __) => const PosScreen()),
          GoRoute(
            path: '/inventory',
            builder: (_, __) => const InventoryScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (_, state) {
                  final id = state.uri.queryParameters['id'];
                  return AddMedicineScreen(medicineId: id != null ? int.tryParse(id) : null);
                },
              ),
              GoRoute(
                path: 'categories',
                builder: (_, __) => const CategoriesUnitsScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/purchases',
            builder: (_, __) => const PurchasesScreen(),
            routes: [
              GoRoute(path: 'add', builder: (_, __) => const AddPurchaseScreen()),
            ],
          ),
          GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen()),
          GoRoute(path: '/suppliers', builder: (_, __) => const SuppliersScreen()),
          GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
          GoRoute(path: '/expenses', builder: (_, __) => const ExpensesScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    stream.listen((_) => notifyListeners());
  }
}
