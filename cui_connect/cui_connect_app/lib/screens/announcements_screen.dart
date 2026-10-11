import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/config.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/common.dart';
import 'announcement_compose.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});
  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = state.announcements.where((item) => _filter == 'all' || item.category == _filter).toList();
    return Column(children: [
      Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Stay informed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Official campus news, events and funding opportunities.', style: TextStyle(color: Colors.black54, fontSize: 13)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _filterChip('all', 'All updates', Icons.dynamic_feed_outlined),
              const SizedBox(width: 8),
              _filterChip('event', 'Events', Icons.event_outlined),
              const SizedBox(width: 8),
              _filterChip('scholarship', 'Scholarships', Icons.school_outlined),
            ]),
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: state.announcementsLoading && state.announcements.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.announcementsError != null && state.announcements.isEmpty
                ? _LoadError(message: state.announcementsError!, onRetry: state.loadAnnouncements)
                : items.isEmpty
                    ? _EmptyState(filter: _filter, canPublish: state.canPublishAnnouncement)
                    : RefreshIndicator(
                        onRefresh: state.loadAnnouncements,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _AnnouncementCard(item: items[i]),
                        ),
                      ),
      ),
    ]);
  }

  Widget _filterChip(String key, String label, IconData icon) => ChoiceChip(
        selected: _filter == key,
        label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)]),
        onSelected: (_) => setState(() => _filter = key),
        selectedColor: kBlue.withAlpha(28),
        labelStyle: TextStyle(color: _filter == key ? kBlue : Colors.black87, fontWeight: FontWeight.w600),
        side: BorderSide(color: _filter == key ? kBlue.withAlpha(70) : Colors.black12),
      );
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement item;
  const _AnnouncementCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isScholarship = item.category == 'scholarship';
    final color = isScholarship ? const Color(0xFF087E73) : kBlue;
    final deadlinePassed = item.deadline != null && item.deadline!.isBefore(DateTime.now());
    final canRemove = state.user?.role == 'admin' || state.user?.id == item.authorityId;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: const BorderSide(color: Color(0xFFE5EAF1))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: color.withAlpha(18), borderRadius: BorderRadius.circular(12)),
              child: Icon(isScholarship ? Icons.school_outlined : Icons.event_outlined, color: color),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: color.withAlpha(18), borderRadius: BorderRadius.circular(20)),
              child: Text(isScholarship ? 'SCHOLARSHIP' : 'CAMPUS EVENT', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .4)),
            ),
            const Spacer(),
            if (canRemove)
              PopupMenuButton<String>(
                tooltip: 'Announcement options',
                onSelected: (value) async {
                  if (value != 'delete') return;
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Remove announcement?'),
                      content: const Text('This will remove the announcement for everyone who can see it.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
                      ],
                    ),
                  );
                  if (ok == true) await state.deleteAnnouncement(item.id);
                },
                itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Remove announcement'))],
              ),
          ]),
          const SizedBox(height: 13),
          Text(item.title, style: const TextStyle(fontSize: 17, height: 1.25, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(item.body, style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF475467))),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 11),
          Wrap(spacing: 14, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _meta(Icons.account_balance_outlined, item.authorityName),
            _meta(Icons.schedule_outlined, DateFormat('MMM d, yyyy').format(DateTime.fromMillisecondsSinceEpoch(item.createdAt))),
            if (item.deadline != null)
              _meta(
                Icons.event_available_outlined,
                '${deadlinePassed ? 'Closed' : 'Deadline'} · ${DateFormat('MMM d, yyyy').format(item.deadline!.toLocal())}',
                color: deadlinePassed ? Colors.red.shade700 : Colors.black54,
              ),
          ]),
        ]),
      ),
    );
  }

  Widget _meta(IconData icon, String text, {Color color = Colors.black54}) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 11, color: color)),
      ]);
}

class _EmptyState extends StatelessWidget {
  final String filter;
  final bool canPublish;
  const _EmptyState({required this.filter, required this.canPublish});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(filter == 'scholarship' ? Icons.school_outlined : Icons.campaign_outlined, size: 54, color: kBlue.withAlpha(100)),
            const SizedBox(height: 14),
            Text(filter == 'all' ? 'You’re all caught up' : 'No ${filter == 'event' ? 'events' : 'scholarships'} yet', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(canPublish ? 'Publish an official update for your campus community.' : 'Official updates from your university will appear here.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, height: 1.4)),
          ]),
        ),
      );
}

class _LoadError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.black38),
            const SizedBox(height: 10),
            const Text('Announcements are temporarily unavailable', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
          ]),
        ),
      );
}
