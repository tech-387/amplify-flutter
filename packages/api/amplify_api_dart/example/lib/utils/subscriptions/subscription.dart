import 'dart:async';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:example/utils/logger/logger.dart';
import 'package:flutter/material.dart';

/// Model representing a single subscription.
class Subscription {
  /// The unique identifier for subscription.
  /// NOTE: Best to provide the name of the subscription method.
  final String id;

  /// The callback that initializes this subscription.
  /// This callback should start the subscription.
  /// NOTE: Callback is called from [_registerSubscription] method.
  final void Function(
    void Function(StreamSubscription<dynamic>),
    void Function() onSocketError,
    void Function(GraphQLRequest) onGraphQLRequest,
  )
  method;

  /// The method that checks for parameters/variables before initializing the subscription.
  /// If this method returns `false` then subscription won't be initialized.
  /// This is useful for example if establishing a subscription that requires the input such us user id.
  final bool Function()? validator;

  /// The stream subscription for this [Subscription].
  StreamSubscription? streamSubscription;

  GraphQLRequest? request;

  /// Whether subscription is registered.
  /// This value indicates that the subscription is successfully established by [onStreamSubscriptionEstablished] method.
  bool isSubscriptionRegistered = false;

  /// Whether subscription is paused.
  /// This value indicates that the subscription has been disposed/paused by [disposeSubscription] method.
  bool isSubscriptionPaused = false;

  /// Whether disposal is currently in progress.
  bool _isDisposingInProgress = false;

  /// Whether reinitialization was requested while disposal was in progress.
  bool _reinitializationRequested = false;

  /// Completer to track when disposal is fully complete.
  Completer<void>? _disposalCompleter;

  /// Stream subscription for WebSocket state monitoring during disposal.
  StreamSubscription? _webSocketStateSubscription;

  /// Additional optional callback passed to [registerSubscription] to execute when subscription is established from [onStreamSubscriptionEstablished] method.
  /// NOTE: This is used by [SubscriptionHandler] mixin to determine if every subscription in the list has been successfully initialized.
  VoidCallback? _onEstablished;

  Subscription({required this.id, required this.method, this.validator});

  @override
  String toString() {
    return "Subscription(id=$id, isSubscriptionRegistered=$isSubscriptionRegistered, isSubscriptionPaused=$isSubscriptionPaused)";
  }

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is! Subscription) {
      return false;
    }
    return id == other.id;
  }

  /// Method that attempts to register this [Subscription].
  void registerSubscription({VoidCallback? onEstablished}) async {
    _onEstablished = onEstablished;
    if (validator?.call() == false) {
      Logger.log("Some parameters are not valid (id=$id)");
      return;
    }

    if (isSubscriptionRegistered) {
      Logger.log("Subscription already registered (id=$id)");
      return;
    }

    // If disposal is in progress, wait for it to complete
    if (_isDisposingInProgress) {
      Logger.log("Disposal in progress, waiting for completion (id=$id)");
      _reinitializationRequested = true;
      await _disposalCompleter?.future;

      // If disposal completed and reinitialization is still requested, proceed
      if (_reinitializationRequested && !_isDisposingInProgress) {
        _reinitializationRequested = false;
        Logger.log("Disposal completed, proceeding with registration (id=$id)");
      } else {
        Logger.log(
          "Registration cancelled or disposal still in progress (id=$id)",
        );
        return;
      }
    }

    Logger.wait("Registering subscription (id=$id)");
    _registerSubscription();
  }

  /// Registers this [Subscription] with the provided configuration.
  void _registerSubscription() {
    method.call(
      onStreamSubscriptionEstablished,
      onSocketError,
      onGraphQLRequest,
    );
  }

  void onGraphQLRequest(GraphQLRequest request) {
    this.request = request;
  }

  /// Callback that is called when this [Subscription] has been successfully established.
  void onStreamSubscriptionEstablished(StreamSubscription streamSubscription) {
    Logger.log("Established subscription (id=$id)");
    this.streamSubscription = streamSubscription;
    isSubscriptionRegistered = true;
    _onEstablished?.call();
  }

  /// Callback that is called when this [Subscription] failes due to no internet connection or socket failure.
  void onSocketError() {
    isSubscriptionPaused = true;
    disposeSubscription();
  }

  /// Callback that disposes this [Subscription].
  Future<void> disposeSubscription() async {
    if (_isDisposingInProgress) {
      Logger.log("Disposal already in progress (id=$id)");
      return _disposalCompleter?.future ?? Future.value();
    }

    _isDisposingInProgress = true;
    _disposalCompleter = Completer<void>();

    Logger.success("Starting disposal of subscription (id=$id)");

    // Cancel the main subscription first
    streamSubscription?.cancel();
    streamSubscription = null;
    isSubscriptionRegistered = false;

    if (request != null) {
      final stopwatch = Stopwatch()..start();
      DateTime? lastEventTime;

      final stream = Amplify.API.getWebSocketStateStream(request!);
      _webSocketStateSubscription = stream.listen((event) {
        final currentTime = DateTime.now();
        final elapsedSinceStart = stopwatch.elapsedMilliseconds;

        String timingInfo;
        if (lastEventTime != null) {
          final timeSinceLastEvent = currentTime
              .difference(lastEventTime!)
              .inMilliseconds;
          timingInfo =
              "Elapsed: ${elapsedSinceStart}ms, Since last: ${timeSinceLastEvent}ms";
        } else {
          timingInfo = "Elapsed: ${elapsedSinceStart}ms (first event)";
        }

        Logger.log("WebSocket State: ${event.runtimeType} - $timingInfo");
        lastEventTime = currentTime;

        // Check if we've reached DisconnectedState
        if (event.runtimeType.toString() == 'DisconnectedState') {
          Logger.success(
            "Disposal completed - DisconnectedState reached (id=$id)",
          );
          _completeDisposal();
        }
      });

      // Set a timeout in case DisconnectedState is never reached
      Timer(const Duration(seconds: 10), () {
        if (_isDisposingInProgress) {
          Logger.log("Disposal timeout reached, forcing completion (id=$id)");
          _completeDisposal();
        }
      });
    } else {
      // No request to monitor, complete disposal immediately
      _completeDisposal();
    }

    return _disposalCompleter!.future;
  }

  /// Completes the disposal process and handles any pending reinitialization.
  void _completeDisposal() {
    if (!_isDisposingInProgress) return;

    _webSocketStateSubscription?.cancel();
    _webSocketStateSubscription = null;
    _isDisposingInProgress = false;

    final completer = _disposalCompleter;
    _disposalCompleter = null;
    completer?.complete();

    // If reinitialization was requested during disposal, trigger it
    if (_reinitializationRequested) {
      Logger.log(
        "Reinitialization was requested, triggering registration (id=$id)",
      );
      // Use a small delay to ensure the disposal completion is fully processed
      Timer(const Duration(milliseconds: 100), () {
        if (_reinitializationRequested) {
          registerSubscription(onEstablished: _onEstablished);
        }
      });
    }
  }
}
