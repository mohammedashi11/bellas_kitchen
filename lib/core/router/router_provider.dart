import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/screens/admin_login_screen.dart';
import '../../features/admin/presentation/screens/admin_shell_screen.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/providers/auth_state.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/phone_entry_screen.dart';
import '../../features/cart/presentation/screens/cart_screen.dart';
import '../../features/menu/domain/entities/menu_item.dart';
import '../../features/menu/presentation/screens/home_screen.dart';
import '../../features/menu/presentation/screens/item_detail_screen.dart';
import '../../features/order/domain/entities/order.dart';
import '../../features/order/presentation/screens/order_history_screen.dart';
import '../../features/order/presentation/screens/order_tracking_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../constants/app_constants.dart';

/// App router, built inside Riverpod so the redirect guard can read auth state.
final routerProvider = Provider<GoRouter>((ref) {
  // Bridges auth-state changes into a Listenable so go_router re-evaluates
  // `redirect` whenever the user signs in / out.
  final refresh = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref.listen<AuthState>(
    authControllerProvider,
    (_, next) => refresh.value = next,
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppConstants.routeHome,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      final isAuthed = auth is Authenticated;
      final isAdmin = auth is Authenticated && auth.user.isAdmin;

      // ── Admin area (independent of customer-side enforceAuth) ──────────────
      // Every '/admin/*' route except the login screen requires an admin; a
      // non-admin (customer, anonymous, or unauthenticated) is bounced to admin
      // login and can never enter admin screens. A logged-in admin skips login.
      if (loc.startsWith('${AppConstants.routeAdmin}/')) {
        if (loc == AppConstants.routeAdminLogin) {
          return isAdmin ? AppConstants.routeAdminDashboard : null;
        }
        return isAdmin ? null : AppConstants.routeAdminLogin;
      }

      // ── Customer area (unchanged) ─────────────────────────────────────────
      final onAuthRoute =
          loc == AppConstants.routePhoneEntry || loc == AppConstants.routeOtp;

      // A signed-in user has no business on the customer auth screens.
      if (isAuthed && onAuthRoute) return AppConstants.routeHome;

      // Demo mode (default): auth is optional — never force the login wall, so
      // the app opens to a usable, browsable state even when Firebase Auth is
      // unreachable. See AppConstants.enforceAuth.
      if (!AppConstants.enforceAuth) return null;

      // Enforced mode: gate everything behind sign-in.
      if (!isAuthed && !onAuthRoute) return AppConstants.routePhoneEntry;
      return null;
    },
    routes: [
      GoRoute(
        path: AppConstants.routeHome,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '${AppConstants.routeItem}/:id',
        name: 'item',
        builder: (context, state) => ItemDetailScreen(
          itemId: state.pathParameters['id']!,
          item: state.extra is MenuItem ? state.extra as MenuItem : null,
        ),
      ),
      GoRoute(
        path: AppConstants.routeCart,
        name: 'cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '${AppConstants.routeOrder}/:id',
        name: 'order',
        builder: (context, state) => OrderTrackingScreen(
          orderId: state.pathParameters['id']!,
          initialOrder: state.extra is Order ? state.extra as Order : null,
        ),
      ),
      GoRoute(
        path: AppConstants.routeOrders,
        name: 'orders',
        builder: (context, state) => const OrderHistoryScreen(),
      ),
      GoRoute(
        path: AppConstants.routeProfile,
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppConstants.routePhoneEntry,
        name: 'phoneEntry',
        builder: (context, state) => const PhoneEntryScreen(),
      ),
      GoRoute(
        path: AppConstants.routeOtp,
        name: 'otp',
        builder: (context, state) {
          final phone = state.extra is String
              ? state.extra as String
              : (ref.read(authControllerProvider.notifier).phoneNumber ?? '');
          return OtpScreen(phoneNumber: phone);
        },
      ),
      GoRoute(
        path: AppConstants.routeAdminLogin,
        name: 'adminLogin',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: AppConstants.routeAdminDashboard,
        name: 'adminDashboard',
        builder: (context, state) => const AdminShellScreen(),
      ),
    ],
  );
});
