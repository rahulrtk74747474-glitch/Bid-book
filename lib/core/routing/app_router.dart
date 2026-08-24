import 'package:bid_book/features/bidding/presentation/bid_history_screen.dart';
import 'package:bid_book/features/groups/presentation/groups_screen.dart';
import 'package:bid_book/features/home/presentation/home_screen.dart';
import 'package:bid_book/features/profile/presentation/profile_screen.dart';
import 'package:bid_book/features/requests/presentation/requests_screen.dart';
import 'package:bid_book/shared/widgets/app_shell.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/requests',
              builder: (context, state) => const RequestsScreen(),
              routes: [
                GoRoute(
                  path: ':requestId/bids',
                  builder: (context, state) => BidHistoryScreen(
                    requestId: state.pathParameters['requestId']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/groups',
              builder: (context, state) => const GroupsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/account',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
