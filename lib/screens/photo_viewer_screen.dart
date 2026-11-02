import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

  /// A see-through route, so the screen underneath shows while the photo is
  /// dragged down to close.
  static Route<void> route({
    required VaultRepository repository,
    required List<String> entryIds,
    required String initialId,
  }) => PageRouteBuilder<void>(
    opaque: false,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) => PhotoViewerScreen(
      repository: repository,
      entryIds: entryIds,
      initialId: initialId,
    ),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen>
    with TickerProviderStateMixin {
  /// Width of one filmstrip slot (thumbnail plus gap).
  static const _thumbExtent = 50.0;
  /// How far the photo must be dragged to close or open details.
  static const _dismissDistance = 110.0;
  static const _flingVelocity = 800.0;

  late final List<String> _ids;
  late final PageController _pages;
  late final ScrollController _strip;
  late final AnimationController _chrome;
  late final AnimationController _snapBack;
  final _drag = ValueNotifier<double>(0);
  late int _index;
  bool _zoomed = false;
  // True while the filmstrip, not the photo, is driving navigation.
  bool _stripInControl = false;

  @override
  void initState() {
    super.initState();
    _ids = List<String>.of(widget.entryIds);
    final initialIndex = _ids.indexOf(widget.initialId);
    _index = initialIndex < 0 ? 0 : initialIndex;
    _pages = PageController(initialPage: _index)..addListener(_followPages);
    _strip = ScrollController(initialScrollOffset: _index * _thumbExtent);
    _chrome = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: 1,
    );
    _snapBack = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    _strip.dispose();
    _chrome.dispose();
    _snapBack.dispose();
    _drag.dispose();
    super.dispose();
  }

  /// The fractional page, which moves smoothly while swiping.
  double get _page => _pages.hasClients && _pages.position.haveDimensions
      ? _pages.page ?? _index.toDouble()
      : _index.toDouble();

  /// Keeps the filmstrip centred under the photo while it is swiped.
  void _followPages() {
    if (_stripInControl || !_strip.hasClients) return;
    final max = _strip.position.maxScrollExtent;
    _strip.jumpTo((_page * _thumbExtent).clamp(0.0, max));
  }

  void _goTo(int page) {
    if (page == _index) return;
    if ((page - _index).abs() == 1) {
      _pages.animateToPage(page,
          duration: const Duration(milliseconds: 340), curve: Curves.easeOutCubic);
      return;
    }
    // Swiping across many photos would decrypt every one in between.
    _stripInControl = true;
    _pages.jumpToPage(page);
    _strip
        .animateTo(page * _thumbExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic)
        .whenComplete(() => _stripInControl = false);
  }

  bool _onStripScroll(ScrollNotification notification) {
    if (notification is UserScrollNotification) {
      if (notification.direction != ScrollDirection.idle) {
        _stripInControl = true;
      } else if (_stripInControl) {
        _stripInControl = false;
        // Settle on the thumbnail that is now showing.
        Future.microtask(() {
          if (!mounted || !_strip.hasClients) return;
          _strip.animateTo(_index * _thumbExtent,
              duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        });
      }
    } else if (_stripInControl && notification is ScrollUpdateNotification) {
      final page = (notification.metrics.pixels / _thumbExtent)
          .round()
          .clamp(0, _ids.length - 1);
      if (page != _index) _pages.jumpToPage(page);
    }
    return false;
  }

  void _toggleChrome() {
    final showing = _chrome.status == AnimationStatus.forward ||
        _chrome.status == AnimationStatus.completed;
    showing ? _chrome.reverse() : _chrome.forward();
  }

  void _openDetails() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MomentScreen(repository: widget.repository, id: _ids[_index]),
    ));
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _snapBack.stop();
    _drag.value += details.delta.dy;
  }

  void _onDragEnd(DragEndDetails details) {
    final offset = _drag.value;
    final velocity = details.primaryVelocity ?? 0;
    if (offset > _dismissDistance || velocity > _flingVelocity) {
      Navigator.of(context).maybePop();
      return;
    }
    final openDetails = offset < -_dismissDistance || velocity < -_flingVelocity;
    _resetDrag();
    if (openDetails) _openDetails();
  }

  void _resetDrag() {
    final start = _drag.value;
    if (start == 0) return;
    final curve = CurvedAnimation(parent: _snapBack, curve: Curves.easeOutBack);
    void tick() => _drag.value = start * (1 - curve.value);
    _snapBack
      ..removeListener(tick)
      ..addListener(tick)
      ..forward(from: 0).whenComplete(() {
        _snapBack.removeListener(tick);
        curve.dispose();
      });
  }

  Widget _buildPages() => PageView.builder(
    controller: _pages,
    physics: _zoomed
        ? const NeverScrollableScrollPhysics()
        : const PageScrollPhysics(parent: BouncingScrollPhysics()),
    itemCount: _ids.length,
    onPageChanged: (page) {
      HapticFeedback.selectionClick();
      setState(() {
        _index = page;
        _zoomed = false;
      });
    },
    itemBuilder: (context, page) => AnimatedBuilder(
      animation: _pages,
      // The photo leaving the screen recedes, so pages feel layered.
      builder: (context, child) {
        final distance = (_page - page).abs().clamp(0.0, 1.0);
        final eased = Curves.easeOut.transform(distance);
        return Opacity(
          opacity: 1 - 0.5 * eased,
          child: Transform.scale(scale: 1 - 0.14 * eased, child: child),
        );
      },
      child: _ZoomablePhoto(
        key: ValueKey(_ids[page]),
        repository: widget.repository,
        entryId: _ids[page],
        onTap: _toggleChrome,
        onZoomChanged: (zoomed) {
          if (page == _index && _zoomed != zoomed) {
            setState(() => _zoomed = zoomed);
          }
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.repository,
    builder: (context, child) {
      // Re-reading metadata ensures edits and favourites appear immediately.
      final entries = <String, FoodEntry>{
        for (final entry in widget.repository.entries) entry.id: entry,
      };
      final current = entries[_ids[_index]];
      final pages = _buildPages();
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedBuilder(
          animation: Listenable.merge([_drag, _chrome]),
          child: pages,
          builder: (context, pages) {
            final offset = _drag.value;
            final height = MediaQuery.sizeOf(context).height;
            final pull = (offset.abs() / (height * 0.4)).clamp(0.0, 1.0);
            final down = offset > 0 ? pull : 0.0;
            final chrome = Curves.easeOutCubic.transform(_chrome.value) *
                (1 - pull * 3).clamp(0.0, 1.0);
            return Stack(children: [
              Positioned.fill(
                child: ColoredBox(color: Colors.black.withValues(alpha: 1 - 0.9 * down)),
              ),
              Positioned.fill(
                child: RawGestureDetector(
                  gestures: {
                    if (!_zoomed)
                      _SingleFingerVerticalDrag:
                          GestureRecognizerFactoryWithHandlers<_SingleFingerVerticalDrag>(
                        _SingleFingerVerticalDrag.new,
                        (recognizer) => recognizer
                          ..onUpdate = _onDragUpdate
                          ..onEnd = _onDragEnd
                          ..onCancel = _resetDrag,
                      ),
                  },
                  child: Transform.translate(
                    offset: Offset(0, offset),
                    child: Transform.scale(scale: 1 - 0.25 * down, child: pages),
                  ),
                ),
              ),
              if (!_chrome.isDismissed) ...[
                Positioned(
                  left: 0, right: 0, top: 0,
                  child: _ChromeFade(
                    value: chrome,
                    slideFrom: -18,
                    child: _topBar(context),
                  ),
                ),
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: _ChromeFade(
                    value: chrome,
                    slideFrom: 22,
                    child: _bottomBar(current),
                  ),
                ),
              ],
            ]);
          },
        ),
      );
    },
  );

  Widget _topBar(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x88000000), Color(0x00000000)],
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 16, 18),
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x99000000),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_index + 1} / ${_ids.length}',
                style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ]),
      ),
    ),
  );

  Widget _bottomBar(FoodEntry? current) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xDD000000), Color(0x00000000)],
      ),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 40, 0, 14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 16, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: _Caption(entry: current)),
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
          if (_ids.length > 1) ...[
            const SizedBox(height: 16),
            _filmstrip(),
          ],
        ]),
      ),
    ),
  );

  Widget _filmstrip() => SizedBox(
    height: 64,
    child: LayoutBuilder(builder: (context, constraints) {
      // Side padding lets the first and last thumbnails reach the centre.
      final side = (constraints.maxWidth - _thumbExtent) / 2;
      return NotificationListener<ScrollNotification>(
        onNotification: _onStripScroll,
        child: ListView.builder(
          controller: _strip,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: side),
          itemExtent: _thumbExtent,
          itemCount: _ids.length,
          itemBuilder: (context, i) => GestureDetector(
            onTap: () => _goTo(i),
            child: AnimatedBuilder(
              animation: _pages,
              builder: (context, child) {
                final focus = 1 - (_page - i).abs().clamp(0.0, 1.0);
                return Center(
                  child: Opacity(
                    opacity: 0.45 + 0.55 * focus,
                    child: Transform.scale(
                      scale: 0.82 + 0.18 * focus,
                      child: Container(
                        width: _thumbExtent - 8,
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: focus),
                            width: 2,
                          ),
                        ),
                        child: child,
                      ),
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: VaultImage(
                  repository: widget.repository,
                  entryId: _ids[i],
                  backgroundColor: const Color(0xFF2A2522),
                ),
              ),
            ),
          ),
        ),
      );
    }),
  );
}

