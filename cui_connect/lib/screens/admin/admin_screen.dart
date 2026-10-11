import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../services/api.dart';
import '../../widgets/common.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage users & groups'),
          bottom: const TabBar(tabs: [Tab(text: 'Users'), Tab(text: 'Groups')]),
        ),
        body: const TabBarView(children: [_UsersTab(), _GroupsTab()]),
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  Future<void> _addUser(BuildContext context) async {
    final st = context.read<AppState>();
    final name = TextEditingController();
    final dept = TextEditingController();
    final batch = TextEditingController();
    final section = TextEditingController();
    String role = 'student';
    bool hod = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add user'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [for (final r in kRoles) DropdownMenuItem(value: r, child: Text(roleLabel(r)))],
                onChanged: (v) => setS(() => role = v!),
              ),
              TextField(controller: dept, decoration: const InputDecoration(labelText: 'Department (e.g. CS)')),
              if (role == 'student') ...[
                TextField(controller: batch, decoration: const InputDecoration(labelText: 'Batch (e.g. FA23)')),
                TextField(controller: section, decoration: const InputDecoration(labelText: 'Section (e.g. A)')),
              ],
              if (role == 'teaching')
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: hod,
                    onChanged: (v) => setS(() => hod = v ?? false),
                    title: const Text('Head of Department')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      final done = await Api.addUser(st.token!, {
        'name': name.text.trim(),
        'role': role,
        'dept': dept.text.trim(),
        if (batch.text.trim().isNotEmpty) 'batch': batch.text.trim(),
        if (section.text.trim().isNotEmpty) 'section': section.text.trim(),
        'hod': hod,
      });
      await st.refreshUsers();
      st.toast(done ? 'User added' : 'Could not add user', error: !done);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addUser(context), icon: const Icon(Icons.person_add), label: const Text('Add user')),
      body: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        for (final u in st.allUsers)
          ListTile(
            leading: UserAvatar(name: u.name, role: u.role, online: st.online.contains(u.id)),
            title: Text(u.name),
            subtitle: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              RoleBadge(u.role, small: true),
              Text([u.dept, u.batch, u.section].where((e) => e != null && e.isNotEmpty).join(' / '), style: const TextStyle(fontSize: 12)),
              if (u.hod) const Text('HOD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
            trailing: u.id == st.user!.id
                ? null
                : IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () async {
                      await Api.deleteUser(st.token!, u.id);
                      await st.refreshUsers();
                    }),
          ),
      ]),
    );
  }
}

class _GroupsTab extends StatelessWidget {
  const _GroupsTab();

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    return FutureBuilder<List<Group>>(
      future: Api.allGroups(st.token!),
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return const Center(child: Text('Could not load groups'));
        final groups = snap.data!;
        return ListView(padding: const EdgeInsets.all(12), children: [
          for (final g in groups)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(groupIcon(g.type), color: kBlue),
                    const SizedBox(width: 8),
                    Expanded(child: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text(g.type, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ]),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: [
                    ...ruleChips(g),
                    Chip(
                        avatar: const Icon(Icons.edit_outlined, size: 14),
                        label: Text(postRuleText(g).replaceAll('Only ', 'Post: '), style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact),
                  ]),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}
