// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

export 'background_isolate_stub.dart'
    if (dart.library.io) 'background_isolate_vm.dart';