/// Fades and slides the viewer controls in and out.
class _ChromeFade extends StatelessWidget {
  const _ChromeFade({required this.value, required this.slideFrom, required this.child});
  final double value;
  final double slideFrom;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: value < 0.5,
    child: Opacity(
      opacity: value,
      child: Transform.translate(offset: Offset(0, slideFrom * (1 - value)), child: child),
    ),
  );
}

/// The meal name and time, cross-fading as photos change.
class _Caption extends StatelessWidget {
  const _Caption({required this.entry});
  final FoodEntry? entry;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 300),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.bottomLeft,
      children: [...previous, ?current],
    ),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(animation),
        child: child,
      ),
    ),
    child: Column(
      key: ValueKey(entry?.id),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(entry?.displayName ?? 'Photo',
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white, fontSize: 23,
            fontFamily: 'Cormorant Garamond', fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        if (entry != null)
          Text(DateFormat('d MMMM yyyy · h:mm a').format(entry!.eatenAt),
            style: const TextStyle(color: Color(0xFFE7DDD5), fontSize: 12),
          ),
        const SizedBox(height: 9),
        const Text('Swipe down to close  ·  up for details',
          style: TextStyle(color: Color(0xFFCEC4BA), fontSize: 11),
        ),
      ],
    ),
  );
}

