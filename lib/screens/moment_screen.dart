import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/food_entry.dart';
import '../services/vault_repository.dart';
import '../theme/savour_theme.dart';
import '../widgets/vault_image.dart';
import 'editor_screen.dart';
import 'photo_viewer_screen.dart';

class MomentScreen extends StatelessWidget {
  const MomentScreen({super.key, required this.repository, required this.id});
  final VaultRepository repository;
  final String id;

  Future<void> _delete(BuildContext context, FoodEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Let this memory go?'),
        content: const Text('This removes the photo and its details from your private album. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete', style: TextStyle(color: SavourColors.terracotta))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) { return; }
    try {
      await repository.delete(entry);
      if (context.mounted) { Navigator.pop(context); }
    } catch (error) {
      if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $error'))); }
    }
  }

  Future<void> _favourite(BuildContext context, FoodEntry entry) async {
    try {
      await repository.toggleFavourite(entry);
    } catch (error) {
      if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update: $error'))); }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: repository,
    builder: (context, child) {
      FoodEntry? entry;
      for (final item in repository.entries) {
        if (item.id == id) { entry = item; break; }
      }
      if (entry == null) {
        return const Scaffold(body: Center(child: Text('This memory has been removed.')));
      }
      final current = entry;
      return Scaffold(
        body: CustomScrollView(slivers: [
          SliverAppBar(
            expandedHeight: MediaQuery.sizeOf(context).height * 0.55,
            pinned: false,
            stretch: true,
            backgroundColor: SavourColors.ink,
            leading: Padding(padding: const EdgeInsets.all(6), child: CircleAvatar(
              backgroundColor: SavourColors.cream,
              child: IconButton(onPressed: () => Navigator.pop(context), tooltip: 'Back', icon: const Icon(Icons.arrow_back, size: 19, color: SavourColors.ink)),
            )),
            actions: [
              Padding(padding: const EdgeInsets.only(right: 8), child: CircleAvatar(
                backgroundColor: SavourColors.cream,
                child: IconButton(
                  onPressed: () => _favourite(context, current),
                  tooltip: current.isFavourite ? 'Remove favourite' : 'Mark favourite',
                  icon: Icon(current.isFavourite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: SavourColors.terracotta, size: 20),
                ),
              )),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => PhotoViewerScreen(
                    repository: repository,
                    entryIds: repository.entries.map((entry) => entry.id).toList(),
                    initialId: current.id,
                  ),
                )),
                child: Hero(
                  tag: 'savour-${current.id}',
                  child: VaultImage(repository: repository, entryId: current.id, fullResolution: true),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 29, 26, 45),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(DateFormat('EEEE · d MMMM yyyy · h:mm a').format(current.eatenAt).toUpperCase(), style: eyebrow(size: 10)),
              const SizedBox(height: 14),
              Text(current.displayName, style: editorialTitle(size: 37)),
              if (current.description.isNotEmpty) ...[
                const SizedBox(height: 21),
                Text(current.description, style: const TextStyle(fontSize: 15, height: 1.7, color: SavourColors.ink)),
              ] else ...[
                const SizedBox(height: 14),
                const Text('A moment worth keeping.', style: TextStyle(color: SavourColors.muted, fontSize: 14)),
              ],
              const SizedBox(height: 35),
              const Divider(),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditorScreen(repository: repository, existing: current))),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit memory'),
                  style: OutlinedButton.styleFrom(foregroundColor: SavourColors.ink, padding: const EdgeInsets.symmetric(vertical: 15), side: const BorderSide(color: SavourColors.line)),
                )),
                const SizedBox(width: 12),
                IconButton.outlined(onPressed: () => _delete(context, current), tooltip: 'Delete photo', icon: const Icon(Icons.delete_outline_rounded, color: SavourColors.terracotta)),
              ]),
            ]),
          )),
        ]),
      );
    },
  );
}
