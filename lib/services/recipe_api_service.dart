import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/recipe.dart';

class RecipeApiService {
  RecipeApiService({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'RECIPES_API_BASE_URL',
              defaultValue: 'http://10.0.2.2:3000',
            );

  final http.Client _client;
  final String _baseUrl;

  Future<List<Recipe>> search(String title) async {
    final response = await _client.get(_endpoint(['search', title]));
    final body = _decodeResponse(response);
    if (body is! List) {
      throw const FormatException(
        'A API deveria retornar uma lista de receitas para a busca.',
      );
    }

    return body.map((item) {
      if (item is! Map<String, dynamic> ||
          item['id'] is! String ||
          item['title'] is! String) {
        throw const FormatException(
          'A API retornou um resultado de busca inválido.',
        );
      }
      return Recipe.fromApiSearch(item);
    }).toList();
  }

  Future<Recipe> getRecipe(String id) async {
    final response = await _client.get(_endpoint(['recipe', id]));
    final body = _decodeResponse(response);
    if (body is! Map<String, dynamic> ||
        body['title'] is! String ||
        !_hasValidSections(body['ingredients']) ||
        !_hasValidSections(body['instructions']) ||
        !_hasValidStats(body['stats'])) {
      throw const FormatException(
        'A API retornou detalhes de receita em formato inválido.',
      );
    }
    return Recipe.fromApiDetails(body, id: id);
  }

  Uri _endpoint(List<String> pathSegments) {
    final base = Uri.tryParse(_baseUrl);
    if (base == null ||
        !base.hasAuthority ||
        (base.scheme != 'https' && base.scheme != 'http')) {
      throw const FormatException(
        'URL base da API inválida. Defina RECIPES_API_BASE_URL.',
      );
    }
    return base.replace(
      pathSegments: [
        ...base.pathSegments.where((segment) => segment.isNotEmpty),
        ...pathSegments,
      ],
      query: null,
      fragment: null,
    );
  }

  bool _hasValidSections(dynamic value) =>
      value is List &&
      value.every(
        (section) =>
            section is Map<String, dynamic> &&
            section['title'] is String &&
            section['items'] is List &&
            (section['items'] as List).every((item) => item is String),
      );

  bool _hasValidStats(dynamic value) =>
      value is Map<String, dynamic> &&
      value['prepare_time_minutes'] is num &&
      value['portion_output'] is num &&
      value['favorites'] is num;

  dynamic _decodeResponse(http.Response response) {
    dynamic body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      if (response.statusCode != 200) {
        throw Exception('A API respondeu com HTTP ${response.statusCode}.');
      }
      rethrow;
    }

    if (response.statusCode != 200) {
      final error = body is Map<String, dynamic> ? body['erro'] : null;
      throw Exception(
        error is String && error.isNotEmpty
            ? error
            : 'A API respondeu com HTTP ${response.statusCode}.',
      );
    }
    return body;
  }
}
