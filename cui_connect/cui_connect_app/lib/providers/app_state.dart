import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/config.dart';
import '../models/models.dart';
import '../services/api.dart';

class AppState extends ChangeNotifier {
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  AppUser? user;
  String? token;
  List<Group> groups = [];
  List<AppUser> allUsers = [];
  List<Announcement> announcements = [];
  bool announcementsLoading = false;
  String? announcementsError;
  final Map<String, List<Message>> messages = {};
  final Map<String, int> unread = {};
  final Set<String> online = {};
  final Map<String, String> typing = {};
  final List<AlertInfo> alerts = [];
  final List<String> dmPeers = [];
  ChatTarget? target;
  io.Socket? _socket;
  final Map<String, Timer> _typingTimers = {};

  bool get canCreateGroup => user != null && (user!.role == 'admin' || (user!.role == 'teaching' && user!.hod));
  bool get canPublishEvent => user != null && (user!.role == 'admin' || user!.role == 'academic' || user!.role == 'administrative' || (user!.role == 'teaching' && user!.hod));
  bool get canPublishScholarship => user != null && (user!.role == 'admin' || user!.role == 'academic' || user!.role == 'administrative' || user!.role == 'finance');
  bool get canPublishAnnouncement => canPublishEvent || canPublishScholarship;

