import 'package:flutter_test/flutter_test.dart';
import 'package:savour/models/food_entry.dart';

void main() {
  test('empty food names are allowed', () {
    final now = DateTime(2026, 10, 31, 12, 30);
    final entry = FoodEntry(id: '1', eatenAt: now, createdAt: now);
    expect(entry.name, isEmpty);
    expect(entry.description, isEmpty);
    expect(entry.displayName, 'Untitled moment');
  });

  test('journal JSON round trip preserves the meal, date and favourite', () {
    final when = DateTime(2026, 5, 19, 18, 42);
    final original = FoodEntry(
      id: 'test-photo-2',
      eatenAt: when,
      createdAt: DateTime(2026, 5, 20),
      name: 'Vegetable pulao',
      description: 'Made at home.',
      isFavourite: true,
    );
    final restored = FoodEntry.fromJson(original.toJson());
    expect(restored.id, original.id);
    expect(restored.eatenAt, original.eatenAt);
    expect(restored.createdAt, original.createdAt);
    expect(restored.name, 'Vegetable pulao');
    expect(restored.description, 'Made at home.');
    expect(restored.isFavourite, isTrue);
  });

  test('copyWith retains fields not being changed', () {
    final now = DateTime.now();
    final entry = FoodEntry(id: '3', eatenAt: now, createdAt: now);
    final newEntry = entry.copyWith(isFavourite: true, name: 'Soup');
    expect(newEntry.id, '3');
    expect(newEntry.eatenAt, now);
    expect(newEntry.isFavourite, true);
    expect(newEntry.name, 'Soup');
    expect(entry.isFavourite, false);
  });
}
