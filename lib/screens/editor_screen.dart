import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/food_entry.dart';
import '../services/vault_repository.dart';
import '../theme/savour_theme.dart';
import '../widgets/vault_image.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.repository,
    this.newPhoto,
    this.existing,
  }) : assert((newPhoto == null) != (existing == null));

  final VaultRepository repository;
  final Uint8List? newPhoto;
  final FoodEntry? existing;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _description = TextEditingController(text: widget.existing?.description ?? '');
    _date = widget.existing?.eatenAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (chosen == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    if (!mounted) return;
    setState(() => _date = DateTime(
      chosen.year, chosen.month, chosen.day,
      time?.hour ?? _date.hour,
      time?.minute ?? _date.minute,
    ));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final old = widget.existing;
      if (old != null) {
        await widget.repository.update(old.copyWith(
          eatenAt: _date,
          name: _name.text,
          description: _description.text,
        ));
      } else {
        await widget.repository.addPhoto(widget.newPhoto!,
          eatenAt: _date,
          name: _name.text,
          description: _description.text,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: _saving ? null : () => Navigator.pop(context), icon: const Icon(Icons.close_rounded), tooltip: 'Close'),
        title: Text(editing ? 'Edit a moment' : 'A new moment', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: Text(editing ? 'Update' : 'Save', style: const TextStyle(fontWeight: FontWeight.w800, color: SavourColors.terracotta))),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(22, 12, 22, 40), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: SizedBox(
            height: 282,
            child: editing
                ? VaultImage(repository: widget.repository, entryId: widget.existing!.id)
                : Image.memory(widget.newPhoto!, fit: BoxFit.cover, width: double.infinity),
          ),
        ),
        const SizedBox(height: 24),
        Text(editing ? 'Make this memory yours.' : 'One for the memory book.', style: editorialTitle(size: 30)),
        const SizedBox(height: 8),
        const Text('The photo is the only thing you need. Everything else is optional.', style: TextStyle(color: SavourColors.muted, fontSize: 13, height: 1.5)),
        const SizedBox(height: 26),
        const _FieldLabel('NAME  ·  OPTIONAL'),
        const SizedBox(height: 9),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 90,
          decoration: const InputDecoration(hintText: 'A delicious bowl of…', counterText: ''),
        ),
        const SizedBox(height: 21),
        const _FieldLabel('A LITTLE NOTE  ·  OPTIONAL'),
        const SizedBox(height: 9),
        TextField(
          controller: _description,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 4,
          maxLength: 1200,
          decoration: const InputDecoration(hintText: 'What made this moment special?', alignLabelWithHint: true),
        ),
        const SizedBox(height: 17),
        const _FieldLabel('WHEN WAS THIS?'),
        const SizedBox(height: 9),
        InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: _chooseDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 18),
            decoration: BoxDecoration(color: SavourColors.cream, borderRadius: BorderRadius.circular(17), border: Border.all(color: SavourColors.line)),
            child: Row(children: [
              const Icon(Icons.event_outlined, color: SavourColors.terracotta),
              const SizedBox(width: 13),
              Expanded(child: Text(DateFormat('EEE, d MMM yyyy · h:mm a').format(_date), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              const Icon(Icons.edit_outlined, size: 18, color: SavourColors.muted),
            ]),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 55,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Icon(editing ? Icons.check_circle_outline : Icons.lock_outline),
            label: Text(_saving ? 'Safely storing…' : (editing ? 'Save changes' : 'Save to my private album')),
            style: FilledButton.styleFrom(backgroundColor: SavourColors.terracotta, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
        ),
        const SizedBox(height: 14),
        const Center(child: Text('Encrypted on your device · No account needed', style: TextStyle(color: SavourColors.muted, fontSize: 11))),
      ]),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(label, style: eyebrow(size: 10));
}