  void toast(String m, {bool error = false}) {
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), backgroundColor: error ? Colors.red.shade700 : null));
  }

  // ---------- auth ----------
  Future<void> login(String username, String password) async {
    final r = await Api.login(username, password);
    token = r['token'];
    user = AppUser.fromJson(Map<String, dynamic>.from(r['user']));
    await refreshUsers();
    await loadAnnouncements();
    _connect();
    notifyListeners();
  }

  Future<void> refreshUsers() async {
    try {
      allUsers = await Api.users(token);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadAnnouncements() async {
    final currentToken = token;
    if (currentToken == null) return;
    announcementsLoading = true;
    announcementsError = null;
    notifyListeners();
    try {
      announcements = await Api.announcements(currentToken);
    } catch (e) {
      announcementsError = e.toString();
    } finally {
      announcementsLoading = false;
      notifyListeners();
    }
  }

  Future<String?> publishAnnouncement({required String category, required String title, required String body, required List<String> audienceRoles, DateTime? deadline}) async {
    try {
      final item = await Api.publishAnnouncement(token!, {
        'category': category,
        'title': title,
        'body': body,
        'audienceRoles': audienceRoles,
        if (deadline != null) 'deadline': deadline.toUtc().toIso8601String(),
      });
      _upsertAnnouncement(item);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<bool> deleteAnnouncement(String id) async {
    try {
      await Api.deleteAnnouncement(token!, id);
      announcements.removeWhere((item) => item.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      toast('Could not remove announcement: $e', error: true);
      return false;
    }
  }

  void _upsertAnnouncement(Announcement item) {
    announcements = [item, ...announcements.where((old) => old.id != item.id)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  void logout() {
    _socket?.dispose();
    _socket = null;
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    _typingTimers.clear();
    user = null;
    token = null;
    groups = [];
    allUsers = [];
    announcements = [];
    announcementsError = null;
    messages.clear();
    unread.clear();
    online.clear();
    typing.clear();
    alerts.clear();
    dmPeers.clear();
    target = null;
    notifyListeners();
  }

  // ---------- socket ----------
  void _connect() {
    final s = io.io(
      Config.baseUrl,
      io.OptionBuilder().setTransports(['websocket']).setAuth({'token': token}).disableAutoConnect().build(),
    );
    _socket = s;

    s.on('ready', (d) {
      final m = Map<String, dynamic>.from(d);
      groups = (m['groups'] as List).map((e) => Group.fromJson(Map<String, dynamic>.from(e))).toList();
      online
        ..clear()
        ..addAll((m['onlineUserIds'] as List).map((e) => e.toString()));
      notifyListeners();
    });

    s.on('group:joined', (d) {
      final g = Group.fromJson(Map<String, dynamic>.from(d));
      groups = [...groups.where((x) => x.id != g.id), g];
      notifyListeners();
    });

    s.on('group:left', (d) {
      final id = Map<String, dynamic>.from(d)['groupId'];
      groups = groups.where((x) => x.id != id).toList();
      if (target?.group?.id == id) target = null;
      notifyListeners();
    });

    s.on('group:message', (d) {
      final m = Message.fromJson(Map<String, dynamic>.from(d));
      final k = m.groupId!;
      (messages[k] ??= []).add(m);
      if (target?.key != k && m.senderId != user?.id) unread[k] = (unread[k] ?? 0) + 1;
      notifyListeners();
    });

    s.on('dm:message', (d) {
      final m = Message.fromJson(Map<String, dynamic>.from(d));
      final other = m.fromId == user?.id ? m.toId! : m.fromId!;
      final k = 'dm:$other';
      (messages[k] ??= []).add(m);
      if (!dmPeers.contains(other)) dmPeers.insert(0, other);
      if (target?.key != k && m.senderId != user?.id) unread[k] = (unread[k] ?? 0) + 1;
      notifyListeners();
    });

    s.on('presence:update', (d) {
      final m = Map<String, dynamic>.from(d);
      m['online'] == true ? online.add(m['userId']) : online.remove(m['userId']);
      notifyListeners();
    });

    s.on('typing', (d) {
      final m = Map<String, dynamic>.from(d);
      final k = m['groupId'] != null ? m['groupId'] as String : 'dm:${m['dmWith']}';
      typing[k] = m['name'];
      _typingTimers[k]?.cancel();
      _typingTimers[k] = Timer(const Duration(seconds: 3), () {
        typing.remove(k);
        notifyListeners();
      });
      notifyListeners();
    });

    s.on('emergency:alert', (d) {
      alerts.insert(0, AlertInfo.fromJson(Map<String, dynamic>.from(d)));
      notifyListeners();
    });

    s.on('announcement:new', (d) {
      _upsertAnnouncement(Announcement.fromJson(Map<String, dynamic>.from(d)));
      toast('A new campus announcement is available');
    });
    s.on('connect', (_) => loadAnnouncements());
    s.on('announcement:removed', (d) {
      final id = Map<String, dynamic>.from(d)['id']?.toString();
      announcements.removeWhere((item) => item.id == id);
      notifyListeners();
    });

    s.on('emergency:ack', (d) {
      final m = Map<String, dynamic>.from(d);
      alerts.removeWhere((a) => a.id == m['alertId']);
      notifyListeners();
    });

    s.on('error:forbidden', (d) => toast(Map<String, dynamic>.from(d)['message'] ?? 'Not allowed', error: true));
    s.onConnectError((e) => toast('Connection error: $e', error: true));
    s.connect();
  }

  Future<Map<String, dynamic>> _ask(String ev, dynamic data) {
    final c = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck(ev, data, ack: (res) {
      if (!c.isCompleted) c.complete(res is Map ? Map<String, dynamic>.from(res) : {'ok': false});
    });
    return c.future.timeout(const Duration(seconds: 8), onTimeout: () => {'ok': false});
  }

  // ---------- chat ----------
  Future<void> openGroup(Group g) async {
    target = ChatTarget.group(g);
    unread[g.id] = 0;
    notifyListeners();
    final r = await _ask('group:history', {'groupId': g.id});
    if (r['ok'] == true) {
      messages[g.id] = (r['messages'] as List).map((e) => Message.fromJson(Map<String, dynamic>.from(e))).toList();
      notifyListeners();
    }
  }

  Future<void> openDm(AppUser p) async {
    target = ChatTarget.dm(p);
    final k = 'dm:${p.id}';
    unread[k] = 0;
    if (!dmPeers.contains(p.id)) dmPeers.insert(0, p.id);
    notifyListeners();
    final r = await _ask('dm:history', {'withUserId': p.id});
    if (r['ok'] == true) {
      messages[k] = (r['messages'] as List).map((e) => Message.fromJson(Map<String, dynamic>.from(e))).toList();
      notifyListeners();
    }
  }

  void closeChat() {
    target = null;
    notifyListeners();
  }

  void send(String text) {
    final t = target;
    if (t == null) return;
    if (t.group != null) {
      _socket?.emit('group:message', {'groupId': t.group!.id, 'text': text});
    } else {
      _socket?.emit('dm:send', {'toUserId': t.peer!.id, 'text': text});
    }
  }

  void sendTyping() {
    final t = target;
    if (t == null) return;
    _socket?.emit('typing', t.group != null ? {'groupId': t.group!.id} : {'toUserId': t.peer!.id});
  }

  AppUser? userById(String id) {
    for (final u in allUsers) {
      if (u.id == id) return u;
    }
    return null;
  }

  Future<List<AppUser>> dmCandidates() async {
    final c = Completer<List<AppUser>>();
    _socket!.emitWithAck('dm:candidates', {}, ack: (res) {
      if (!c.isCompleted) {
        c.complete((res as List).map((e) => AppUser.fromJson(Map<String, dynamic>.from(e))).toList());
      }
    });
    return c.future.timeout(const Duration(seconds: 8), onTimeout: () => []);
  }

  Future<List<AppUser>> members(String groupId) async {
    final r = await _ask('group:members', {'groupId': groupId});
    if (r['ok'] != true) return [];
    return (r['members'] as List).map((e) => AppUser.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<String?> createGroup(Map<String, dynamic> body) async {
    final r = await _ask('group:create', body);
    return r['ok'] == true ? null : (r['error'] ?? 'Could not create group').toString();
  }

  Future<bool> addMember(String groupId, String userId) async =>
      (await _ask('group:addMember', {'groupId': groupId, 'userId': userId}))['ok'] == true;

  Future<bool> removeMember(String groupId, String userId) async =>
      (await _ask('group:removeMember', {'groupId': groupId, 'userId': userId}))['ok'] == true;

  // ---------- emergency ----------
  Future<void> sendEmergency(String type, String location, String note) async {
    final r = await _ask('emergency:alert', {'type': type, 'location': location, 'note': note});
    if (r['ok'] == true) toast('Emergency alert sent to Security and Admin');
  }

  void ackAlert(String id) => _socket?.emit('emergency:ack', {'alertId': id});
}
