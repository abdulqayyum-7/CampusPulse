import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/common.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});
  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  late final Future<List<AppUser>> _f = context.read<AppState>().dmCandidates();
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New message')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => _q = v.toLowerCase()),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search people', border: OutlineInputBorder(), isDense: true),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<AppUser>>(
            future: _f,
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              final list = (snap.data ?? []).where((u) => u.name.toLowerCase().contains(_q)).toList()
                ..sort((a, b) => (b.allowed == true ? 1 : 0).compareTo(a.allowed == true ? 1 : 0));
              return ListView(children: [
                for (final u in list)
                  Opacity(
                    opacity: u.allowed == true ? 1 : 0.45,
                    child: ListTile(
                      leading: UserAvatar(name: u.name, role: u.role),
                      title: Text(u.name),
                      subtitle: u.allowed == true
                          ? Row(children: [RoleBadge(u.role, small: true), const SizedBox(width: 6), Text(u.dept, style: const TextStyle(fontSize: 12))])
                          : Text(u.reason ?? 'Not allowed', style: const TextStyle(fontSize: 12)),
                      trailing: u.allowed == true ? null : const Icon(Icons.block, size: 18),
                      onTap: () {
                        if (u.allowed == true) {
                          Navigator.pop(context, u);
                        } else {
                          context.read<AppState>().toast("You can't message this user. No shared group or role permission.", error: true);
                        }
                      },
                    ),
                  ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}
