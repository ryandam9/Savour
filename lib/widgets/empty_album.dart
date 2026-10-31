import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/savour_theme.dart';

class EmptyAlbum extends StatelessWidget {
  const EmptyAlbum({super.key, required this.onAdd, this.isFiltered = false});
  final VoidCallback onAdd;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 250,
            height: 215,
            child: CustomPaint(painter: _AlbumIllustration()),
          ),
          const SizedBox(height: 23),
          Text(
            isFiltered ? 'Nothing here just yet.' : 'Every plate has a story.',
            textAlign: TextAlign.center,
            style: editorialTitle(size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            isFiltered
                ? 'Try another search or revisit your full album.'
                : 'The first delicious memory is just a photo away. Your little collection starts here.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: SavourColors.muted, height: 1.6, fontSize: 14),
          ),
          if (!isFiltered) ...[
            const SizedBox(height: 23),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: const Text('Add your first moment'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 17),
                backgroundColor: SavourColors.terracotta,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _AlbumIllustration extends CustomPainter {
  const _AlbumIllustration();

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()..color = const Color(0x220F0906);
    final paper = Paint()..color = SavourColors.cream;
    final ochre = Paint()..color = const Color(0xFFE5B77D);
    final rose = Paint()..color = const Color(0xFFE3A499);
    final berry = Paint()..color = SavourColors.plum;
    final green = Paint()..color = const Color(0xFF829A81);

    canvas.save();
    canvas.translate(25, 16);
    canvas.rotate(-0.14);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 5, 150, 179), const Radius.circular(11)), shadow);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 150, 179), const Radius.circular(11)), paper);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(9, 9, 132, 130), const Radius.circular(7)), rose);
    canvas.drawCircle(const Offset(75, 75), 48, Paint()..color = const Color(0xFFF9E8CB));
    canvas.drawCircle(const Offset(75, 75), 39, ochre);
    for (var i = 0; i < 9; i++) {
      final angle = i * math.pi * 2 / 9;
      canvas.drawCircle(Offset(75 + 26 * math.cos(angle), 75 + 26 * math.sin(angle)), 6, berry);
    }
    canvas.restore();

    canvas.save();
    canvas.translate(111, 47);
    canvas.rotate(0.16);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(2, 4, 133, 156), const Radius.circular(10)), shadow);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 133, 156), const Radius.circular(10)), paper);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(8, 8, 117, 111), const Radius.circular(6)), const Paint()..color = Color(0xFFE9D8C1));
    canvas.drawOval(const Rect.fromLTWH(24, 27, 85, 79), const Paint()..color = Color(0xFFF9F1E6));
    canvas.drawOval(const Rect.fromLTWH(32, 33, 68, 65), const Paint()..color = Color(0xFFD38D64));
    for (var i = 0; i < 6; i++) {
      canvas.drawOval(Rect.fromLTWH(35 + (i % 3) * 21, 44 + (i ~/ 3) * 26, 12, 24), green);
    }
    canvas.restore();
    final spark = Paint()..color = SavourColors.terracotta..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(20, 162), const Offset(10, 171), spark);
    canvas.drawLine(const Offset(23, 172), const Offset(22, 184), spark);
    canvas.drawLine(const Offset(33, 174), const Offset(43, 180), spark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
