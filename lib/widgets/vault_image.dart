import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/vault_repository.dart';
import '../theme/savour_theme.dart';

/// An encrypted image is decoded only for the displayed widget.
class VaultImage extends StatefulWidget {
  const VaultImage({
    super.key,
    required this.repository,
    required this.entryId,
    this.fullResolution = false,
    this.fit = BoxFit.cover,
    this.backgroundColor = SavourColors.sand,
  });

  final VaultRepository repository;
  final String entryId;
  final bool fullResolution;
  final BoxFit fit;
  final Color backgroundColor;

  @override
  State<VaultImage> createState() => _VaultImageState();
}

class _VaultImageState extends State<VaultImage> {
  late Future<Uint8List> _image;
  // An already-decrypted thumbnail, shown on the very first frame so the
  // widget never flashes empty while the future resolves.
  Uint8List? _cachedThumbnail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VaultImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entryId != widget.entryId ||
        oldWidget.fullResolution != widget.fullResolution) {
      _load();
    }
  }

  void _load() {
    _cachedThumbnail = widget.repository.cachedThumbnail(widget.entryId);
    _image = widget.fullResolution
        ? widget.repository.photo(widget.entryId)
        : widget.repository.thumbnail(widget.entryId);
  }

  Widget _memory(Uint8List bytes, {bool hideUntilDecoded = false}) => Image.memory(
    bytes,
    fit: widget.fit,
    width: double.infinity,
    height: double.infinity,
    gaplessPlayback: true,
    // Keeps the layer underneath visible until this image can be drawn.
    frameBuilder: hideUntilDecoded
        ? (context, child, frame, sync) =>
            sync || frame != null ? child : const SizedBox.shrink()
        : null,
    errorBuilder: (context, error, stackTrace) => ColoredBox(
      color: widget.backgroundColor,
      child: const Center(child: Icon(Icons.broken_image_outlined)),
    ),
  );

  Widget _loading() => ColoredBox(
    color: widget.backgroundColor,
    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
  );

  @override
  Widget build(BuildContext context) {
    final placeholder = _cachedThumbnail;
    return FutureBuilder<Uint8List>(
      future: _image,
      initialData: widget.fullResolution ? null : placeholder,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            color: widget.backgroundColor,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined, color: SavourColors.muted),
          );
        }
        if (!widget.fullResolution) {
          return snapshot.hasData ? _memory(snapshot.data!) : _loading();
        }
        // Full resolution: the cached thumbnail stays underneath until the
        // full photo has decoded on top of it.
        return ColoredBox(
          color: widget.backgroundColor,
          child: Stack(fit: StackFit.expand, children: [
            if (placeholder != null) _memory(placeholder)
            else if (!snapshot.hasData) const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            if (snapshot.hasData) _memory(snapshot.data!, hideUntilDecoded: true),
          ]),
        );
      },
    );
  }
}
