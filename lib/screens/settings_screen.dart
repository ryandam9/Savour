import 'dart:io';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../services/vault_repository.dart';
import '../theme/savour_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.repository, required this.onLockChanged});
  final VaultRepository repository;
  final Future<void> Function(bool) onLockChanged;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _lock = false;
  bool _changing = false;
  bool _supported = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await widget.repository.getAppLockEnabled();
    bool supported = false;
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows) {
      try { supported = await LocalAuthentication().isDeviceSupported(); } catch (_) { /* unsupported */ }
    }
    if (mounted) { setState(() { _lock = enabled; _supported = supported; }); }
  }

  Future<void> _toggleLock(bool enabled) async {
    if (_changing) { return; }
    setState(() => _changing = true);
    try {
      final authenticated = await LocalAuthentication().authenticate(
        localizedReason: enabled ? 'Protect your Savour album' : 'Confirm turning off album lock',
        persistAcrossBackgrounding: true,
      );
      if (!authenticated) { return; }
      await widget.repository.setAppLockEnabled(enabled);
      await widget.onLockChanged(enabled);
      if (mounted) { setState(() => _lock = enabled); }
    } catch (error) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not change lock setting: $error'))); }
    } finally {
      if (mounted) { setState(() => _changing = false); }
    }
  }

  Future<void> _deleteAll() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your entire album?'),
        content: const Text('Every stored photo and its notes will be permanently deleted. There is no backup or undo in this version.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete all', style: TextStyle(color: SavourColors.terracotta))),
        ],
      ),
    );
    if (approved != true || !mounted) { return; }
    try {
      await widget.repository.deleteEverything();
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your album has been cleared.'))); }
    } catch (error) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not clear album: $error'))); }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: ListenableBuilder(listenable: widget.repository, builder: (context, child) =>
      ListView(padding: const EdgeInsets.fromLTRB(24, 34, 24, 145), children: [
        Text('MADE FOR YOUR MEMORIES', style: eyebrow()),
        const SizedBox(height: 15),
        Text('Your little corner.', style: editorialTitle(size: 37)),
        const SizedBox(height: 10),
        const Text('A few things about your private album.', style: TextStyle(color: SavourColors.muted)),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 25),
          decoration: BoxDecoration(color: SavourColors.plum, borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            const Icon(Icons.photo_album_outlined, size: 42, color: Color(0xFFFFE2D4)),
            const SizedBox(width: 20),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${widget.repository.count}', style: const TextStyle(fontFamily: 'Cormorant Garamond', fontSize: 35, color: Colors.white, height: 1)),
              const SizedBox(height: 6),
              const Text('memories kept safely', style: TextStyle(color: Color(0xFFFFE2D4), fontSize: 12)),
            ]),
          ]),
        ),
        const SizedBox(height: 31),
        Text('PRIVACY & SECURITY', style: eyebrow()),
        const SizedBox(height: 12),
        _SettingsPanel(children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
            leading: const Icon(Icons.lock_outline_rounded, color: SavourColors.terracotta),
            title: const Text('App lock', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(_supported ? 'Use your device’s fingerprint, face, or passcode' : 'Device authentication unavailable here', style: const TextStyle(fontSize: 11, color: SavourColors.muted)),
            trailing: Switch(value: _lock, onChanged: _changing || !_supported ? null : _toggleLock),
          ),
          const Divider(height: 1, indent: 18, endIndent: 18),
          const ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 17, vertical: 7),
            leading: Icon(Icons.shield_outlined, color: SavourColors.terracotta),
            title: Text('Encrypted on this device', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Photos and journal details are protected using AES-256-GCM.', style: TextStyle(fontSize: 11, color: SavourColors.muted)),
          ),
        ]),
        const SizedBox(height: 29),
        Text('DANGER ZONE', style: eyebrow()),
        const SizedBox(height: 12),
        _SettingsPanel(children: [
          ListTile(
            onTap: widget.repository.count == 0 ? null : _deleteAll,
            leading: const Icon(Icons.delete_forever_outlined, color: SavourColors.terracotta),
            title: const Text('Delete all memories', style: TextStyle(fontWeight: FontWeight.w700, color: SavourColors.terracotta)),
            subtitle: const Text('Permanently erase photos and notes from this vault', style: TextStyle(color: SavourColors.muted, fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 31),
        const Center(child: Text('savour.  ·  VERSION 0.1.0', style: TextStyle(fontSize: 10, letterSpacing: 1.8, fontWeight: FontWeight.w800, color: SavourColors.muted))),
        const SizedBox(height: 8),
        const Center(child: Text('Good moments deserve a place to live.', style: TextStyle(fontFamily: 'Cormorant Garamond', color: SavourColors.muted, fontSize: 14))),
      ]),
    ),
  );
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: SavourColors.cream, borderRadius: BorderRadius.circular(18), border: Border.all(color: SavourColors.line)),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}
