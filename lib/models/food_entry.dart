class FoodEntry {
  const FoodEntry({
    required this.id,
    required this.eatenAt,
    required this.createdAt,
    this.name = '',
    this.description = '',
    this.isFavourite = false,
  });

  final String id;
  final DateTime eatenAt;
  final DateTime createdAt;
  final String name;
  final String description;
  final bool isFavourite;

  String get displayName => name.trim().isEmpty ? 'Untitled moment' : name.trim();

  FoodEntry copyWith({
    DateTime? eatenAt,
    String? name,
    String? description,
    bool? isFavourite,
  }) {
    return FoodEntry(
      id: id,
      eatenAt: eatenAt ?? this.eatenAt,
      createdAt: createdAt,
      name: name ?? this.name,
      description: description ?? this.description,
      isFavourite: isFavourite ?? this.isFavourite,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'eatenAt': eatenAt.toUtc().toIso8601String(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'name': name,
    'description': description,
    'isFavourite': isFavourite,
  };

  factory FoodEntry.fromJson(Map<String, dynamic> json) => FoodEntry(
    id: json['id'] as String,
    eatenAt: DateTime.parse(json['eatenAt'] as String).toLocal(),
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    isFavourite: json['isFavourite'] as bool? ?? false,
  );
}
