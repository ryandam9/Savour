import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savour/models/food_entry.dart';
import 'package:savour/screens/photo_viewer_screen.dart';
import 'package:savour/services/vault_repository.dart';

// A 1x1 PNG: the viewer must request full-resolution photos, not thumbnails.
final _samplePhoto = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aN5sAAAAASUVORK5CYII=',
);

class _ViewerVault extends VaultRepository {
  _ViewerVault()
      : _items = [
          FoodEntry(
            id: 'first',
            name: 'Breakfast',
            eatenAt: DateTime(2026, 10, 31),
            createdAt: DateTime(2026, 10, 31),
          ),
          FoodEntry(
            id: 'second',
            name: 'Dinner',
            eatenAt: DateTime(2026, 10, 30),
            createdAt: DateTime(2026, 10, 30),
          ),
        ];

  final List<FoodEntry> _items;
  int fullImageReads = 0;

  @override
  List<FoodEntry> get entries => _items;

  @override
  Future<Uint8List> photo(String id) async {
    fullImageReads++;
    return _samplePhoto;
  }

  @override
  Future<Uint8List> thumbnail(String id) async =>
      throw StateError('The viewer must never load a thumbnail');
}

void main() {
  testWidgets('opens the original without cropping and allows swiping', (tester) async {
    final vault = _ViewerVault();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => PhotoViewerScreen(
            repository: vault,
            entryIds: const ['first', 'second'],
            initialId: 'first',
          ),
        )),
        child: const Text('Open viewer'),
      ))),
    ));
    await tester.tap(find.text('Open viewer'));
    await tester.pumpAndSettle();
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(vault.fullImageReads, greaterThan(0));
    expect(tester.widget<Image>(find.byType(Image).first).fit, BoxFit.contain);

    await tester.drag(find.byType(PageView), const Offset(-650, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);

    await tester.tapAt(const Offset(300, 300));
    // Single taps wait for the double-tap gesture deadline.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsNothing);
    await tester.tapAt(const Offset(300, 300));
    // Single taps wait for the double-tap gesture deadline.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Close full-screen photo'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewerScreen), findsNothing);
    expect(find.text('Open viewer'), findsOneWidget);
  });

  testWidgets('double-tap zooms in and out', (tester) async {
    final vault = _ViewerVault();
    await tester.pumpWidget(MaterialApp(
      home: PhotoViewerScreen(
        repository: vault,
        entryIds: const ['first'],
        initialId: 'first',
      ),
    ));
    await tester.pumpAndSettle();
    final image = find.byType(InteractiveViewer).first;
    await tester.tapAt(const Offset(150, 220));
    await tester.pump(const Duration(milliseconds: 65));
    await tester.tapAt(const Offset(150, 220));
    await tester.pumpAndSettle();
    expect(
      tester.widget<InteractiveViewer>(image).transformationController!
          .value.getMaxScaleOnAxis(),
      greaterThan(2),
    );
    await tester.tapAt(const Offset(150, 220));
    await tester.pump(const Duration(milliseconds: 65));
    await tester.tapAt(const Offset(150, 220));
    await tester.pumpAndSettle();
    expect(
      tester.widget<InteractiveViewer>(image).transformationController!
          .value.getMaxScaleOnAxis(),
      closeTo(1, 0.01),
    );
  });
}
