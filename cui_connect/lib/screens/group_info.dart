import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/common.dart';

class GroupInfoPanel extends StatefulWidget {
  final Group group;
  const GroupInfoPanel({super.key, required this.group});
  @override
  State<GroupInfoPanel> createState() => _GroupInfoPanelState();
}

class _GroupInfoPanelState extends State<GroupInfoPanel> {
  late Future<List<AppUser>> _f;

  @override
  void initState() {
    super.initState();
    _f = context.read<AppState>().members(widget.group.id);
  }

  @override
  void didUpdateWidget(covariant GroupInfoPanel old) {
    super.didUpdateWidget(old);
    if (old.group.id != widget.group.id) _reload();
  }

  void _reload() => setState(() => _f = context.read<AppState>().members(widget.group.id));

  Future<void> _addMember(List<AppUser> current) async {
    final st = context.read<AppState>();
    final ids = current.map((e) => e.id).toSet();
    final candidates = st.allUsers.where((u) => !ids.contains(u.id)).toList();
    final picked = await showDialog<AppUser>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add member'),
        content: SizedBox(
          width: 360,
          height: 360,
          child: ListView(children: [
            for (final u in candidates)
              ListTile(
                dense: true,
                leading: UserAvatar(name: u.name, role: u.role, radius: 14),
                title: Text(u.name),
                subtitle: Text('${roleLabel(u.role)}  ${u.dept}'),
                onTap: () => Navigator.pop(context, u),
              ),
          ]),
        ),
      ),
    );
    if (picked != null) {
      await st.addMember(widget.group.id, picked.id);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    Group g = widget.group;
    for (final x in st.groups) {
      if (x.id == g.id) g = x;
    }
    return Container(
      color: Colors.white,
      child: FutureBuilder<List<AppUser>>(
        future: _f,
        builder: (_, snap) {
          final members = snap.data ?? [];
          final byRole = <String, List<AppUser>>{};
          for (final m in members) {
            (byRole[m.role] ??= []).add(m);
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Text('About', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            if (g.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(g.description)),
            const SizedBox(height: 12),
            const Text('Who can join', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
            Wrap(spacing: 6, children: ruleChips(g)),
            const SizedBox(height: 10),
            const Text('Who can post', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
            Wrap(spacing: 6, children: [
              Chip(
                avatar: Icon(g.canPost ? Icons.edit_outlined : Icons.lock_outline, size: 16),
                label: Text(postRuleText(g), style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
              ),
            ]),
            const Divider(height: 28),
            Row(children: [
              Expanded(child: Text('Members (${members.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              if (g.canManage && snap.connectionState == ConnectionState.done)
                IconButton(tooltip: 'Add member', onPressed: () => _addMember(members), icon: const Icon(Icons.person_add_alt_1_outlined)),
            ]),
            if (snap.connectionState != ConnectionState.done) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
            for (final role in kRoles)
              if (byRole[role] != null) ...[
                Padding(padding: const EdgeInsets.only(top: 8, bottom: 2), child: RoleBadge(role)),
                for (final u in byRole[role]!)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: UserAvatar(name: u.name, role: u.role, radius: 14, online: st.online.contains(u.id)),
                    title: Text(u.name),
                    subtitle: u.dept.isEmpty ? null : Text(u.dept, style: const TextStyle(fontSize: 11)),
                    trailing: g.canManage && u.role != 'admin'
                        ? IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.redAccent),
                            onPressed: () async {
                              await context.read<AppState>().removeMember(g.id, u.id);
                              _reload();
                            })
                        : null,
                  ),
              ],
          ]);
        },
      ),
    );
  }
}
