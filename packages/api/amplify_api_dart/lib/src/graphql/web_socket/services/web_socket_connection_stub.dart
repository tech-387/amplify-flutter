// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:meta/meta.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// {@template amplify_api_dart.web_socket_connection}
/// A WebSocket connection to AppSync together with a way to check that the
/// connection still works.
/// {@endtemplate}
@internal
class WebSocketConnection {
  /// {@macro amplify_api_dart.web_socket_connection}
  WebSocketConnection.connect(Uri uri, {Iterable<String>? protocols})
    : channel = WebSocketChannel.connect(uri, protocols: protocols);

  /// The channel used to send and receive messages.
  final WebSocketChannel channel;

  /// {@template amplify_api_dart.web_socket_connection.verify}
  /// Checks that the connection still reaches the server with a WebSocket
  /// ping. If the ping is not answered within [timeout], the connection is
  /// closed and the stream of [channel] is done.
  ///
  /// The ping is sent [timeout] after this call, so a connection that stopped
  /// working is closed within twice the [timeout].
  /// {@endtemplate}
  ///
  /// Browsers do not let pings be sent, so this does nothing on the web.
  void verify(Duration timeout) {}
}
