class RecipeSection {
  const RecipeSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  Map<String, dynamic> toMap() => {'title': title, 'items': items};

  factory RecipeSection.fromMap(Map<String, dynamic> data) => RecipeSection(
        title: data['title'] as String? ?? 'default',
        items: _readStrings(data['items']),
      );
}

class RecipeStats {
  const RecipeStats({
    this.prepareTimeMinutes,
    this.portionOutput,
    this.favorites,
  });

  final int? prepareTimeMinutes;
  final int? portionOutput;
  final int? favorites;

  Map<String, dynamic> toMap() => {
        'prepare_time_minutes': prepareTimeMinutes,
        'portion_output': portionOutput,
        'favorites': favorites,
      };

  factory RecipeStats.fromMap(Map<String, dynamic> data) => RecipeStats(
        prepareTimeMinutes: _readInt(data['prepare_time_minutes']),
        portionOutput: _readInt(data['portion_output']),
        favorites: _readInt(data['favorites']),
      );
}

class Recipe {
  const Recipe({
    this.id,
    required this.title,
    this.sourceId = '',
    this.ingredients = const [],
    this.instructions = const [],
    this.ingredientSections = const [],
    this.instructionSections = const [],
    this.stats = const RecipeStats(),
  });

  final String? id;
  final String title;
  final String sourceId;
  final List<String> ingredients;
  final List<String> instructions;
  final List<RecipeSection> ingredientSections;
  final List<RecipeSection> instructionSections;
  final RecipeStats stats;

  bool get hasDetails =>
      ingredientSections.isNotEmpty || instructionSections.isNotEmpty;

  Recipe copyWith({String? id}) => Recipe(
        id: id ?? this.id,
        title: title,
        sourceId: sourceId,
        ingredients: ingredients,
        instructions: instructions,
        ingredientSections: ingredientSections,
        instructionSections: instructionSections,
        stats: stats,
      );

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'sourceId': sourceId,
        'stats': stats.toMap(),
        'ingredients': _sectionsForStorage(ingredientSections, ingredients),
        'instructions': _sectionsForStorage(instructionSections, instructions),
      };

  factory Recipe.fromFirestore(String id, Map<String, dynamic> data) {
    final ingredients = _readSections(data['ingredients']);
    final instructions = _readSections(data['instructions']);
    final statsData = data['stats'];
    return Recipe(
      id: id,
      title: data['title'] as String? ?? '',
      sourceId: data['sourceId'] as String? ?? '',
      ingredients: _flatten(ingredients),
      instructions: _flatten(instructions),
      ingredientSections: ingredients,
      instructionSections: instructions,
      stats: statsData is Map<String, dynamic>
          ? RecipeStats.fromMap(statsData)
          : const RecipeStats(),
    );
  }

  factory Recipe.fromApiSearch(Map<String, dynamic> data) => Recipe(
        title: data['title'] as String,
        sourceId: data['id'] as String,
      );

  factory Recipe.fromApiDetails(Map<String, dynamic> data, {String id = ''}) {
    final statsData = data['stats'];
    final ingredients = _readSections(data['ingredients']);
    final instructions = _readSections(data['instructions']);
    return Recipe(
      sourceId: id,
      title: data['title'] as String,
      ingredients: _flatten(ingredients),
      instructions: _flatten(instructions),
      ingredientSections: ingredients,
      instructionSections: instructions,
      stats: statsData is Map<String, dynamic>
          ? RecipeStats.fromMap(statsData)
          : const RecipeStats(),
    );
  }

  static List<Map<String, dynamic>> _sectionsForStorage(
    List<RecipeSection> sections,
    List<String> items,
  ) =>
      (sections.isEmpty
              ? [RecipeSection(title: 'default', items: items)]
              : sections)
          .map((section) => section.toMap())
          .toList();

  static List<RecipeSection> _readSections(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) {
          if (item is Map<String, dynamic>) {
            return RecipeSection.fromMap(item);
          }
          if (item is Map) {
            return RecipeSection.fromMap(Map<String, dynamic>.from(item));
          }
          if (item is String) {
            return RecipeSection(title: 'default', items: [item]);
          }
          return null;
        })
        .whereType<RecipeSection>()
        .toList();
  }

  static List<String> _flatten(List<RecipeSection> sections) =>
      sections.expand((section) => section.items).toList();
}

List<String> _readStrings(dynamic value) =>
    value is List ? value.whereType<String>().toList() : const [];

int? _readInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
