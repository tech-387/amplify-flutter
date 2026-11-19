// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

export 'web_socket_connection_stub.dart'
    if (dart.library.io) 'web_socket_connection_io.dart';
