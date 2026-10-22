import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:minha_lista_comida_tudo_gostosa/services/recipe_api_service.dart';

void main() {
  group('RecipeApiService', () {
    test('searches by title using the documented search route', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.pathSegments, ['v1', 'search', 'bolo de aveia']);
        return http.Response(
          jsonEncode([
            {
              'title': 'Bolo de aveia com cacau no micro-ondas',
              'id': '307527-bolo-de-aveia-com-cacau-no-micro-ondas',
            },
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = RecipeApiService(
        client: client,
        baseUrl: 'https://receitas.example/v1/',
      );

      final recipes = await service.search('bolo de aveia');

      expect(recipes.single.title, 'Bolo de aveia com cacau no micro-ondas');
      expect(
        recipes.single.sourceId,
        '307527-bolo-de-aveia-com-cacau-no-micro-ondas',
      );
      expect(recipes.single.hasDetails, isFalse);
    });

    test('loads recipe details using the API recipe id', () async {
      final client = MockClient((request) async {
        expect(request.url.pathSegments, ['recipe', '123-picanha-invertida']);
        return http.Response(
          jsonEncode({
            'title': 'Picanha invertida',
            'stats': {
              'prepare_time_minutes': 90,
              'portion_output': 5,
              'favorites': 7933,
            },
            'ingredients': [
              {
                'title': 'Recheio',
                'items': ['400 g de provolone'],
              },
            ],
            'instructions': [
              {
                'title': 'default',
                'items': ['Asse até dourar.'],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = RecipeApiService(
        client: client,
        baseUrl: 'https://receitas.example',
      );

      final recipe = await service.getRecipe('123-picanha-invertida');

      expect(recipe.title, 'Picanha invertida');
      expect(recipe.ingredientSections.single.title, 'Recheio');
      expect(recipe.stats.prepareTimeMinutes, 90);
    });

    test('reports the documented error field for HTTP 400', () async {
      final service = RecipeApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'erro': 'Receita não encontrada'}),
            400,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
        baseUrl: 'https://receitas.example',
      );

      await expectLater(
        service.getRecipe('missing'),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Receita não encontrada'),
          ),
        ),
      );
    });
  });
}
