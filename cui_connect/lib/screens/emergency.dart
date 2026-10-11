import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config.dart';
import '../providers/app_state.dart';

void showEmergencySheet(BuildContext context) {
  showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _EmergencySheet());
}

class _EmergencySheet extends StatefulWidget {
  const _EmergencySheet();
  @override
  State<_EmergencySheet> createState() => _EmergencySheetState();
}

class _EmergencySheetState extends State<_EmergencySheet> {
  String _type = emergencyTypes.first;
  final _loc = TextEditingController();
  final _note = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
          const SizedBox(width: 8),
          const Text('Send Emergency Alert', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        const Text('Goes to Security and Admin first.', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, children: [
          for (final t in emergencyTypes)
            ChoiceChip(label: Text(t), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
        ]),
        const SizedBox(height: 12),
        TextField(
            controller: _loc,
            decoration: const InputDecoration(labelText: 'Location (e.g. CS Block, Room 12)', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Message (optional)', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600, padding: const EdgeInsets.all(14)),
            icon: const Icon(Icons.send),
            label: const Text('Send Alert'),
            onPressed: () {
              context.read<AppState>().sendEmergency(
                  _type, _loc.text.trim().isEmpty ? 'Unknown' : _loc.text.trim(), _note.text.trim());
              Navigator.pop(context);
            },
          ),
        ),
      ]),
    );
  }
}
