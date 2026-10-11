import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/common.dart';
import 'group_info.dart';

/// Narrow-screen wrapper around ChatPane.
class ChatPage extends StatelessWidget {
  const ChatPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: SafeArea(child: ChatPane(showBack: true)));
}

class ChatPane extends StatefulWidget {
  final bool showBack;
  const ChatPane({super.key, this.showBack = false});
  @override
  State<ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<ChatPane> {
  final _c = TextEditingController();
  DateTime _lastTyping = DateTime(2000);

  void _send() {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    context.read<AppState>().send(t);
    _c.clear();
  }

  void _onChanged(String _) {
    final now = DateTime.now();
    if (now.difference(_lastTyping).inSeconds >= 2) {
      _lastTyping = now;
      context.read<AppState>().sendTyping();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final t = st.target;
    if (t == null) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.forum_outlined, size: 64, color: Colors.black26),
          SizedBox(height: 8),
          Text('Select a group or conversation', style: TextStyle(color: Colors.black45)),
        ]),
      );
    }

    // always use the freshest group object (permissions can change live)
    final Group? g = _fresh(st, t.group);
    final msgs = st.messages[t.key] ?? const <Message>[];
    final typing = st.typing[t.key];
    final canPost = g == null ? true : g.canPost;

    return Column(children: [
      // header
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(children: [
          if (widget.showBack)
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
          if (g != null)
            Padding(padding: const EdgeInsets.all(8), child: Icon(groupIcon(g.type), color: kBlue))
          else
            Padding(
                padding: const EdgeInsets.all(8),
                child: UserAvatar(
                    name: t.peer!.name, role: t.peer!.role, radius: 16, online: st.online.contains(t.peer!.id))),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              if (g != null)
                Text(g.canPost ? postRuleText(g) : 'Read-only for you',
                    style: TextStyle(fontSize: 12, color: g.canPost ? Colors.black54 : Colors.orange.shade800))
              else
                Row(children: [
                  RoleBadge(t.peer!.role, small: true),
                  const SizedBox(width: 6),
                  Text(st.online.contains(t.peer!.id) ? 'online' : 'offline',
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ]),
            ]),
          ),
          if (g != null && !g.canPost)
            const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.lock_outline, size: 18, color: Colors.black45)),
          if (g != null && MediaQuery.of(context).size.width < 1200)
            IconButton(
              tooltip: 'Group info',
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                final grp = g;
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => Scaffold(
                            appBar: AppBar(title: Text(grp.name)), body: GroupInfoPanel(group: grp))));
              },
            ),
        ]),
      ),
      const Divider(height: 1),
      // messages
      Expanded(
        child: msgs.isEmpty
            ? const Center(child: Text('No messages yet', style: TextStyle(color: Colors.black45)))
            : ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: msgs.length,
                itemBuilder: (_, i) => _Bubble(m: msgs[msgs.length - 1 - i], mine: msgs[msgs.length - 1 - i].senderId == st.user!.id, showSender: g != null),
              ),
      ),
      if (typing != null)
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text('$typing is typing...', style: const TextStyle(fontSize: 12, color: Colors.black45, fontStyle: FontStyle.italic))),
        ),
      // input or read-only bar
      if (canPost)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _c,
                onChanged: _onChanged,
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Type a message',
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF1F3F8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(style: IconButton.styleFrom(backgroundColor: kBlue), onPressed: _send, icon: const Icon(Icons.send)),
          ]),
        )
      else
        Container(
          width: double.infinity,
          color: Colors.grey.shade200,
          padding: const EdgeInsets.all(16),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_outline, size: 16, color: Colors.black54),
            const SizedBox(width: 8),
            Flexible(child: Text(postRuleText(g!), style: const TextStyle(color: Colors.black54))),
          ]),
        ),
    ]);
  }
}

Group? _fresh(AppState st, Group? g) {
  if (g == null) return null;
  for (final x in st.groups) {
    if (x.id == g.id) return x;
  }
  return g;
}

class _Bubble extends StatelessWidget {
  final Message m;
  final bool mine, showSender;
  const _Bubble({required this.m, required this.mine, required this.showSender});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7 > 520 ? 520 : MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: mine ? kBlue : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 3),
            bottomRight: Radius.circular(mine ? 3 : 14),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 3, offset: const Offset(0, 1))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!mine && showSender)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(m.senderName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: roleColor(m.senderRole))),
                RoleBadge(m.senderRole, small: true),
              ]),
            ),
          Text(m.text, style: TextStyle(color: mine ? Colors.white : Colors.black87)),
          const SizedBox(height: 2),
          Align(
              alignment: Alignment.bottomRight,
              child: Text(fmtTime(m.ts), style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : Colors.black45))),
        ]),
      ),
    );
  }
}
