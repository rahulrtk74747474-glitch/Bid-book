import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:bid_book/features/auth/presentation/otp_login_screen.dart';
import 'package:bid_book/features/bidding/presentation/bid_history_screen.dart';
import 'package:bid_book/features/bookings/presentation/booking_detail_screen.dart';
import 'package:bid_book/features/bookings/presentation/bookings_screen.dart';
import 'package:bid_book/features/communications/presentation/chat_screen.dart';
import 'package:bid_book/features/communications/presentation/chats_screen.dart';
import 'package:bid_book/features/communications/presentation/notifications_screen.dart';
import 'package:bid_book/features/groups/presentation/group_detail_screen.dart';
import 'package:bid_book/features/groups/presentation/groups_screen.dart';
import 'package:bid_book/features/home/presentation/home_screen.dart';
import 'package:bid_book/features/operations/presentation/discovery_screen.dart';
import 'package:bid_book/features/operations/presentation/provider_availability_screen.dart';
import 'package:bid_book/features/operations/presentation/support_safety_screen.dart';
import 'package:bid_book/features/production/presentation/admin_mfa_gate_screen.dart';
import 'package:bid_book/features/production/presentation/company_team_screen.dart';
import 'package:bid_book/features/production/presentation/media_manager_screen.dart';
import 'package:bid_book/features/production/presentation/nearby_services_screen.dart';
import 'package:bid_book/features/production/presentation/privacy_data_screen.dart';
import 'package:bid_book/features/production/presentation/provider_business_screen.dart';
import 'package:bid_book/features/profile/presentation/profile_screen.dart';
import 'package:bid_book/features/provider/presentation/provider_onboarding_screen.dart';
import 'package:bid_book/features/requests/presentation/post_request_screen.dart';
import 'package:bid_book/features/requests/presentation/requests_screen.dart';
import 'package:bid_book/features/services/presentation/add_service_listing_screen.dart';
import 'package:bid_book/features/services/presentation/service_detail_screen.dart';
import 'package:bid_book/features/trust/presentation/booking_trust_screen.dart';
import 'package:bid_book/features/trust/presentation/trust_center_screen.dart';
import 'package:bid_book/shared/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(remoteAuthControllerProvider);
  final auth = authAsync.asData?.value;
  final booting = authAsync.isLoading && auth == null;
  final authenticated = auth?.isAuthenticated == true;

  return GoRouter(
    initialLocation: booting ? '/boot' : authenticated ? '/' : '/login',
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (booting) return location == '/boot' ? null : '/boot';
      if (!authenticated) return location == '/login' ? null : '/login';
      if (location == '/login' || location == '/boot') return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/boot',
        builder: (context, state) => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const OtpLoginScreen(),
      ),
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
                    path: 'new',
                    builder: (context, state) => const PostRequestScreen(),
                  ),
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
                path: '/chats',
                builder: (context, state) => const ChatsScreen(),
                routes: [
                  GoRoute(
                    path: ':chatId',
                    builder: (context, state) => ChatScreen(
                      chatId: state.pathParameters['chatId']!,
                    ),
                  ),
                ],
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
      GoRoute(
        path: '/discover',
        builder: (context, state) => const DiscoveryScreen(),
      ),
      GoRoute(
        path: '/nearby',
        builder: (context, state) => const NearbyServicesScreen(),
      ),
      GoRoute(
        path: '/support-safety',
        builder: (context, state) => const SupportSafetyScreen(),
      ),
      GoRoute(
        path: '/privacy-data',
        builder: (context, state) => const PrivacyDataScreen(),
      ),
      GoRoute(
        path: '/provider/availability',
        builder: (context, state) => const ProviderAvailabilityScreen(),
      ),
      GoRoute(
        path: '/provider/business',
        builder: (context, state) => const ProviderBusinessScreen(),
      ),
      GoRoute(
        path: '/provider/team',
        builder: (context, state) => CompanyTeamScreen(
          bookingId: state.uri.queryParameters['bookingId'],
        ),
      ),
      GoRoute(
        path: '/media',
        builder: (context, state) {
          final type = state.uri.queryParameters['entityType'];
          final id = state.uri.queryParameters['entityId'];
          if (type == null || id == null) {
            return const Scaffold(
              body: Center(child: Text('Media target is missing.')),
            );
          }
          return MediaManagerScreen(entityType: type, entityId: id);
        },
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminMfaGateScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/trust',
        builder: (context, state) => const TrustCenterScreen(),
      ),
      GoRoute(
        path: '/groups/:groupId',
        builder: (context, state) => GroupDetailScreen(
          groupId: state.pathParameters['groupId']!,
        ),
      ),
      GoRoute(
        path: '/provider/onboarding',
        builder: (context, state) => const ProviderOnboardingScreen(),
      ),
      GoRoute(
        path: '/services/new',
        builder: (context, state) => const AddServiceListingScreen(),
      ),
      GoRoute(
        path: '/services/:listingId',
        builder: (context, state) => ServiceDetailScreen(
          listingId: state.pathParameters['listingId']!,
        ),
      ),
      GoRoute(
        path: '/bookings',
        builder: (context, state) => const BookingsScreen(),
      ),
      GoRoute(
        path: '/bookings/:bookingId',
        builder: (context, state) => BookingDetailScreen(
          bookingId: state.pathParameters['bookingId']!,
        ),
      ),
      GoRoute(
        path: '/bookings/:bookingId/trust',
        builder: (context, state) => BookingTrustScreen(
          bookingId: state.pathParameters['bookingId']!,
        ),
      ),
    ],
  );
});
