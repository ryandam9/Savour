import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/food_entry.dart';
import '../services/vault_repository.dart';
import '../theme/savour_theme.dart';
import '../widgets/empty_album.dart';
import '../widgets/vault_image.dart';
import 'photo_viewer_screen.dart';

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key, required this.repository, required this.onAdd});
  final VaultRepository repository;
  final VoidCallback onAdd;

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  final _search = TextEditingController();
  bool _favouritesOnly = false;
  bool _searchVisible = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _search.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  List<FoodEntry> _filtered(List<FoodEntry> all) {
    final query = _search.text.trim().toLowerCase();
    return all.where((e) {
      if (_favouritesOnly && !e.isFavourite) return false;
      if (query.isEmpty) return true;
      return e.name.toLowerCase().contains(query) ||
          e.description.toLowerCase().contains(query) ||
          DateFormat('d MMMM yyyy').format(e.eatenAt).toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: ListenableBuilder(
      listenable: widget.repository,
      builder: (context, child) {
        final all = widget.repository.entries;
        final entries = _filtered(all);
        final groups = <String, List<FoodEntry>>{};
        for (final entry in entries) {
          final group = DateFormat('MMMM yyyy').format(entry.eatenAt);
          groups.putIfAbsent(group, () => []).add(entry);
        }
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(25, 25, 25, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Text('A PERSONAL FOOD JOURNAL', style: TextStyle(fontSize: 10, letterSpacing: 2.2, color: SavourColors.terracotta, fontWeight: FontWeight.w800))),
                  IconButton(
                    tooltip: 'Search meals',
                    onPressed: () => setState(() {
                      _searchVisible = !_searchVisible;
                      if (!_searchVisible) _search.clear();
                    }),
                    icon: Icon(_searchVisible ? Icons.close_rounded : Icons.search_rounded, color: SavourColors.ink),
                  ),
                ]),
                const SizedBox(height: 11),
                Text('Good food.\nGood memories.', style: editorialTitle(size: 42)),
                const SizedBox(height: 14),
                Text(all.isEmpty
                    ? 'Your private collection of delicious moments.'
                    : '${all.length} ${all.length == 1 ? 'moment' : 'moments'} worth remembering  ·  ${widget.repository.favouriteCount} loved',
                  style: const TextStyle(color: SavourColors.muted, fontSize: 13)),
                if (_searchVisible) ...[
                  const SizedBox(height: 21),
                  TextField(
                    controller: _search,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Dish, memory, or date…',
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                Row(children: [
                  _FilterPill(label: 'All moments', selected: !_favouritesOnly, onTap: () => setState(() => _favouritesOnly = false)),
                  const SizedBox(width: 9),
                  _FilterPill(label: 'Loved ones', selected: _favouritesOnly, icon: Icons.favorite_rounded, onTap: () => setState(() => _favouritesOnly = true)),
                ]),
                const SizedBox(height: 11),
              ]),
            ),
          ),
          if (entries.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyAlbum(
                onAdd: widget.onAdd,
                isFiltered: all.isNotEmpty || _favouritesOnly || _search.text.isNotEmpty,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(19, 12, 19, 145),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  for (final group in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 15, 6, 18),
                      child: Row(children: [
                        Text(group.key, style: editorialTitle(size: 24)),
                        const SizedBox(width: 13),
                        const Expanded(child: Divider()),
                        const SizedBox(width: 13),
                        Text('${group.value.length}', style: const TextStyle(color: SavourColors.muted, fontSize: 12)),
                      ]),
                    ),
                    _MasonryMonth(
                      entries: group.value,
                      repository: widget.repository,
                      allIds: entries.map((entry) => entry.id).toList(),
                    ),
                    const SizedBox(height: 22),
                  ],
                ]),
              ),
            ),
        ]);
      },
    ),
  );
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? SavourColors.ink : SavourColors.cream,
    shape: StadiumBorder(side: BorderSide(color: selected ? SavourColors.ink : SavourColors.line)),
    child: InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: selected ? Colors.white : SavourColors.terracotta),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(color: selected ? Colors.white : SavourColors.ink, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    ),
  );
}

class _MasonryMonth extends StatelessWidget {
  const _MasonryMonth({required this.entries, required this.repository, required this.allIds});
  final List<FoodEntry> entries;
  final VaultRepository repository;
  final List<String> allIds;

  @override
  Widget build(BuildContext context) {
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      final card = Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: _PhotoTile(
          entry: entries[i],
          repository: repository,
          allIds: allIds,
          height: i % 4 == 0 || i % 4 == 3 ? 235 : 177,
        ),
      );
      if (i.isEven) {
        left.add(card);
      } else {
        right.add(card);
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: left)),
        const SizedBox(width: 13),
        Expanded(child: Column(children: right)),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.entry, required this.repository, required this.allIds, required this.height});
  final FoodEntry entry;
  final VaultRepository repository;
  final List<String> allIds;
  final double height;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(
      builder: (_) => PhotoViewerScreen(repository: repository, entryIds: allIds, initialId: entry.id),
    )),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: SizedBox(height: height, child: Stack(fit: StackFit.expand, children: [
        Hero(
          tag: 'savour-${entry.id}',
          child: VaultImage(repository: repository, entryId: entry.id),
        ),
        const DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.53, 1.0],
            colors: [Color(0x32000000), Colors.transparent, Color(0xAF000000)],
          ),
        )),
        Positioned(top: 9, right: 9, child: entry.isFavourite
            ? const Icon(Icons.favorite_rounded, size: 23, color: Color(0xFFFFDFD4))
            : const SizedBox.shrink()),
        Positioned(left: 13, bottom: 14, right: 10, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(DateFormat('d MMM').format(entry.eatenAt).toUpperCase(), style: const TextStyle(fontSize: 9, letterSpacing: 1.3, fontWeight: FontWeight.w800, color: Color(0xFFEADDD4))),
            if (entry.name.trim().isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'serif', color: Colors.white, fontSize: 19, height: 1.05, fontWeight: FontWeight.w600)),
            ],
          ],
        )),
      ])),
    ),
  );
}