/// A vertical drag that steps aside as soon as a second finger lands, so
/// pinch-to-zoom keeps working.
class _SingleFingerVerticalDrag extends VerticalDragGestureRecognizer {
  final _pointers = <int>{};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _pointers.add(event.pointer);
    super.addAllowedPointer(event);
    if (_pointers.length > 1) resolve(GestureDisposition.rejected);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointers.clear();
    super.didStopTrackingLastPointer(pointer);
  }
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

class _ZoomablePhotoState extends State<_ZoomablePhoto>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _zoomAnimation;
  Animation<Matrix4>? _zoomTween;
  TapDownDetails? _doubleTap;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_handleTransform);
    _zoomAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(() {
        final tween = _zoomTween;
        if (tween != null) _transform.value = tween.value;
      });
  }

  void _handleTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (_zoomed != zoomed) {
      _zoomed = zoomed;
      widget.onZoomChanged(zoomed);
      setState(() {});
    }
  }

  void _toggleZoom() {
    final Matrix4 target;
    if (_zoomed) {
      target = Matrix4.identity();
    } else {
      final point = _doubleTap?.localPosition ?? Offset.zero;
      const scale = 2.5;
      target = Matrix4.identity()
        ..setEntry(0, 0, scale)
        ..setEntry(1, 1, scale)
        ..setEntry(0, 3, -point.dx * (scale - 1))
        ..setEntry(1, 3, -point.dy * (scale - 1));
    }
    _zoomTween = Matrix4Tween(begin: _transform.value.clone(), end: target)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(_zoomAnimation);
    _zoomAnimation.forward(from: 0);
  }

  @override
  void dispose() {
    _zoomAnimation.dispose();
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
            onInteractionStart: (_) => _zoomAnimation.stop(),
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
