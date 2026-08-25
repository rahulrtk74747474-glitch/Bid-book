import 'package:flutter/material.dart';

void main() {
  runApp(const BidBookDemoApp());
}

class BidBookDemoApp extends StatelessWidget {
  const BidBookDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF087F83),
      brightness: Brightness.light,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bid&Book Demo',
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9F9),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
            side: BorderSide(color: Color(0xFFE4E9E9)),
          ),
        ),
      ),
      home: const DemoLoginScreen(),
    );
  }
}

class DemoLoginScreen extends StatefulWidget {
  const DemoLoginScreen({super.key});

  @override
  State<DemoLoginScreen> createState() => _DemoLoginScreenState();
}

class _DemoLoginScreenState extends State<DemoLoginScreen> {
  final phone = TextEditingController();
  final otp = TextEditingController();
  bool sent = false;

  @override
  void dispose() {
    phone.dispose();
    otp.dispose();
    super.dispose();
  }

  void _submit() {
    if (!sent) {
      if (phone.text.trim().length < 10) {
        _snack('Enter any 10-digit mobile number for this demo.');
        return;
      }
      setState(() => sent = true);
      _snack('Demo OTP: 123456');
      return;
    }
    if (otp.text.trim() != '123456') {
      _snack('Use demo OTP 123456.');
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DemoShell()),
    );
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Icon(Icons.handshake_outlined, size: 92),
                const SizedBox(height: 18),
                Text(
                  'Bid&Book',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Phone-only demo\nNo PC or backend required',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    prefixIcon: Icon(Icons.phone_android),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (sent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: otp,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'OTP',
                      helperText: 'Demo OTP: 123456',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(sent ? 'Verify & enter demo' : 'Send OTP'),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This demo stores nothing online and does not send a real SMS or payment.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DemoShell extends StatefulWidget {
  const DemoShell({super.key});

  @override
  State<DemoShell> createState() => _DemoShellState();
}

class _DemoShellState extends State<DemoShell> {
  int index = 0;

  final requests = <DemoRequest>[
    DemoRequest('AC service required', 'AC Repair', 'Sector 14, Sonipat', 'Tomorrow 10:00 AM'),
    DemoRequest('Bathroom tap leaking', 'Plumbing', 'Model Town', 'Today 6:00 PM'),
  ];

  final bids = <DemoBid>[
    DemoBid('CoolFix Services', 650, DateTime.now().subtract(const Duration(hours: 3))),
    DemoBid('Quick AC Care', 600, DateTime.now().subtract(const Duration(hours: 2))),
    DemoBid('CoolFix Services', 550, DateTime.now().subtract(const Duration(hours: 1))),
  ];

  final messages = <DemoMessage>[
    DemoMessage('Provider', 'Hello, I can come tomorrow at 10 AM.', false),
    DemoMessage('You', 'Okay. Please bring the required tools.', true),
  ];

  bool bookingCreated = false;
  bool groupPublished = false;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DemoHome(onOpenBids: _openBids),
      DemoRequests(requests: requests, onOpenBids: _openBids, onAdd: _addRequest),
      DemoGroups(
        published: groupPublished,
        onPublish: () => setState(() => groupPublished = true),
      ),
      DemoChat(messages: messages, onSend: _sendMessage),
      DemoAccount(bookingCreated: bookingCreated),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bid&Book Demo'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('OFFLINE DEMO'),
          ),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.request_page_outlined), selectedIcon: Icon(Icons.request_page), label: 'Requests'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Groups'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }

