import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/config.dart';
import '../models/models.dart';

String fmtTime(int ts) => DateFormat('h:mm a').format(DateTime.fromMillisecondsSinceEpoch(ts));

class RoleBadge extends StatelessWidget {
  final String role;
  final bool small;
  const RoleBadge(this.role, {super.key, this.small = false});

  @override
  Widget build(BuildContext context) {
    final c = roleColor(role);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: small ? 1 : 2),
      decoration: BoxDecoration(color: c.withAlpha(32), borderRadius: BorderRadius.circular(10)),
      child: Text(roleLabel(role),
          style: TextStyle(fontSize: small ? 10 : 11, fontWeight: FontWeight.w600, color: c)),
    );
  }
}

class UserAvatar extends StatelessWidget {
  final String name, role;
  final double radius;
  final bool? online;
  const UserAvatar({super.key, required this.name, required this.role, this.radius = 20, this.online});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).where((w) => RegExp(r'^[A-Za-z]').hasMatch(w)).take(2).map((w) => w[0]).join();
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: roleColor(role).withAlpha(45),
      child: Text(initials.toUpperCase(),
          style: TextStyle(color: roleColor(role), fontWeight: FontWeight.w700, fontSize: radius * 0.7)),
    );
    if (online == null) return avatar;
    return Stack(clipBehavior: Clip.none, children: [
      avatar,
      Positioned(
        right: -1,
        bottom: -1,
        child: Container(
          width: radius * 0.6,
          height: radius * 0.6,
          decoration: BoxDecoration(
            color: online! ? Colors.green : Colors.grey,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    ]);
  }
}

String listLabel(String key, List<String> vals) =>
    vals.map((v) => key == 'roles' ? roleLabel(v) : v).join(' | ');

/// Join-rule + post-rule chips shown in group info.
List<Widget> ruleChips(Group g) {
  const names = {'roles': 'Roles', 'depts': 'Dept', 'batches': 'Batch', 'sections': 'Section'};
  final chips = <Widget>[];
  for (final k in names.keys) {
    final v = g.joinRule[k];
    if (v is List && v.isNotEmpty) {
      chips.add(Chip(
        label: Text('${names[k]}: ${listLabel(k, v.map((e) => e.toString()).toList())}', style: const TextStyle(fontSize: 12)),
        visualDensity: VisualDensity.compact,
      ));
    }
  }
  final u = g.joinRule['users'];
  if (u is List && u.isNotEmpty) {
    chips.add(Chip(label: Text('Extra users: ${u.length}', style: const TextStyle(fontSize: 12)), visualDensity: VisualDensity.compact));
  }
  return chips;
}

String postRuleText(Group g) {
  if (g.postRoles.contains('*')) return 'Everyone can post';
  if (g.postRoles.isEmpty) return 'Only Admin can post';
  return 'Only ${g.postRoles.map(roleLabel).join(', ')} can post';
}

/// Mirror of the server's membership rule, used only for the live preview in Create Group.
bool matchesJoinRule(AppUser u, Map<String, dynamic> j) {
  bool open(dynamic list, String? v) => list is! List || list.isEmpty || list.contains('*') || list.contains(v);
  if (j['users'] is List && (j['users'] as List).contains(u.id)) return true;
  final roles = j['roles'];
  if (roles is! List || roles.isEmpty) return false;
  return (roles.contains('*') || roles.contains(u.role)) &&
      open(j['depts'], u.dept) && open(j['batches'], u.batch) && open(j['sections'], u.section);
}
