// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:isolate';

import 'package:amplify_api_dart/amplify_api_dart.dart';
import 'package:amplify_api_dart/src/graphql/helpers/background_isolate.dart';
import 'package:amplify_core/amplify_core.dart';
import 'package:aws_common/testing.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'test_data/fake_amplify_configuration.dart';
import 'test_models/ModelProvider.dart';

/// Smallest response body, in bytes, that is decoded in a background isolate.
const _backgroundDecodeThreshold = 32 * 1024;

/// A list query result well above [_backgroundDecodeThreshold], with
/// non-ASCII text to cover UTF-8 decoding.
final _largeQueryResponseBody = {
  'data': {
    'listBlogs': {
      'items': [
        for (var index = 0; index < 1000; index++)
          {
            'id': 'blog-$index',
            'name': 'Blog $index — ćevapi, 日本語, 🏀',
            'createdAt': '2021-07-21T22:23:33.707Z',
          },
      ],
      'nextToken': 'next-token',
    },
  },
};

/// [expectedErrorResponseBody] with enough errors to be decoded in a
/// background isolate.
final _largeErrorResponseBody = {
  'data': null,
  'errors': List.filled(
    300,
    (expectedErrorResponseBody['errors']! as List).single,
  ),
};

/// A model query result above [_backgroundDecodeThreshold].
final _largeModelQueryResponseBody = {
  'data': {
    'getBlog': {
      'id': modelQueryId,
      'name': 'Test App Blog ' * 3000,
      'createdAt': '2021-07-21T22:23:33.707Z',
    },
  },
};

final _largeQueryHttpClient = MockAWSHttpClient((request, _) async {
  final body = await utf8.decodeStream(request.body);
  final List<int> responseBody;
  if (body.contains('LargeErrors')) {
    responseBody = utf8.encode(json.encode(_largeErrorResponseBody));
  } else if (body.contains('LargeArray')) {
    responseBody = utf8.encode(
      json.encode(_largeQueryResponseBody['data']!['listBlogs']!['items']),
    );
  } else if (body.contains('LargeMalformed')) {
    responseBody = utf8.encode('${json.encode(_largeQueryResponseBody)}}');
  } else if (body.contains('getBlog')) {
    responseBody = utf8.encode(json.encode(_largeModelQueryResponseBody));
  } else {
    responseBody = utf8.encode(json.encode(_largeQueryResponseBody));
  }
  return AWSHttpResponse(statusCode: 200, body: responseBody);
});

/// A request variable that can be encoded in the request body, but can't be
/// sent to another isolate.
class _UnsendableVariable {
  final port = ReceivePort();

  Map<String, Object?> toJson() => {'value': 'unsendable'};
}

void main() {
  setUp(() async {
    await Amplify.addPlugin(
      AmplifyAPIDart(
        options: APIPluginOptions(
          baseHttpClient: _largeQueryHttpClient,
          modelProvider: ModelProvider.instance,
        ),
      ),
    );
    await Amplify.configure(amplifyConfig);
  });

  tearDown(Amplify.reset);

  test(
    'the response fixtures are large enough to decode in the background',
    () {
      for (final body in [
        _largeQueryResponseBody,
        _largeErrorResponseBody,
        _largeModelQueryResponseBody,
      ]) {
        expect(
          utf8.encode(json.encode(body)).length,
          greaterThanOrEqualTo(_backgroundDecodeThreshold),
        );
      }
    },
  );

  group('Large GraphQL responses', () {
    test('query returns response.data encoded as a JSON string', () async {
      final request = GraphQLRequest<String>(
        document: 'query LargeQuery { listBlogs { items { id name } } }',
      );

      final response = await Amplify.API.query(request: request).response;

      expect(response.data, json.encode(_largeQueryResponseBody['data']));
      expect(response.errors, isEmpty);
    });

    test('query with dynamic type returns response.data', () async {
      final request = GraphQLRequest<dynamic>(
        document: 'query LargeQuery { listBlogs { items { id name } } }',
      );

      final response = await Amplify.API.query(request: request).response;

      expect(response.data, json.encode(_largeQueryResponseBody['data']));
      expect(response.errors, isEmpty);
    });

    test('mutate returns response.data', () async {
      final request = GraphQLRequest<String>(
        document: 'mutation LargeMutation { createBlog { id } }',
      );

      final response = await Amplify.API.mutate(request: request).response;

      expect(response.data, json.encode(_largeQueryResponseBody['data']));
    });

    test('response errors are decoded', () async {
      final request = GraphQLRequest<String>(document: 'query LargeErrors {}');

      final response = await Amplify.API.query(request: request).response;

      const errorExpected = GraphQLResponseError(
        message: errorMessage,
        locations: [
          GraphQLResponseErrorLocation(2, 3),
          GraphQLResponseErrorLocation(4, 5),
        ],
        path: <dynamic>[...errorPath],
        extensions: <String, dynamic>{...errorExtensions},
        errorType: errorType,
        errorInfo: errorInfo,
      );
      expect(response.data, isNull);
      expect(response.errors, List.filled(300, errorExpected));
    });

    test('a body that is not a JSON object throws UnknownException', () async {
      final request = GraphQLRequest<String>(document: 'query LargeArray {}');

      await expectLater(
        Amplify.API.query(request: request).response,
        throwsA(
          isA<UnknownException>().having(
            (exception) => exception.message,
            'message',
            startsWith(
              'unable to parse GraphQLResponse from server response which '
              'was not a JSON object: [',
            ),
          ),
        ),
      );
    });

    test('a malformed body throws FormatException', () async {
      final request = GraphQLRequest<String>(
        document: 'query LargeMalformed {}',
      );

      await expectLater(
        Amplify.API.query(request: request).response,
        throwsFormatException,
      );
    });

    test('model query is decoded with the model provider', () async {
      final request = ModelQueries.get<Blog>(
        Blog.classType,
        BlogModelIdentifier(id: modelQueryId),
      );

      final response = await Amplify.API.query(request: request).response;

      expect(response.data, isA<Blog>());
      expect(response.data?.id, modelQueryId);
      expect(response.data?.name, 'Test App Blog ' * 3000);
      expect(response.errors, isEmpty);
    });

    test('request variables are not sent to the background isolate', () async {
      final variable = _UnsendableVariable();
      addTearDown(variable.port.close);
      await expectLater(
        Isolate.run(variable.toJson),
        throwsArgumentError,
        reason: 'the variable must not be sendable for this test to hold',
      );
      final request = GraphQLRequest<String>(
        document:
            r'query LargeQuery($input: Input) { listBlogs { items { id } } }',
        variables: {'input': variable},
      );

      final response = await Amplify.API.query(request: request).response;

      expect(response.data, json.encode(_largeQueryResponseBody['data']));
    });
  });

  group('runInBackgroundIsolate', () {
    test('runs the computation in another isolate', () async {
      expect(supportsBackgroundIsolate, isTrue);
      expect(
        await runInBackgroundIsolate(() => Isolate.current.debugName),
        'amplify_api_dart background',
      );
    });

    test('rethrows errors of the computation', () async {
      await expectLater(
        runInBackgroundIsolate<void>(() => throw const FormatException('bad')),
        throwsFormatException,
      );
    });
  });
}
