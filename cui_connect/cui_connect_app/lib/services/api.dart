import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import '../models/models.dart';

class Api {
  static Map<String, String> _h([String? token]) =>
      {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};

  static Future<List<AppUser>> users(String? token) async {
    final r = await http.get(Uri.parse('${Config.baseUrl}/api/users'), headers: _h(token)).timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) throw Exception('Server error ${r.statusCode}');
    return (jsonDecode(r.body) as List).map((e) => AppUser.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<Map<String, dynamic>> login(String username, String password) async {
    final r = await http.post(Uri.parse('${Config.baseUrl}/api/login'),
        headers: _h(), body: jsonEncode({'username': username, 'password': password}));
    if (r.statusCode != 200) {
      final body = jsonDecode(r.body);
      throw Exception(body is Map ? body['error'] ?? 'Login failed' : 'Login failed');
    }
    return Map<String, dynamic>.from(jsonDecode(r.body));
  }

  static Future<List<Announcement>> announcements(String token) async {
    final r = await http.get(Uri.parse('${Config.baseUrl}/api/announcements'), headers: _h(token)).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw Exception('Could not load announcements (${r.statusCode})');
    return (jsonDecode(r.body) as List).map((e) => Announcement.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<Announcement> publishAnnouncement(String token, Map<String, dynamic> body) async {
    final r = await http.post(Uri.parse('${Config.baseUrl}/api/announcements'), headers: _h(token), body: jsonEncode(body)).timeout(const Duration(seconds: 10));
    final data = Map<String, dynamic>.from(jsonDecode(r.body));
    if (r.statusCode != 201) throw Exception(data['error'] ?? 'Could not publish announcement');
    return Announcement.fromJson(data);
  }

  static Future<void> deleteAnnouncement(String token, String id) async {
    final r = await http.delete(Uri.parse('${Config.baseUrl}/api/announcements/$id'), headers: _h(token)).timeout(const Duration(seconds: 10));
    if (r.statusCode != 204) {
      final data = jsonDecode(r.body);
      throw Exception(data is Map ? data['error'] ?? 'Could not remove announcement' : 'Could not remove announcement');
    }
  }

  static Future<List<Group>> allGroups(String token) async {
    final r = await http.get(Uri.parse('${Config.baseUrl}/api/groups'), headers: _h(token));
    if (r.statusCode != 200) throw Exception('Forbidden');
    return (jsonDecode(r.body) as List).map((e) => Group.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<bool> addUser(String token, Map<String, dynamic> body) async {
    final r = await http.post(Uri.parse('${Config.baseUrl}/api/users'), headers: _h(token), body: jsonEncode(body));
    return r.statusCode == 201;
  }

  static Future<bool> deleteUser(String token, String id) async {
    final r = await http.delete(Uri.parse('${Config.baseUrl}/api/users/$id'), headers: _h(token));
    return r.statusCode == 204;
  }
}
