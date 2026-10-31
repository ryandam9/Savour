import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/food_entry.dart';
import '../services/vault_repository.dart';
import '../theme/savour_theme.dart';
import '../widgets/vault_image.dart';
import 'photo_viewer_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.repository});
  final VaultRepository repository;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  void _moveMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selected = DateTime(_month.year, _month.month, 1);
    });
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year && first.month == second.month && first.day == second.day;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: ListenableBuilder(
      listenable: widget.repository,
      builder: (context, child) {
        final entries = widget.repository.entries;
        final counts = <int, int>{};
        for (final e in entries) {
          if (e.eatenAt.year == _month.year && e.eatenAt.month == _month.month) {
            counts[e.eatenAt.day] = (counts[e.eatenAt.day] ?? 0) + 1;
          }
        }
        final selected = entries.where((e) => _sameDay(e.eatenAt, _selected)).toList();
        final days = DateUtils.getDaysInMonth(_month.year, _month.month);
        final offset = DateTime(_month.year, _month.month, 1).weekday - 1;
        return ListView(padding: const EdgeInsets.fromLTRB(24, 32, 24, 145), children: [
          Text('THE DAYS, WELL SPENT', style: eyebrow()),
          const SizedBox(height: 14),
          Text('Your food calendar', style: editorialTitle(size: 36)),
          const SizedBox(height: 12),
          const Text('Some days are worth tasting twice.', style: TextStyle(color: SavourColors.muted)),
          const SizedBox(height: 29),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 19, 14, 18),
            decoration: BoxDecoration(color: SavourColors.cream, borderRadius: BorderRadius.circular(23), border: Border.all(color: SavourColors.line)),
            child: Column(children: [
              Row(children: [
                IconButton(tooltip: 'Previous month', onPressed: () => _moveMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
                Expanded(child: Text(DateFormat('MMMM yyyy').format(_month), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'serif', fontSize: 22, fontWeight: FontWeight.w600))),
                IconButton(tooltip: 'Next month', onPressed: () => _moveMonth(1), icon: const Icon(Icons.chevron_right_rounded)),
              ]),
              const SizedBox(height: 15),
              Row(children: [
                for (final label in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                  Expanded(child: Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: SavourColors.muted, fontSize: 11)))),
              ]),
              const SizedBox(height: 8),
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 0.94),
                itemCount: offset + days,
                itemBuilder: (context, index) {
                  final day = index - offset + 1;
                  if (day <= 0) return const SizedBox.shrink();
                  final date = DateTime(_month.year, _month.month, day);
                  final active = _sameDay(_selected, date);
                  final hasPhotos = counts.containsKey(day);
                  return InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: () => setState(() => _selected = date),
                    child: Container(
                      decoration: BoxDecoration(
                        color: active ? SavourColors.terracotta : (hasPhotos ? SavourColors.paleRose : Colors.transparent),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('$day', style: TextStyle(fontSize: 13, fontWeight: hasPhotos || active ? FontWeight.w800 : FontWeight.w400, color: active ? Colors.white : SavourColors.ink)),
                        const SizedBox(height: 3),
                        if (hasPhotos) Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: active ? Colors.white : SavourColors.terracotta)),
                      ]),
                    ),
                  );
                },
              ),
            ]),
          ),
          const SizedBox(height: 29),
          Row(children: [
            Expanded(child: Text(DateFormat('EEEE, d MMMM').format(_selected), style: editorialTitle(size: 24))),
            Text('${selected.length} ${selected.length == 1 ? 'photo' : 'photos'}', style: const TextStyle(color: SavourColors.muted, fontSize: 12)),
          ]),
          const SizedBox(height: 15),
          if (selected.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(color: SavourColors.cream, borderRadius: BorderRadius.circular(20)),
              child: const Column(children: [
                Icon(Icons.auto_stories_outlined, size: 37, color: SavourColors.terracotta),
                SizedBox(height: 13),
                Text('No memories on this day', style: TextStyle(color: SavourColors.muted)),
              ]),
            )
          else
            for (final entry in selected) _CalendarMoment(
              entry: entry,
              repository: widget.repository,
              dayIds: selected.map((moment) => moment.id).toList(),
            ),
        ]);
      },
    ),
  );
}

class _CalendarMoment extends StatelessWidget {
  const _CalendarMoment({required this.entry, required this.repository, required this.dayIds});
  final FoodEntry entry;
  final VaultRepository repository;
  final List<String> dayIds;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoViewerScreen(repository: repository, entryIds: dayIds, initialId: entry.id))),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: SavourColors.cream, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(11), child: SizedBox(height: 78, width: 82, child: VaultImage(repository: repository, entryId: entry.id))),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text(DateFormat('h:mm a').format(entry.eatenAt), style: const TextStyle(color: SavourColors.muted, fontSize: 12)),
          ])),
          if (entry.isFavourite) const Icon(Icons.favorite, size: 17, color: SavourColors.terracotta),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: SavourColors.muted),
        ]),
      ),
    ),
  );
}
