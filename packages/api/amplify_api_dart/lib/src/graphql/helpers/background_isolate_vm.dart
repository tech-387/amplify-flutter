// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:isolate';

/// {@macro amplify_api_dart.background_isolate.supports_background_isolate}
const bool supportsBackgroundIsolate = true;

/// {@macro amplify_api_dart.background_isolate.run_in_background_isolate}
Future<R> runInBackgroundIsolate<R>(R Function() computation) {
  return Isolate.run(computation, debugName: 'amplify_api_dart background');
}
