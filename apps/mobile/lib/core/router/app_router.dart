import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/pending_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/welcome_page.dart';
import '../../features/people/presentation/people_list_page.dart';
import '../../features/people/presentation/person_details_page.dart';
import '../../features/people/presentation/person_form_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/scan/presentation/find_person_page.dart';
import '../../features/scan/presentation/scan_page.dart';
import '../../features/scan/presentation/session_summary_page.dart';
import '../../features/statistics/presentation/statistics_page.dart';
import '../../shell/home_shell.dart';
import '../settings/settings_controller.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

const _publicRoutes = {'/welcome', '/login', '/register', '/pending'};

/// Pure redirect rule, unit-tested: where should [location] go given [auth]?
///
/// The splash is held until the saved settings are in ([settingsReady]), so
/// the first real screen already has the volunteer's language and theme.
String? authRedirect(
  AsyncValue<User?> auth,
  String location, {
  bool settingsReady = true,
}) {
  if (!settingsReady || (auth.isLoading && !auth.hasValue)) {
    return location == '/splash' ? null : '/splash';
  }
  final signedIn = auth.value != null;
  final isPublic = _publicRoutes.contains(location);
  if (!signedIn) return isPublic ? null : '/welcome';
  if (isPublic || location == '/splash') return '/people';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AsyncValue<User?>>(
    ref.read(authControllerProvider),
  );
  // A failed settings load counts as loaded: the defaults apply.
  final settingsReady = ValueNotifier<bool>(
    !ref.read(settingsControllerProvider).isLoading,
  );
  ref
    ..listen(authControllerProvider, (_, next) => auth.value = next)
    ..listen(
      settingsControllerProvider,
      (_, next) => settingsReady.value = !next.isLoading,
    )
    ..onDispose(auth.dispose)
    ..onDispose(settingsReady.dispose);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: Listenable.merge([auth, settingsReady]),
    redirect: (context, state) => authRedirect(
      auth.value,
      state.matchedLocation,
      settingsReady: settingsReady.value,
    ),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomePage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(path: '/pending', builder: (_, _) => const PendingPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/people',
                builder: (_, _) => const PeopleListPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/add',
                builder: (_, state) => AddPersonPage(
                  initialId: int.tryParse(
                    state.uri.queryParameters['id'] ?? '',
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                builder: (_, _) => const StatisticsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/scan',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const ScanPage(),
      ),
      // "Register this card" from the scanner: the same form as the Add tab,
      // but pushed over the scanner (a shell tab cannot be stacked on it), so
      // the scan session survives underneath.
      GoRoute(
        path: '/register-card',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => AddPersonPage(
          initialId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
          overScanner: true,
        ),
      ),
      GoRoute(
        path: '/find',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const FindPersonPage(),
      ),
      GoRoute(
        path: '/summary',
        parentNavigatorKey: _rootKey,
        redirect: (_, state) => state.extra is SessionSummary ? null : '/people',
        builder: (_, state) => SessionSummaryPage(summary: state.extra! as SessionSummary),
      ),
      GoRoute(
        path: '/people/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            PersonDetailsPage(personId: int.parse(state.pathParameters['id']!)),
        routes: [
          GoRoute(
            path: 'edit',
            parentNavigatorKey: _rootKey,
            builder: (_, state) => EditPersonPage(
              personId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
