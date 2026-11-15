import 'package:flutter/foundation.dart';

/// One item of the space food database (assets/data/foods.json).
///
/// Values are APPROXIMATE and only inspired by ISS menu items — they are not
/// official NASA nutrition data (the UI says so under the food list).
@immutable
class Food {
  const Food({
    required this.id,
    required this.name,
    required this.category,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.sodiumMg,
    required this.potassiumMg,
    required this.tags,
  });

  final String id;
  final String name;

  /// Breakfast, Main, Starter, Snack, Fruit, Drink.
  final String category;

  /// Energy of one full serving.
  final int kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final int sodiumMg;
  final int potassiumMg;

  /// Nutrition tags (high_protein, hydrating, …) used by the recommender.
  final List<String> tags;

  bool hasTag(String tag) => tags.contains(tag);

  Food copyWith({
    String? id,
    String? name,
    String? category,
    int? kcal,
    double? proteinG,
    double? carbsG,
    double? fatG,
    int? sodiumMg,
    int? potassiumMg,
    List<String>? tags,
  }) {
    return Food(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      kcal: kcal ?? this.kcal,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      potassiumMg: potassiumMg ?? this.potassiumMg,
      tags: tags ?? this.tags,
    );
  }

  factory Food.fromJson(Map<String, dynamic> json) {
    return Food(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      kcal: (json['kcal'] as num).round(),
      proteinG: (json['protein_g'] as num).toDouble(),
      carbsG: (json['carbs_g'] as num).toDouble(),
      fatG: (json['fat_g'] as num).toDouble(),
      sodiumMg: (json['sodium_mg'] as num).round(),
      potassiumMg: (json['potassium_mg'] as num).round(),
      tags: List.unmodifiable((json['tags'] as List).cast<String>()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'kcal': kcal,
    'protein_g': proteinG,
    'carbs_g': carbsG,
    'fat_g': fatG,
    'sodium_mg': sodiumMg,
    'potassium_mg': potassiumMg,
    'tags': tags,
  };

  @override
  bool operator ==(Object other) => other is Food && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
