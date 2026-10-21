// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

/// {@template amplify_api_dart.background_isolate.supports_background_isolate}
/// Whether [runInBackgroundIsolate] is supported on this platform. Isolates
/// are not available on the web.
/// {@endtemplate}
const bool supportsBackgroundIsolate = false;

/// {@template amplify_api_dart.background_isolate.run_in_background_isolate}
/// Runs [computation] in a new isolate and returns its result, so that it does
/// not block the calling isolate.
///
/// [computation] and its result are sent between isolates, so they must only
/// hold sendable objects. Only supported when [supportsBackgroundIsolate].
/// {@endtemplate}
Future<R> runInBackgroundIsolate<R>(R Function() computation) {
  throw UnsupportedError('Isolates are not supported on this platform.');
}
