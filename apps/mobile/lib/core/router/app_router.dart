import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/welcome_page.dart';
import '../../features/people/presentation/people_list_page.dart';
import '../../features/people/presentation/person_details_page.dart';
import '../../features/people/presentation/person_form_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/scan/presentation/scan_page.dart';
import '../../features/statistics/presentation/statistics_page.dart';
import '../../shell/home_shell.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

const _publicRoutes = {'/welcome', '/login', '/register'};

/// Pure redirect rule, unit-tested: where should [location] go given [auth]?
String? authRedirect(AsyncValue<User?> auth, String location) {
  if (auth.isLoading && !auth.hasValue) {
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
  ref
    ..listen(authControllerProvider, (_, next) => auth.value = next)
    ..onDispose(auth.dispose);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) =>
        authRedirect(auth.value, state.matchedLocation),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomePage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
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