  void _openBids() async {
    final booked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DemoBidHistoryScreen(bids: bids),
      ),
    );
    if (booked == true) setState(() => bookingCreated = true);
  }

  void _addRequest() {
    setState(() {
      requests.insert(
        0,
        DemoRequest('Ceiling fan installation', 'Electrician', 'Sector 15', 'Saturday 11:00 AM'),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demo request posted.')),
    );
  }

  void _sendMessage(String value) {
    if (value.trim().isEmpty) return;
    setState(() => messages.add(DemoMessage('You', value.trim(), true)));
  }
}

class DemoHome extends StatelessWidget {
  const DemoHome({required this.onOpenBids, super.key});
  final VoidCallback onOpenBids;

  @override
  Widget build(BuildContext context) {
    final services = const [
      ('AC Repair & Service', 'CoolFix Services', '₹499', Icons.ac_unit),
      ('Plumber', 'Aman Plumbing', '₹299', Icons.plumbing),
      ('Electrician', 'Bright Home Electric', '₹349', Icons.electrical_services),
      ('Home Cleaning', 'FreshNest', '₹699', Icons.cleaning_services),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Find trusted local help', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text('Book directly or post a request and let providers compete transparently.'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Popular services', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        for (final item in services) ...[
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: CircleAvatar(child: Icon(item.$4)),
              title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${item.$2}\n⭐ 4.8 • Verified provider'),
              isThreeLine: true,
              trailing: Text(item.$3, style: const TextStyle(fontWeight: FontWeight.w900)),
              onTap: () => _serviceDialog(context, item.$1, item.$2, item.$3),
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onOpenBids,
          icon: const Icon(Icons.gavel_outlined),
          label: const Text('View transparent bid history demo'),
        ),
      ],
    );
  }

  void _serviceDialog(BuildContext context, String title, String provider, String price) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(provider),
            const SizedBox(height: 6),
            Text('$price starting price', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Demo booking request created.')),
                  );
                },
                child: const Text('Book service'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DemoRequests extends StatelessWidget {
  const DemoRequests({required this.requests, required this.onOpenBids, required this.onAdd, super.key});
  final List<DemoRequest> requests;
  final VoidCallback onOpenBids;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(child: Text('Service requests', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
            IconButton.filled(onPressed: onAdd, icon: const Icon(Icons.add)),
          ],
        ),
        const SizedBox(height: 12),
        for (final request in requests) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('${request.category} • ${request.area}'),
                  Text(request.when),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Chip(label: Text('Bidding open')),
                      const Spacer(),
                      FilledButton.tonal(onPressed: onOpenBids, child: const Text('View bids')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class DemoBidHistoryScreen extends StatefulWidget {
  const DemoBidHistoryScreen({required this.bids, super.key});
  final List<DemoBid> bids;

  @override
  State<DemoBidHistoryScreen> createState() => _DemoBidHistoryScreenState();
}

class _DemoBidHistoryScreenState extends State<DemoBidHistoryScreen> {
  late final List<DemoBid> bids = List.of(widget.bids);

  @override
  Widget build(BuildContext context) {
    final latestByProvider = <String, DemoBid>{};
    for (final bid in bids) {
      latestByProvider[bid.provider] = bid;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Permanent bid history')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Every bid and every rebid remains visible. A revised price appends a new event and never overwrites the old one.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (final bid in bids.reversed) ...[
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: const CircleAvatar(child: Icon(Icons.currency_rupee)),
                title: Text('${bid.provider} • ₹${bid.amount}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(latestByProvider[bid.provider] == bid ? 'CURRENT OFFER' : 'HISTORICAL BID — permanently visible'),
                trailing: latestByProvider[bid.provider] == bid
                    ? FilledButton(
                        onPressed: () => _accept(context, bid),
                        child: const Text('Accept'),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 10),
          ],
          FilledButton.tonalIcon(
            onPressed: _rebid,
            icon: const Icon(Icons.add),
            label: const Text('Simulate provider rebid'),
          ),
        ],
      ),
    );
  }

  void _rebid() {
    final last = bids.lastWhere((item) => item.provider == 'CoolFix Services');
    setState(() {
      bids.add(DemoBid('CoolFix Services', (last.amount - 50).clamp(250, 5000), DateTime.now()));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('New bid appended. Previous prices are still visible.')),
    );
  }

  void _accept(BuildContext context, DemoBid bid) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Accept exact bid?'),
        content: Text('Create a booking for ${bid.provider} at exactly ₹${bid.amount}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context, true);
            },
            child: const Text('Accept & book'),
          ),
        ],
      ),
    );
  }
}

class DemoGroups extends StatefulWidget {
  const DemoGroups({required this.published, required this.onPublish, super.key});
  final bool published;
  final VoidCallback onPublish;

