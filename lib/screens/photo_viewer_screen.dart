import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/food_entry.dart';
import '../services/vault_repository.dart';
import '../widgets/vault_image.dart';
import 'moment_screen.dart';

/// A distraction-free viewer. The originals are decrypted only on demand and
/// never exported to the device's public photo library.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.repository,
    required this.entryIds,
    required this.initialId,
  }) : assert(entryIds.length > 0);

  final VaultRepository repository;
  /// IDs in the order currently visible in the album or calendar.
  final List<String> entryIds;
  final String initialId;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final List<String> _ids;
  late final PageController _pages;
  late int _index;
  bool _controlsVisible = true;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _ids = List<String>.of(widget.entryIds);
    final initialIndex = _ids.indexOf(widget.initialId);
    _index = initialIndex < 0 ? 0 : initialIndex;
    _pages = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _openDetails() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MomentScreen(repository: widget.repository, id: _ids[_index]),
    ));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.repository,
    builder: (context, child) {
      // Re-reading metadata ensures edits and favourites appear immediately.
      final entries = <String, FoodEntry>{
        for (final entry in widget.repository.entries) entry.id: entry,
      };
      final current = entries[_ids[_index]];
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pages,
              physics: _zoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              itemCount: _ids.length,
              onPageChanged: (page) => setState(() {
                _index = page;
                _zoomed = false;
              }),
              itemBuilder: (context, page) => _ZoomablePhoto(
                key: ValueKey(_ids[page]),
                repository: widget.repository,
                entryId: _ids[page],
                onTap: () => setState(() => _controlsVisible = !_controlsVisible),
                onZoomChanged: (zoomed) {
                  if (page == _index && _zoomed != zoomed) {
                    setState(() => _zoomed = zoomed);
                  }
                },
              ),
            ),
          ),
          if (_controlsVisible) ...[
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 9, 16, 12),
                  child: Row(children: [
                    IconButton.filledTonal(
                      tooltip: 'Close full-screen photo',
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0x99000000),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const Spacer(),
                    Semantics(
                      label: 'Photo ${_index + 1} of ${_ids.length}',
                      child: Text(
                        '${_index + 1} / ${_ids.length}',
                        style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600,
                          fontSize: 14, shadows: [Shadow(blurRadius: 9)],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xCC000000), Color(0x00000000)],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 36, 16, 18),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(current?.displayName ?? 'Photo',
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white, fontSize: 23,
                              fontFamily: 'Cormorant Garamond', fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 5),
                          if (current != null)
                            Text(DateFormat('d MMMM yyyy · h:mm a').format(current.eatenAt),
                              style: const TextStyle(color: Color(0xFFE7DDD5), fontSize: 12),
                            ),
                          const SizedBox(height: 13),
                          const Text('Pinch to zoom  ·  Double-tap  ·  Swipe',
                            style: TextStyle(color: Color(0xFFCEC4BA), fontSize: 11),
                          ),
                        ],
                      )),
                      if (current != null)
                        IconButton.filledTonal(
                          tooltip: 'View meal details',
                          onPressed: _openDetails,
                          icon: const Icon(Icons.info_outline_rounded),
                          style: IconButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: const Color(0x99000000),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ]),
      );
    },
  );
}

class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({
    super.key,
    required this.repository,
    required this.entryId,
    required this.onTap,
    required this.onZoomChanged,
  });

  final VaultRepository repository;
  final String entryId;
  final VoidCallback onTap;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final _transform = TransformationController();
  TapDownDetails? _doubleTap;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_handleTransform);
  }

  void _handleTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (_zoomed != zoomed) {
      _zoomed = zoomed;
      widget.onZoomChanged(zoomed);
    }
  }

  void _toggleZoom() {
    if (_zoomed) {
      _transform.value = Matrix4.identity();
    } else {
      final point = _doubleTap?.localPosition ?? Offset.zero;
      const scale = 2.5;
      final matrix = Matrix4.identity()
        ..setEntry(0, 0, scale)
        ..setEntry(1, 1, scale)
        ..setEntry(0, 3, -point.dx * (scale - 1))
        ..setEntry(1, 3, -point.dy * (scale - 1));
      _transform.value = matrix;
    }
  }

  @override
  void dispose() {
    _transform.removeListener(_handleTransform);
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const Key('photo-viewer-gesture'),
    behavior: HitTestBehavior.opaque,
    onTap: widget.onTap,
    onDoubleTapDown: (details) => _doubleTap = details,
    onDoubleTap: _toggleZoom,
    child: Center(
      child: Hero(
        tag: 'savour-${widget.entryId}',
        child: ClipRect(
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: 1,
            maxScale: 5,
            panEnabled: _zoomed,
            scaleEnabled: true,
            child: SizedBox.expand(
              child: VaultImage(
                repository: widget.repository,
                entryId: widget.entryId,
                fullResolution: true,
                fit: BoxFit.contain,
                // Transparent: during the Hero flight the image is drawn above
                // the whole page, and a black box would hide the controls.
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
