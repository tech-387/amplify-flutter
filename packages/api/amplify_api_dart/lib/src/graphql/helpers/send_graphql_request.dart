// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:amplify_api_dart/src/graphql/helpers/background_isolate.dart';
import 'package:amplify_api_dart/src/graphql/helpers/graphql_response_decoder.dart';
import 'package:amplify_core/amplify_core.dart';
import 'package:meta/meta.dart';

/// Response bodies at least this large, in bytes, are decoded in a background
/// isolate, so that parsing them doesn't block the calling isolate (the UI
/// isolate in Flutter apps). Smaller ones are decoded inline, where starting an
/// isolate would cost more than it saves.
const _backgroundDecodeThreshold = 32 * 1024;

/// Converts the [GraphQLRequest] to an HTTP POST request and sends with ///[client].
@internal
GraphQLOperation<T> sendGraphQLRequest<T>({
  required GraphQLRequest<T> request,
  required AWSHttpClient client,
  required Uri uri,
}) {
  final body = {'variables': request.variables, 'query': request.document};
  final graphQLOperation = client.send(
    AWSStreamedHttpRequest.post(
      uri,
      body: HttpPayload.json(body),
      headers: request.headers,
    ),
  );

  return GraphQLOperation(
    graphQLOperation.operation.then(
      (response) async {
        final bodyBytes = await response.bodyBytes;

        // Without a model type, `data` is re-encoded as a JSON string, which
        // needs nothing from the calling isolate. Models are decoded with the
        // model provider registered in the calling isolate, so they stay here.
        if (supportsBackgroundIsolate &&
            request.modelType == null &&
            (T == String || T == dynamic) &&
            bodyBytes.length >= _backgroundDecodeThreshold) {
          return _decodeStringResponseInBackground<T>(bodyBytes);
        }

        return GraphQLResponseDecoder.instance.decode<T>(
          request: request,
          response: _parseResponseBody(bodyBytes),
        );
      },
      onError: (error, stackTrace) {
        Error.throwWithStackTrace(
          UnknownException(
            'unable to send GraphQLRequest to client.',
            underlyingException: error,
          ),
          stackTrace,
        );
      },
    ),
  );
}

/// Decodes [bodyBytes] into the JSON object of a GraphQL response.
Map<String, dynamic> _parseResponseBody(List<int> bodyBytes) {
  final responseJson = utf8.decode(bodyBytes);
  final responseBody = json.decode(responseJson);

  if (responseBody is! Map<String, dynamic>) {
    throw UnknownException(
      'unable to parse GraphQLResponse from server response which was '
      'not a JSON object: $responseJson',
    );
  }

  return responseBody;
}

/// Decodes the response to a request without a model type in a background
/// isolate, with the same result and errors as decoding it in this isolate.
///
/// Top-level on purpose: the isolate closure must capture only [bodyBytes].
/// A closure created in [sendGraphQLRequest] would also capture its scope,
/// such as the request, whose variables may hold objects that can't be sent
/// to another isolate.
Future<GraphQLResponse<T>> _decodeStringResponseInBackground<T>(
  List<int> bodyBytes,
) {
  return runInBackgroundIsolate(
    () => GraphQLResponseDecoder.instance.decodeString<T>(
      _parseResponseBody(bodyBytes),
    ),
  );
}
