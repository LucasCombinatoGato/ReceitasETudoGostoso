import 'package:flutter_test/flutter_test.dart';
import 'package:minha_lista_comida_tudo_gostosa/models/recipe.dart';

void main() {
  group('Recipe', () {
    test('serializes API sections and statistics for Firestore', () {
      const recipe = Recipe(
        title: 'Picanha invertida',
        sourceId: '123-picanha-invertida',
        ingredientSections: [
          RecipeSection(
            title: 'Recheio',
            items: ['400 g de provolone', '100 g de bacon'],
          ),
        ],
        instructionSections: [
          RecipeSection(title: 'default', items: ['Asse até dourar.']),
        ],
        stats: RecipeStats(
          prepareTimeMinutes: 90,
          portionOutput: 5,
          favorites: 7933,
        ),
      );

      final data = recipe.toFirestore();

      expect(data['ingredients'], [
        {
          'title': 'Recheio',
          'items': ['400 g de provolone', '100 g de bacon'],
        },
      ]);
      expect(data['instructions'], [
        {
          'title': 'default',
          'items': ['Asse até dourar.'],
        },
      ]);
      expect(data['stats'], {
        'prepare_time_minutes': 90,
        'portion_output': 5,
        'favorites': 7933,
      });
    });

    test('reads API detail fields and retains section titles', () {
      final recipe = Recipe.fromApiDetails(
        {
          'title': 'Picanha invertida',
          'stats': {
            'prepare_time_minutes': 90,
            'portion_output': 5,
            'favorites': 7933,
          },
          'ingredients': [
            {
              'title': 'Recheio',
              'items': ['400 g de provolone', '100 g de bacon'],
            },
          ],
          'instructions': [
            {'title': 'default', 'items': ['Asse até dourar.']},
          ],
        },
        id: '123-picanha-invertida',
      );

      expect(recipe.title, 'Picanha invertida');
      expect(recipe.sourceId, '123-picanha-invertida');
      expect(recipe.ingredientSections.single.title, 'Recheio');
      expect(recipe.ingredients, ['400 g de provolone', '100 g de bacon']);
      expect(recipe.instructionSections.single.items, ['Asse até dourar.']);
      expect(recipe.stats.prepareTimeMinutes, 90);
      expect(recipe.stats.portionOutput, 5);
      expect(recipe.stats.favorites, 7933);
    });

    test('reads saved recipe documents and preserves their document id', () {
      final recipe = Recipe.fromFirestore('doc-1', {
        'title': 'Bolo',
        'sourceId': '',
        'ingredients': [
          {'title': 'default', 'items': ['Farinha']},
        ],
        'instructions': [
          {'title': 'default', 'items': ['Misture.']},
        ],
        'stats': {},
      });

      expect(recipe.id, 'doc-1');
      expect(recipe.title, 'Bolo');
      expect(recipe.ingredients, ['Farinha']);
      expect(recipe.instructions, ['Misture.']);
    });
  });
}
