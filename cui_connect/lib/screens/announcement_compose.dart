import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config.dart';
import '../providers/app_state.dart';
import '../widgets/common.dart';

const _audienceOptions = <String>[
  'student', 'teaching', 'nonTeaching', 'finance', 'academic', 'administrative', 'security', 'cleaning',
];

class AnnouncementComposeScreen extends StatefulWidget {
  const AnnouncementComposeScreen({super.key});
  @override
  State<AnnouncementComposeScreen> createState() => _AnnouncementComposeScreenState();
}

class _AnnouncementComposeScreenState extends State<AnnouncementComposeScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  late String _category;
  late Set<String> _audience;
  DateTime? _deadline;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _category = state.canPublishEvent ? 'event' : 'scholarship';
    _audience = _defaultAudience(_category);
  }

  Set<String> _defaultAudience(String category) => category == 'scholarship'
      ? {'student', 'academic', 'administrative', 'finance'}
      : _audienceOptions.toSet();

  List<String> _categories(AppState state) => [
        if (state.canPublishEvent) 'event',
        if (state.canPublishScholarship) 'scholarship',
      ];

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (value != null) setState(() => _deadline = value);
  }

  Future<void> _publish() async {
    if (!_form.currentState!.validate()) return;
    if (_audience.isEmpty) {
      setState(() => _error = 'Select at least one audience.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppState>().publishAnnouncement(
          category: _category,
          title: _title.text.trim(),
          body: _body.text.trim(),
          deadline: _deadline,
          audienceRoles: _audience.toList(),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      setState(() => _error = error.replaceFirst('Exception: ', ''));
      return;
    }
    context.read<AppState>().toast('Announcement published');
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final categories = _categories(state);
    return Scaffold(
      appBar: AppBar(title: const Text('New announcement'), backgroundColor: Colors.white),
      backgroundColor: const Color(0xFFF4F6FA),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
              children: [
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE5EAF1))),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Official campus update', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      const Text('Your post will be attributed to your office and delivered to the selected roles.', style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4)),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _category,
                        decoration: const InputDecoration(labelText: 'Announcement type', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category_outlined)),
                        items: [
                          for (final item in categories)
                            DropdownMenuItem(value: item, child: Text(item == 'event' ? 'Campus event' : 'Scholarship opportunity')),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  _category = value;
                                  _audience = _defaultAudience(value);
                                });
                              },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _title,
                        maxLength: 120,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Title', hintText: 'A clear, informative headline', border: OutlineInputBorder()),
                        validator: (value) => (value ?? '').trim().length < 4 ? 'Enter at least 4 characters' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _body,
                        minLines: 4,
                        maxLines: 8,
                        maxLength: 5000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Details', hintText: 'Share eligibility, location, timing, links or how to apply.', border: OutlineInputBorder(), alignLabelWithHint: true),
                        validator: (value) => (value ?? '').trim().length < 10 ? 'Add at least 10 characters of details' : null,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _pickDate,
                        icon: const Icon(Icons.event_available_outlined),
                        label: Text(_deadline == null ? 'Add event date or application deadline' : 'Date: ${MaterialLocalizations.of(context).formatMediumDate(_deadline!)}'),
                      ),
                      if (_deadline != null)
                        Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _busy ? null : () => setState(() => _deadline = null), icon: const Icon(Icons.close, size: 16), label: const Text('Remove date'))),
                      const SizedBox(height: 18),
                      const Text('Audience', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('Only selected roles will receive this notice.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 4,
                        children: [
                          for (final role in _audienceOptions)
                            FilterChip(
                              label: Text(roleLabel(role)),
                              selected: _audience.contains(role),
                              onSelected: _busy ? null : (selected) => setState(() => selected ? _audience.add(role) : _audience.remove(role)),
                            ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('Publishing authority is determined by your university account. Posting unauthorized categories is blocked by the server.', style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4)),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SizedBox(
              height: 50,
              width: double.infinity,
              child: FilledButton.icon(onPressed: _busy ? null : _publish, icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.campaign_outlined), label: Text(_busy ? 'Publishing…' : 'Publish announcement')),
            ),
          ),
        ),
      ),
    );
  }
}
