import 'dart:developer';

import 'package:example/utils/subscriptions/subscription_listener.dart';
import 'package:example/utils/subscriptions/subscription_listener_callback_params.dart';
import 'package:flutter/material.dart';

/// Notifier class for monitoring and handling subscription listeners
class SubscriptionListenersNotifier extends ChangeNotifier {
  static SubscriptionListenersNotifier? _instance;

  SubscriptionListenersNotifier._private() {
    _instance = this;
  }

  /// Singleton pattern for accessing the instance of SubscriptionListenersNotifier.
  static SubscriptionListenersNotifier get instance {
    if (_instance == null) return SubscriptionListenersNotifier._private();
    return _instance!;
  }

  /// Custom subscription listeners that can be attached to any subscription.
  List<SubscriptionListener> subscriptionListeners = [];

  /// Method that adds [subscriptionListener] to list of subscription listeners in [subscriptionListeners].
  /// Useful when other class should listen for notify changes.
  void addSubscriptionListener(SubscriptionListener subscriptionListener) {
    if (!subscriptionListeners.contains(subscriptionListener)) {
      subscriptionListeners.add(subscriptionListener);
    }
    inspect(subscriptionListeners);
  }

  /// Method that removes [subscriptionListener] from the list of subscription listeners in [subscriptionListeners].
  void removeSubscriptionListener(SubscriptionListener subscriptionListener) {
    subscriptionListeners.remove(subscriptionListener);
    inspect(subscriptionListener);
  }

  void notifySubscriptionListeners({
    required String subscriptionID,
    required SubscriptionListenerCallbackParams callbackParams,
  }) {
    for (var subscriptionListener in subscriptionListeners) {
      if (subscriptionListener.subscriptionID == subscriptionID) {
        subscriptionListener.callback.call(callbackParams);
      }
    }
  }
}
