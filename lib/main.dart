import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';

import 'screens/album_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/editor_screen.dart';
import 'screens/settings_screen.dart';
import 'services/vault_repository.dart';
import 'theme/savour_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SavourApp());
}

class SavourApp extends StatefulWidget {
  const SavourApp({super.key});

  @override
  State<SavourApp> createState() => _SavourAppState();
}

class _SavourAppState extends State<SavourApp> with WidgetsBindingObserver {
  final _repository = VaultRepository();
  final _auth = LocalAuthentication();
  bool _loading = true;
  bool _lockEnabled = false;
  bool _unlocked = false;
  bool _authenticating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialise();
  }

  Future<void> _initialise() async {
    try {
      await _repository.initialise();
      final locked = await _repository.getAppLockEnabled();
      if (!mounted) return;
      setState(() {
        _lockEnabled = locked;
        _unlocked = !locked;
        _error = null;
        _loading = false;
      });
      if (locked) await _unlock();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_lockEnabled || _loading) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (mounted) setState(() => _unlocked = false);
    } else if (state == AppLifecycleState.resumed && !_authenticating && !_unlocked) {
      _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_authenticating || !_lockEnabled) return;
    _authenticating = true;
    try {
      final accepted = await _auth.authenticate(
        localizedReason: 'Unlock your private food journal',
        persistAcrossBackgrounding: true,
      );
      if (mounted) setState(() => _unlocked = accepted);
    } catch (_) {
      // Stay locked. A failed or unsupported system prompt must not bypass it.
      if (mounted) setState(() => _unlocked = false);
    } finally {
      _authenticating = false;
    }
  }

  Future<void> _lockChanged(bool enabled) async {
    if (!mounted) return;
    setState(() {
      _lockEnabled = enabled;
      _unlocked = true; // Already authenticated when enabling the option.
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Savour · Your food journal',
    debugShowCheckedModeBanner: false,
    theme: buildSavourTheme(),
    // The privacy overlay is ABOVE the Navigator. It also covers editor and
    // photo-detail routes when the app is backgrounded, without destroying them.
    builder: (context, navigator) => Stack(children: [
      navigator ?? const SizedBox.shrink(),
      if (!_loading && _error == null && !_unlocked)
        Positioned.fill(child: _LockedScreen(onUnlock: _unlock)),
    ]),
    home: _loading
        ? const _BootScreen()
        : _error != null
            ? _VaultErrorScreen(message: _error!)
            : HomeShell(repository: _repository, onLockChanged: _lockChanged),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.repository,
    required this.onLockChanged,
  });
  final VaultRepository repository;
  final Future<void> Function(bool) onLockChanged;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  bool _importing = false;

  Future<void> _capture(ImageSource source) async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 4096,
        imageQuality: 95,
        requestFullMetadata: false,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      await _cleanPickerCopy(picked);
      if (!mounted) return;
      if (bytes.isEmpty) throw const VaultException('This image is empty.');
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => EditorScreen(repository: widget.repository, newPhoto: bytes),
        ),
      );
      if (saved == true && mounted) setState(() => _tab = 0);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open photo: $error')),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _cleanPickerCopy(XFile picked) async {
    // Delete ONLY private picker cache copies, never an image from the user's
    // actual gallery. The source photo in Photos/Gallery is untouched.
    try {
      final temp = await getTemporaryDirectory();
      final cacheRoot = '${temp.absolute.path}${Platform.pathSeparator}';
      if (File(picked.path).absolute.path.startsWith(cacheRoot)) {
        await File(picked.path).delete();
      }
    } catch (_) {
      // Different platforms place picker cache files in different locations.
    }
  }

  void _showAddOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: SavourColors.cream,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Save a delicious moment', style: editorialTitle(size: 27)),
              const SizedBox(height: 10),
              const Text(
                'Just a photo is enough. The rest is up to you.',
                style: TextStyle(color: SavourColors.muted),
              ),
              const SizedBox(height: 23),
              if (Platform.isAndroid || Platform.isIOS)
                _PhotoSourceTile(
                  icon: Icons.photo_camera_outlined,
                  title: 'Take a photo',
                  subtitle: 'Capture what’s on your plate',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _capture(ImageSource.camera);
                  },
                ),
              _PhotoSourceTile(
                icon: Icons.photo_library_outlined,
                title: 'Choose from gallery',
                subtitle: 'Use a photo you already have',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _capture(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      AlbumScreen(repository: widget.repository, onAdd: _showAddOptions),
      CalendarScreen(repository: widget.repository),
      SettingsScreen(repository: widget.repository, onLockChanged: widget.onLockChanged),
    ];
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Semantics(
        label: 'Add food photo',
        button: true,
        child: FloatingActionButton(
          heroTag: 'capture-food',
          onPressed: _importing ? null : _showAddOptions,
          backgroundColor: SavourColors.terracotta,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: const CircleBorder(),
          child: _importing
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.add_a_photo_outlined, size: 25),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: SavourColors.cream,
        surfaceTintColor: Colors.transparent,
        height: 74,
        padding: EdgeInsets.zero,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          children: [
            Expanded(child: _NavItem(icon: Icons.photo_library_outlined, selectedIcon: Icons.photo_library_rounded, title: 'Album', selected: _tab == 0, onTap: () => setState(() => _tab = 0))),
            Expanded(child: _NavItem(icon: Icons.calendar_month_outlined, selectedIcon: Icons.calendar_month_rounded, title: 'Calendar', selected: _tab == 1, onTap: () => setState(() => _tab = 1))),
            const SizedBox(width: 65),
            Expanded(child: _NavItem(icon: Icons.tune_outlined, selectedIcon: Icons.tune_rounded, title: 'Settings', selected: _tab == 2, onTap: () => setState(() => _tab = 2))),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.selectedIcon, required this.title, required this.selected, required this.onTap});
  final IconData icon;
  final IconData selectedIcon;
  final String title;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(selected ? selectedIcon : icon, color: selected ? SavourColors.terracotta : SavourColors.muted, size: 23),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 10, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, color: selected ? SavourColors.terracotta : SavourColors.muted)),
      ],
    ),
  );
}

