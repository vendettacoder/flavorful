import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flavorful/data/http_recipe_repository.dart';
import 'package:flavorful/data/recipe_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _ResponseAdapter implements HttpClientAdapter {
  _ResponseAdapter(this.body);
  final String body;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  for (final body in [
    '{"account_deleted":false,"deleted_recipes":4}',
    '{"deleted_recipes":4}',
    'null',
  ]) {
    test(
      'deleteAccount rejects partial or missing confirmation: $body',
      () async {
        final dio = Dio()..httpClientAdapter = _ResponseAdapter(body);
        final repository = HttpRecipeRepository(
          baseUrl: 'http://offline.invalid',
          getToken: () => 'test',
          dio: dio,
        );
        await expectLater(
          repository.deleteAccount(),
          throwsA(isA<RecipeException>()),
        );
      },
    );
  }
  test('deleteAccount accepts explicit successful account deletion', () async {
    final dio = Dio()
      ..httpClientAdapter = _ResponseAdapter('{"account_deleted":true}');
    final repository = HttpRecipeRepository(
      baseUrl: 'http://offline.invalid',
      getToken: () => 'test',
      dio: dio,
    );
    await repository.deleteAccount();
  });
}
