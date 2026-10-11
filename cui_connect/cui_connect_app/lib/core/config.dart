import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const kBlue = Color(0xFF0B4F9E);

class Config {
  // Hardcoded for physical-device testing. Change if your PC's IP changes.
  static String baseUrl = 'http://192.168.2.114:3000';
}

const kRoles = ['student', 'teaching', 'nonTeaching', 'finance', 'academic', 'administrative', 'security', 'cleaning', 'admin'];
const kDepts = ['CS', 'EE', 'Management Sciences'];
const kBatches = ['FA21', 'FA22', 'FA23', 'SP24', 'FA24', 'SP25'];
const emergencyTypes = ['Fire', 'Medical', 'Security threat', 'Harassment', 'Other'];

const roleLabels = <String, String>{
  'student': 'Student',
  'teaching': 'Teacher',
  'nonTeaching': 'Non-Teaching',
  'finance': 'Finance',
  'academic': 'Academic',
  'administrative': 'Administrative',
  'security': 'Security',
  'cleaning': 'Cleaning',
  'admin': 'Admin',
  '*': 'Everyone',
};

const roleColors = <String, Color>{
  'student': Color(0xFF1E88E5),
  'teaching': Color(0xFF8E24AA),
  'finance': Color(0xFFFFB300),
  'academic': Color(0xFF00897B),
  'administrative': Color(0xFF546E7A),
  'nonTeaching': Color(0xFFF4511E),
  'security': Color(0xFF2E7D32),
  'cleaning': Color(0xFF757575),
  'admin': Color(0xFF212121),
};

Color roleColor(String r) => roleColors[r] ?? Colors.grey;
String roleLabel(String r) => roleLabels[r] ?? r;

IconData groupIcon(String type) {
  switch (type) {
    case 'broadcast':
      return Icons.campaign_outlined;
    case 'dept':
      return Icons.apartment_outlined;
    case 'batch':
    case 'section':
      return Icons.groups_outlined;
    case 'helpdesk':
      return Icons.support_agent_outlined;
    case 'ops':
      return Icons.shield_outlined;
    case 'course':
      return Icons.menu_book_outlined;
    default:
      return Icons.forum_outlined;
  }
}
