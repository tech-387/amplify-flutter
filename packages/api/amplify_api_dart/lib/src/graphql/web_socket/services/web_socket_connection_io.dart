// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io' as io;

import 'package:meta/meta.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// {@macro amplify_api_dart.web_socket_connection}
@internal
class WebSocketConnection {
  /// {@macro amplify_api_dart.web_socket_connection}
  factory WebSocketConnection.connect(Uri uri, {Iterable<String>? protocols}) {
    final socket = io.WebSocket.connect(uri.toString(), protocols: protocols);
    return WebSocketConnection._(socket, IOWebSocketChannel(socket));
  }

  WebSocketConnection._(this._socket, this.channel) {
    // Connection errors are reported through the stream of [channel].
    _socket.ignore();
  }

  final Future<io.WebSocket> _socket;

  /// The channel used to send and receive messages.
  final WebSocketChannel channel;

  /// Identifies the latest [verify] call, so an earlier call does not end a
  /// later check.
  int _verification = 0;

  /// {@macro amplify_api_dart.web_socket_connection.verify}
  void verify(Duration timeout) {
    final verification = ++_verification;
    unawaited(
      _socket.then((socket) {
        if (socket.readyState != io.WebSocket.open) return;
        // dart:io sends a ping after the interval and closes the socket with
        // `goingAway` if no pong arrives within another interval. A pong
        // restarts the cycle, so pings stop once the connection is confirmed.
        socket.pingInterval = timeout;
        Timer(timeout * 2 + const Duration(seconds: 1), () {
          if (verification == _verification &&
              socket.readyState == io.WebSocket.open) {
            socket.pingInterval = null;
          }
        });
      }, onError: (Object _) {}),
    );
  }
}
