List<String> _ls(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];

class AppUser {
  final String id, name, role, dept, username;
  final String? batch, section, reason;
  final bool hod;
  final bool? allowed;
  AppUser({required this.id, required this.name, required this.role, required this.username, this.dept = '', this.batch, this.section,
      this.hod = false, this.allowed, this.reason});

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        username: (j['username'] ?? j['id']).toString(),
        name: j['name'],
        role: j['role'],
        dept: (j['dept'] ?? '').toString(),
        batch: j['batch'],
        section: j['section'],
        hod: j['hod'] == true,
        allowed: j['allowed'],
        reason: j['reason'],
      );
}

class Group {
  final String id, name, type, description;
  final Map<String, dynamic> joinRule;
  final List<String> postRoles;
  final bool canPost, canManage;
  Group({required this.id, required this.name, required this.type, this.description = '', required this.joinRule,
      required this.postRoles, this.canPost = false, this.canManage = false});

  factory Group.fromJson(Map<String, dynamic> j) => Group(
        id: j['id'],
        name: j['name'],
        type: j['type'] ?? 'custom',
        description: (j['description'] ?? '').toString(),
        joinRule: Map<String, dynamic>.from(j['joinRule'] ?? {}),
        postRoles: _ls(j['postRule'] == null ? null : j['postRule']['roles']),
        canPost: j['canPost'] == true,
        canManage: j['canManage'] == true,
      );
}

class Announcement {
  final String id, category, title, body, authorityName, authorityRole, authorityId;
  final DateTime? deadline;
  final int createdAt;
  final List<String> audienceRoles;

  const Announcement({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.authorityName,
    required this.authorityRole,
    required this.authorityId,
    required this.createdAt,
    required this.audienceRoles,
    this.deadline,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        id: json['id'].toString(),
        category: (json['category'] ?? 'event').toString(),
        title: (json['title'] ?? '').toString(),
        body: (json['body'] ?? '').toString(),
        authorityName: (json['authorityName'] ?? '').toString(),
        authorityRole: (json['authorityRole'] ?? '').toString(),
        authorityId: (json['authorityId'] ?? '').toString(),
        createdAt: (json['createdAt'] as num).toInt(),
        audienceRoles: _ls(json['audienceRoles']),
        deadline: json['deadline'] == null ? null : DateTime.tryParse(json['deadline'].toString()),
      );
}

class Message {
  final String id, senderId, senderName, senderRole, text;
  final String? groupId, fromId, toId;
  final int ts;
  Message({required this.id, required this.senderId, required this.senderName, required this.senderRole,
      required this.text, required this.ts, this.groupId, this.fromId, this.toId});

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'],
        senderId: (j['senderId'] ?? j['fromId']).toString(),
        senderName: (j['senderName'] ?? '').toString(),
        senderRole: (j['senderRole'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
        ts: (j['ts'] as num).toInt(),
        groupId: j['groupId'],
        fromId: j['fromId'],
        toId: j['toId'],
      );
}

class AlertInfo {
  final String id, type, location, note, fromName, fromRole;
  final int ts;
  AlertInfo({required this.id, required this.type, required this.location, required this.note,
      required this.fromName, required this.fromRole, required this.ts});

  factory AlertInfo.fromJson(Map<String, dynamic> j) {
    final f = Map<String, dynamic>.from(j['from'] ?? {});
    return AlertInfo(
      id: j['id'],
      type: (j['type'] ?? '').toString(),
      location: (j['location'] ?? '').toString(),
      note: (j['note'] ?? '').toString(),
      fromName: (f['name'] ?? '').toString(),
      fromRole: (f['role'] ?? '').toString(),
      ts: (j['ts'] as num).toInt(),
    );
  }
}

class ChatTarget {
  final Group? group;
  final AppUser? peer;
  ChatTarget.group(Group g)
      : group = g,
        peer = null;
  ChatTarget.dm(AppUser p)
      : peer = p,
        group = null;
  String get key => group != null ? group!.id : 'dm:${peer!.id}';
  String get title => group?.name ?? peer!.name;
}