  @override
  State<DemoGroups> createState() => _DemoGroupsState();
}

class _DemoGroupsState extends State<DemoGroups> {
  String vote = 'Accept';
  int quantity = 1;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Green Residency', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const Text('Neighborhood group • 84 members • Sector 14'),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Society-wide AC service', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('Members vote and enter how many AC units they want serviced.'),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Accept', label: Text('Accept')),
                    ButtonSegment(value: 'Maybe', label: Text('Maybe')),
                    ButtonSegment(value: 'Reject', label: Text('Reject')),
                  ],
                  selected: {vote},
                  onSelectionChanged: (values) => setState(() => vote = values.first),
                ),
                const SizedBox(height: 14),
                if (vote == 'Accept')
                  Row(
                    children: [
                      const Text('Quantity'),
                      const Spacer(),
                      IconButton(onPressed: quantity > 1 ? () => setState(() => quantity--) : null, icon: const Icon(Icons.remove_circle_outline)),
                      Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w800)),
                      IconButton(onPressed: () => setState(() => quantity++), icon: const Icon(Icons.add_circle_outline)),
                    ],
                  ),
                const Divider(height: 28),
                const Text('Current summary: 42 Accept • 8 Maybe • 5 Reject • 61 units'),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.published ? null : widget.onPublish,
                    child: Text(widget.published ? 'Published for bidding' : 'Publish group request'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DemoChat extends StatefulWidget {
  const DemoChat({required this.messages, required this.onSend, super.key});
  final List<DemoMessage> messages;
  final ValueChanged<String> onSend;

  @override
  State<DemoChat> createState() => _DemoChatState();
}

class _DemoChatState extends State<DemoChat> {
  final text = TextEditingController();

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ListTile(
          leading: CircleAvatar(child: Icon(Icons.handyman)),
          title: Text('CoolFix Services', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('Booking chat • AC service'),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: widget.messages.length,
            itemBuilder: (context, index) {
              final message = widget.messages[index];
              return Align(
                alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: const BoxConstraints(maxWidth: 290),
                  decoration: BoxDecoration(
                    color: message.mine
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(message.text),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: text,
                    decoration: const InputDecoration(hintText: 'Message provider…', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () {
                    widget.onSend(text.text);
                    text.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DemoAccount extends StatelessWidget {
  const DemoAccount({required this.bookingCreated, super.key});
  final bool bookingCreated;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: ListTile(
            contentPadding: EdgeInsets.all(18),
            leading: CircleAvatar(radius: 28, child: Icon(Icons.person)),
            title: Text('Demo User', style: TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text('+91 98765 43210\nPhone verified • Identity demo'),
            isThreeLine: true,
          ),
        ),
        const SizedBox(height: 14),
        ListTile(
          leading: const Icon(Icons.event_available_outlined),
          title: const Text('My bookings'),
          subtitle: Text(bookingCreated ? '1 confirmed demo booking' : 'Accept a bid to create a booking'),
        ),
        const ListTile(
          leading: Icon(Icons.verified_user_outlined),
          title: Text('Trust & payments'),
          subtitle: Text('Demo identity, payment, payout and dispute flow'),
        ),
        const ListTile(
          leading: Icon(Icons.support_agent),
          title: Text('Support & safety'),
          subtitle: Text('Reports, support cases and blocking'),
        ),
        const ListTile(
          leading: Icon(Icons.schedule_outlined),
          title: Text('Provider availability'),
          subtitle: Text('Mon–Sat • 9:00 AM–7:00 PM'),
        ),
        const Divider(),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Offline demo mode: actions are simulated locally. Real OTP, real payments, real messages and cloud data are intentionally disabled in this APK.',
            ),
          ),
        ),
      ],
    );
  }
}

class DemoRequest {
  DemoRequest(this.title, this.category, this.area, this.when);
  final String title;
  final String category;
  final String area;
  final String when;
}

class DemoBid {
  DemoBid(this.provider, this.amount, this.submittedAt);
  final String provider;
  final int amount;
  final DateTime submittedAt;
}

class DemoMessage {
  DemoMessage(this.sender, this.text, this.mine);
  final String sender;
  final String text;
  final bool mine;
}
