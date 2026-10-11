import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config.dart';
import '../providers/app_state.dart';
import '../widgets/common.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});
  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _roles = <String>{};
  final _depts = <String>{};
  final _batches = <String>{};
  final _users = <String>{};
  final _postRoles = <String>{};
  bool _postEveryone = false;
  bool _busy = false;

  Map<String, dynamic> _joinRule(AppState st) {
    final isHod = st.user!.role != 'admin';
    final depts = isHod ? {st.user!.dept} : _depts;
    return {
      'roles': _roles.toList(),
      if (depts.isNotEmpty) 'depts': depts.toList(),
      if (_batches.isNotEmpty) 'batches': _batches.toList(),
      if (_users.isNotEmpty) 'users': _users.toList(),
    };
  }

  Future<void> _create() async {
    final st = context.read<AppState>();
    if (_name.text.trim().isEmpty) return st.toast('Enter a group name', error: true);
    if (_roles.isEmpty && _users.isEmpty) return st.toast('Pick at least one role or user', error: true);
    if (!_postEveryone && _postRoles.isEmpty) return st.toast('Choose who can post', error: true);
    setState(() => _busy = true);
    final err = await st.createGroup({
      'name': _name.text.trim(),
      'description': _desc.text.trim(),
      'joinRule': _joinRule(st),
      'postRule': {'roles': _postEveryone ? ['*'] : _postRoles.toList()},
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      Navigator.pop(context);
      st.toast('Group created');
    }
  }

  Widget _chips(String title, List<String> options, Set<String> sel, {String Function(String)? label}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final o in options)
          FilterChip(
            label: Text(label?.call(o) ?? o),
            selected: sel.contains(o),
            onSelected: (v) => setState(() => v ? sel.add(o) : sel.remove(o)),
          ),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final isHod = st.user!.role != 'admin';
    final rule = _joinRule(st);
    final count = st.allUsers.where((u) => u.role != 'admin' && matchesJoinRule(u, rule)).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Create group')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Group name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
            const Divider(height: 32),
            const Text('Who can join', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            _chips('Roles', kRoles.where((r) => r != 'admin').toList(), _roles, label: roleLabel),
            if (isHod)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Chip(avatar: const Icon(Icons.lock_outline, size: 16), label: Text('Department locked to ${st.user!.dept}')),
              )
            else
              _chips('Departments (empty = all)', kDepts, _depts),
            _chips('Batches (empty = all)', kBatches, _batches),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Add individual users (${_users.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
              children: [
                for (final u in st.allUsers.where((u) => u.role != 'admin'))
                  CheckboxListTile(
                    dense: true,
                    value: _users.contains(u.id),
                    onChanged: (v) => setState(() => v == true ? _users.add(u.id) : _users.remove(u.id)),
                    title: Text(u.name),
                    subtitle: Text('${roleLabel(u.role)} ${u.dept}'),
                  ),
              ],
            ),
            const Divider(height: 32),
            const Text('Who can post', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Everyone in the group'),
              subtitle: const Text('Turn off for announcements-only'),
              value: _postEveryone,
              onChanged: (v) => setState(() => _postEveryone = v),
            ),
            if (!_postEveryone) _chips('Roles allowed to post', kRoles.where((r) => r != 'admin').toList(), _postRoles, label: roleLabel),
            const SizedBox(height: 20),
            Card(
              color: kBlue.withAlpha(18),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const Icon(Icons.groups, color: kBlue),
                  const SizedBox(width: 10),
                  Text('Estimated members: $count', style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
              onPressed: _busy ? null : _create,
              child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create group'),
            ),
          ]),
        ),
      ),
    );
  }
}
