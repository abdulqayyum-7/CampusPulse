import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/common.dart';
import 'admin/admin_screen.dart';
import 'create_group.dart';
import 'new_chat.dart';

class Sidebar extends StatefulWidget {
  final VoidCallback onOpened;
  const Sidebar({super.key, required this.onOpened});
  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  String _q = '';

  static const _sections = <(String, List<String>)>[
    ('University-Wide', ['broadcast']),
    ('My Department', ['dept', 'batch', 'section']),
    ('Helpdesks', ['helpdesk']),
    ('Operations', ['ops']),
    ('Courses', ['course']),
    ('Custom Groups', ['custom']),
  ];

  Future<void> _newChat() async {
    final st = context.read<AppState>();
    final peer = await Navigator.push<AppUser>(context, MaterialPageRoute(builder: (_) => const NewChatScreen()));
    if (peer != null) {
      await st.openDm(peer);
      widget.onOpened();
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final me = st.user!;
    final q = _q.toLowerCase();
    final visible = st.groups.where((g) => g.type != 'emergency' && g.name.toLowerCase().contains(q)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Container(
      color: Colors.white,
      child: Column(children: [
        // profile
        ListTile(
          leading: UserAvatar(name: me.name, role: me.role, online: true),
          title: Text(me.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              RoleBadge(me.role),
              if (me.dept.isNotEmpty) Text(me.dept, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            IconButton(tooltip: 'New chat', onPressed: _newChat, icon: const Icon(Icons.chat_outlined)),
            if (st.canCreateGroup)
              IconButton(
                  tooltip: 'Create group',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen())),
                  icon: const Icon(Icons.group_add_outlined)),
            if (me.role == 'admin')
              IconButton(
                  tooltip: 'Manage users & groups',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen())),
                  icon: const Icon(Icons.admin_panel_settings_outlined)),
            const Spacer(),
            IconButton(tooltip: 'Logout', onPressed: st.logout, icon: const Icon(Icons.logout)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: 'Search groups',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF1F3F8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(children: [
            for (final s in _sections)
              if (visible.any((g) => s.$2.contains(g.type)))
                ExpansionTile(
                  key: PageStorageKey(s.$1),
                  initiallyExpanded: true,
                  title: Text(s.$1.toUpperCase(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
                  children: [
                    for (final g in visible.where((g) => s.$2.contains(g.type))) _GroupTile(group: g, onOpened: widget.onOpened),
                  ],
                ),
            ExpansionTile(
              key: const PageStorageKey('dms'),
              initiallyExpanded: true,
              title: const Text('DIRECT MESSAGES',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
              children: [
                if (st.dmPeers.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No conversations yet. Tap the chat icon to start one.',
                          style: TextStyle(color: Colors.black45, fontSize: 12))),
                for (final id in st.dmPeers)
                  if (st.userById(id) != null) _DmTile(peer: st.userById(id)!, onOpened: widget.onOpened),
              ],
            ),
          ]),
        ),
      ]),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final Group group;
  final VoidCallback onOpened;
  const _GroupTile({required this.group, required this.onOpened});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final unread = st.unread[group.id] ?? 0;
    final selected = st.target?.key == group.id;
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: kBlue.withAlpha(20),
      leading: Icon(groupIcon(group.type), color: selected ? kBlue : Colors.black54),
      title: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (!group.canPost) const Icon(Icons.lock_outline, size: 15, color: Colors.black38),
        if (unread > 0) ...[
          const SizedBox(width: 6),
          CircleAvatar(radius: 10, backgroundColor: kBlue, child: Text('$unread', style: const TextStyle(fontSize: 11, color: Colors.white))),
        ],
      ]),
      onTap: () async {
        await context.read<AppState>().openGroup(group);
        onOpened();
      },
    );
  }
}

class _DmTile extends StatelessWidget {
  final AppUser peer;
  final VoidCallback onOpened;
  const _DmTile({required this.peer, required this.onOpened});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final unread = st.unread['dm:${peer.id}'] ?? 0;
    return ListTile(
      dense: true,
      selected: st.target?.key == 'dm:${peer.id}',
      selectedTileColor: kBlue.withAlpha(20),
      leading: UserAvatar(name: peer.name, role: peer.role, radius: 15, online: st.online.contains(peer.id)),
      title: Text(peer.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(roleLabel(peer.role), style: const TextStyle(fontSize: 11)),
      trailing: unread > 0
          ? CircleAvatar(radius: 10, backgroundColor: kBlue, child: Text('$unread', style: const TextStyle(fontSize: 11, color: Colors.white)))
          : null,
      onTap: () async {
        await context.read<AppState>().openDm(peer);
        onOpened();
      },
    );
  }
}
