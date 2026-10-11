import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/common.dart';
import 'announcement_compose.dart';
import 'announcements_screen.dart';
import 'chat_screen.dart';
import 'emergency.dart';
import 'group_info.dart';
import 'sidebar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.hub_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('CampusPulse', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text('COMSATS University Islamabad', style: TextStyle(fontSize: 10, color: Colors.black54)),
          ]),
        ]),
        actions: [
          IconButton(
            tooltip: 'Emergency alert',
            onPressed: () => showEmergencySheet(context),
            icon: const Icon(Icons.emergency_outlined, color: Colors.red),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account options',
            onSelected: (value) {
              if (value == 'logout') state.logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text('${user.name}\n${roleLabel(user.role)}${user.dept.isEmpty ? '' : ' · ${user.dept}'}')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout), title: Text('Sign out'), contentPadding: EdgeInsets.zero)),
            ],
            child: Padding(
              padding: const EdgeInsets.only(left: 4, right: 14),
              child: UserAvatar(name: user.name, role: user.role, radius: 17, online: true),
            ),
          ),
        ],
      ),
      body: Column(children: [
        for (final alert in state.alerts) AlertBanner(alert: alert),
        Expanded(child: _section == 0 ? _chatContent(state) : const AnnouncementsScreen()),
      ]),
      floatingActionButton: _section == 1 && state.canPublishAnnouncement
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementComposeScreen())),
              icon: const Icon(Icons.add),
              label: const Text('New announcement'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _section,
        onDestinationSelected: (index) => setState(() => _section = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: 'Announcements'),
        ],
      ),
    );
  }

  Widget _chatContent(AppState state) => LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 900;
        if (!wide) {
          return Sidebar(onOpened: () {
            final current = context.read<AppState>();
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatPage())).then((_) => current.closeChat());
          });
        }
        final showInfo = c.maxWidth >= 1200 && state.target?.group != null;
        return Row(children: [
          SizedBox(width: 340, child: Sidebar(onOpened: () {})),
          const VerticalDivider(width: 1),
          const Expanded(child: ChatPane()),
          if (showInfo) ...[
            const VerticalDivider(width: 1),
            SizedBox(width: 300, child: GroupInfoPanel(group: state.target!.group!)),
          ],
        ]);
      });
}

class AlertBanner extends StatelessWidget {
  final AlertInfo alert;
  const AlertBanner({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.red.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        const Icon(Icons.campaign, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('EMERGENCY: ${alert.type} at ${alert.location}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            Text('From ${alert.fromName} (${roleLabel(alert.fromRole)}) at ${fmtTime(alert.ts)}${alert.note.isEmpty ? '' : ' - ${alert.note}'}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        TextButton(
          style: TextButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red.shade700),
          onPressed: () => context.read<AppState>().ackAlert(alert.id),
          child: const Text('Acknowledge'),
        ),
      ]),
    );
  }
}
