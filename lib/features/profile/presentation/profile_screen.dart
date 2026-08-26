import 'package:bid_book/core/api/api_models.dart';
import 'package:bid_book/core/theme/app_theme.dart';
import 'package:bid_book/features/auth/application/remote_auth_controller.dart';
import 'package:bid_book/features/marketplace/application/remote_marketplace_controller.dart';
import 'package:bid_book/features/media/data/media_api.dart';
import 'package:bid_book/features/operations/application/remote_operations_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(remoteAuthControllerProvider).asData?.value;
    final marketplace = ref.watch(remoteMarketplaceProvider).asData?.value;
    final operations = ref.watch(remoteOperationsProvider).asData?.value;
    final user = auth?.user;
    final provider = marketplace?.provider;
    final providerPhotos = provider == null
        ? const AsyncValue<List<String>>.data([])
        : ref.watch(mediaGalleryProvider('provider|${provider.id}'));
    final avatar = providerPhotos.asData?.value.isNotEmpty == true ? providerPhotos.asData!.value.first : user?.avatarUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.navyDeep, AppColors.navy]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      backgroundImage: avatar?.startsWith('http') == true ? NetworkImage(avatar!) : null,
                      child: avatar?.startsWith('http') == true
                          ? null
                          : Text(
                              (user?.bestName.isNotEmpty == true ? user!.bestName[0] : 'B').toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.bestName ?? 'Bid&Book account', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          if (user?.primaryContact.isNotEmpty == true)
                            Text(user!.primaryContact, style: const TextStyle(color: Color(0xFFD7E8FF), fontSize: 13)),
                          if (provider != null) ...[
                            const SizedBox(height: 5),
                            Text('${provider.kind.label} • ${provider.serviceArea}', style: const TextStyle(color: Color(0xFF9BC8FF), fontSize: 12.5)),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.push('/provider/onboarding'),
                      icon: const Icon(Icons.edit_outlined, color: Colors.white),
                      tooltip: 'Edit provider profile',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _TrustBox(icon: Icons.phone_android, label: 'Phone', active: user?.phoneVerified == true)),
                    const SizedBox(width: 8),
                    Expanded(child: _TrustBox(icon: Icons.email_outlined, label: 'Email', active: user?.emailVerified == true)),
                    const SizedBox(width: 8),
                    Expanded(child: _TrustBox(icon: Icons.verified_user_outlined, label: 'Identity', active: user?.identityVerified == true)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Marketplace', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          _MenuCard(children: [
            _MenuItem(
              icon: Icons.search,
              title: 'Find trusted services',
              subtitle: 'Search providers, ratings and availability',
              color: AppColors.blue,
              onTap: () => context.push('/discover'),
            ),
            _MenuItem(
              icon: Icons.gavel_outlined,
              title: 'Post a request & receive bids',
              subtitle: 'Providers compete with transparent prices',
              color: AppColors.orange,
              onTap: () => context.push('/requests/new'),
            ),
            _MenuItem(
              icon: Icons.calendar_month_outlined,
              title: 'My bookings',
              subtitle: 'Upcoming and completed jobs',
              color: AppColors.blue,
              onTap: () => context.go('/bookings'),
            ),
            _MenuItem(
              icon: Icons.groups_2_outlined,
              title: 'Neighborhood groups',
              subtitle: 'Combine demand for better group prices',
              color: AppColors.purple,
              onTap: () => context.push('/groups'),
            ),
          ]),
          const SizedBox(height: 20),
          const Text('Offer services', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          _MenuCard(children: [
            _MenuItem(
              icon: Icons.handyman_outlined,
              title: provider == null ? 'Become a service provider' : provider.displayName,
              subtitle: provider == null ? 'One account can also earn by offering work' : 'Edit provider profile and portfolio',
              color: AppColors.green,
              onTap: () => context.push('/provider/onboarding'),
            ),
            if (provider != null)
              _MenuItem(
                icon: Icons.add_business_outlined,
                title: 'Publish a service',
                subtitle: 'Add price, details and real work photos',
                color: AppColors.green,
                onTap: () => context.push('/services/new'),
              ),
            if (provider != null)
              _MenuItem(
                icon: Icons.schedule_outlined,
                title: 'Provider availability',
                subtitle: 'Set the days you normally accept work',
                color: AppColors.green,
                onTap: () => context.push('/provider/availability'),
              ),
          ]),
          const SizedBox(height: 20),
          const Text('Trust & safety', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          _MenuCard(children: [
            _MenuItem(
              icon: Icons.shield_outlined,
              title: 'Trust & payments',
              subtitle: 'Verification, payments, payouts and disputes',
              color: AppColors.navy,
              onTap: () => context.push('/trust'),
            ),
            _MenuItem(
              icon: Icons.support_agent,
              title: 'Support & safety',
              subtitle: 'Support cases, reports and account controls',
              color: AppColors.navy,
              onTap: () => context.push('/support-safety'),
            ),
            if (operations?.isAdmin == true)
              _MenuItem(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin operations',
                subtitle: 'Review trust, safety, payouts and support',
                color: AppColors.navy,
                onTap: () => context.push('/admin'),
              ),
          ]),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => ref.read(remoteAuthControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _TrustBox extends StatelessWidget {
  const _TrustBox({required this.icon, required this.label, required this.active});
  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Icon(active ? Icons.check_circle : icon, color: active ? const Color(0xFF8EE0B8) : Colors.white70, size: 19),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1) const Divider(height: 1, indent: 64),
            ],
          ],
        ),
      );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
      );
}
