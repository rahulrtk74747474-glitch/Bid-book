import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 38,
                    child: Icon(Icons.person, size: 38),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your profile',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 5),
                  const Text('Customer + service provider in one account'),
                  const SizedBox(height: 14),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      Chip(
                        avatar: Icon(Icons.phone_android, size: 16),
                        label: Text('Mobile verified'),
                      ),
                      Chip(
                        avatar: Icon(Icons.verified_user_outlined, size: 16),
                        label: Text('Identity pending'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const ListTile(
            leading: Icon(Icons.handyman_outlined),
            title: Text('Start offering services'),
            subtitle: Text('Independent workers and companies use the same app'),
            trailing: Icon(Icons.chevron_right),
          ),
          const ListTile(
            leading: Icon(Icons.verified_user_outlined),
            title: Text('Identity verification'),
            subtitle: Text('Keep verification status; avoid storing raw Aadhaar'),
            trailing: Icon(Icons.chevron_right),
          ),
          const ListTile(
            leading: Icon(Icons.account_balance_outlined),
            title: Text('Payments & payouts'),
            trailing: Icon(Icons.chevron_right),
          ),
          const ListTile(
            leading: Icon(Icons.security_outlined),
            title: Text('Security & devices'),
            trailing: Icon(Icons.chevron_right),
          ),
          const ListTile(
            leading: Icon(Icons.support_agent_outlined),
            title: Text('Help & disputes'),
            trailing: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
