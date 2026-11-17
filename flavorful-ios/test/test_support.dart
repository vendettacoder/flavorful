import 'dart:async';

import 'package:flavorful/data/auth_repository.dart';
import 'package:flavorful/data/mock_recipe_repository.dart';
import 'package:flavorful/data/sample_data.dart';
import 'package:flavorful/models/recipe.dart';

AuthSession testSession({String id = 'user-a', String token = 'token-a'}) =>
    AuthSession(
      userId: id,
      token: token,
      email: 'same@example.com',
      userInitial: 'A',
      provider: 'google',
    );

class TestAuthRepository implements AuthRepository {
  TestAuthRepository([this.session]);
  AuthSession? session;
  Uri? callback;
  bool failCallback = false;
  final changes = StreamController<AuthSession?>.broadcast();
  void emit(AuthSession? value) {
    session = value;
    changes.add(value);
  }

  @override
  Future<AuthSession?> currentSession() async => session;
  @override
  Stream<AuthSession?> authStateChanges() => changes.stream;
  @override
  Future<void> signInWithGoogle() async => emit(testSession());
  @override
  Future<void> signInWithApple() async => emit(testSession());
  @override
  Future<void> signOut() async => emit(null);
  @override
  Future<void> completeWebSignIn(Uri uri) async {
    callback = uri;
    if (failCallback) throw StateError('Invalid callback');
    emit(testSession());
  }
}

class TestRecipeRepository extends MockRecipeRepository {
  List<Recipe> data = buildSampleRecipes();
  Completer<List<Recipe>>? pending;
  Completer<Recipe>? pendingDetail;
  @override
  Future<List<Recipe>> getAllRecipes() async => pending?.future ?? data;
  @override
  Future<bool> toggleFavorite(String id) async {
    data = [
      for (final recipe in data)
        if (recipe.id == id)
          recipe.copyWith(isFavorited: !recipe.isFavorited)
        else
          recipe,
    ];
    return data.firstWhere((recipe) => recipe.id == id).isFavorited;
  }

  @override
  Future<Recipe> getRecipe(String id) async =>
      pendingDetail?.future ?? data.firstWhere((recipe) => recipe.id == id);
}