class _PhotoSourceTile extends StatelessWidget {
  const _PhotoSourceTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 6),
    leading: Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(color: SavourColors.paleRose, borderRadius: BorderRadius.circular(16)),
      child: Icon(icon, color: SavourColors.terracotta),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle, style: const TextStyle(color: SavourColors.muted, fontSize: 12)),
    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: SavourColors.muted),
    onTap: onTap,
  );
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.restaurant_menu_rounded, color: SavourColors.terracotta, size: 48),
          SizedBox(height: 20),
          Text('savour.', style: TextStyle(fontFamily: 'serif', fontSize: 43, fontWeight: FontWeight.w600, color: SavourColors.ink)),
          SizedBox(height: 28),
          CircularProgressIndicator(strokeWidth: 2),
        ],
      ),
    ),
  );
}

class _LockedScreen extends StatelessWidget {
  const _LockedScreen({required this.onUnlock});
  final VoidCallback onUnlock;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(34),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline_rounded, size: 64, color: SavourColors.terracotta),
            const SizedBox(height: 26),
            Text('For your eyes only.', style: editorialTitle(size: 35), textAlign: TextAlign.center),
            const SizedBox(height: 13),
            const Text('Your food memories are safely tucked away.', style: TextStyle(color: SavourColors.muted), textAlign: TextAlign.center),
            const SizedBox(height: 35),
            FilledButton.icon(onPressed: onUnlock, icon: const Icon(Icons.fingerprint), label: const Text('Unlock Savour')),
          ]),
        ),
      ),
    ),
  );
}

class _VaultErrorScreen extends StatelessWidget {
  const _VaultErrorScreen({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.gpp_bad_outlined, color: SavourColors.terracotta, size: 52),
            const SizedBox(height: 20),
            Text('Your vault is protected.', style: editorialTitle(size: 31), textAlign: TextAlign.center),
            const SizedBox(height: 18),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 16),
            const Text('Nothing has been reset or deleted.', style: TextStyle(color: SavourColors.muted)),
          ]),
        ),
      ),
    ),
  );
}
