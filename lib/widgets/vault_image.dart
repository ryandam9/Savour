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
  });

  final VaultRepository repository;
  final String entryId;
  final bool fullResolution;
  final BoxFit fit;

  @override
  State<VaultImage> createState() => _VaultImageState();
}

class _VaultImageState extends State<VaultImage> {
  late Future<Uint8List> _image;

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
    _image = widget.fullResolution
        ? widget.repository.photo(widget.entryId)
        : widget.repository.thumbnail(widget.entryId);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _image,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Container(
          color: SavourColors.sand,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: SavourColors.muted),
        );
      }
      if (!snapshot.hasData) {
        return const ColoredBox(
          color: SavourColors.sand,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }
      return Image.memory(
        snapshot.data!,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            const ColoredBox(
              color: SavourColors.sand,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
      );
    },
  );
}
