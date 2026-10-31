import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savour/theme/savour_theme.dart';

void main() {
  test('DM Sans is the app-wide interface font', () {
    final theme = buildSavourTheme();
    expect(theme.textTheme.bodyMedium?.fontFamily, 'DM Sans');
    expect(theme.textTheme.labelLarge?.fontFamily, 'DM Sans');
    expect(theme.textTheme.titleMedium?.fontFamily, 'DM Sans');
    expect(eyebrow().fontFamily, 'DM Sans');
  });

  test('Cormorant Garamond is used for editorial headings', () {
    expect(editorialTitle().fontFamily, 'Cormorant Garamond');
    expect(savourSerif(size: 24).fontFamily, 'Cormorant Garamond');
    expect(savourSerif(size: 24, color: Colors.white).color, Colors.white);
  });
}
