import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/recipe.dart';

class RecipeRepository {
  RecipeRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _recipes(String userId) =>
      _firestore.collection('users').doc(userId).collection('recipes');

  Stream<List<Recipe>> watchRecipes(String userId) => _recipes(userId)
      .orderBy('title')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((document) => Recipe.fromFirestore(document.id, document.data()))
          .toList());

  Future<void> saveRecipe(String userId, Recipe recipe) async {
    final collection = _recipes(userId);
    final document = recipe.id != null
        ? collection.doc(recipe.id)
        : recipe.sourceId.isNotEmpty
            ? collection.doc('recipe_${Uri.encodeComponent(recipe.sourceId)}')
            : collection.doc();
    await document.set(recipe.toFirestore());
  }

  Future<void> deleteRecipe(String userId, String recipeId) =>
      _recipes(userId).doc(recipeId).delete();
}
