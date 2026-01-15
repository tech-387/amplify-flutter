import 'package:example/utils/logger/logger.dart';
import 'package:example/utils/subscriptions/subscription.dart';
import 'package:flutter/material.dart';

/// Mixin that provides subscription utility method to register and dispose subscriptions.
mixin SubscriptionHandler on ChangeNotifier {
  /// The list of susbcriptions that this mixin manages.
  /// To attempt to initialize every subscription call [registerSubscriptions] method.
  /// To dispose every subscription call [disposeSubscriptions] method.
  List<Subscription> get subscriptions;

  /// Method that attempts to register all subscriptions in [subscriptions].
  void registerSubscriptions() {
    for (var subscription in subscriptions) {
      subscription.registerSubscription(
        onEstablished: _checkAllSubscriptionsRegistered,
      );
    }
  }

  /// Method that disposes all subscriptions in [subscriptions].
  void disposeSubscriptions() {
    Logger.wait("Disposing all subscriptions");
    for (var subscription in subscriptions) {
      subscription.disposeSubscription();
    }
  }

  /// Method that checks whether every subscription is established.
  /// Every subscription will notify and execute this callback when it has been established successfully.
  /// If the last subscription is established then [onAllSubscriptionsRegistered] is called.
  void _checkAllSubscriptionsRegistered() {
    if (subscriptions.every(
      (subscription) => subscription.isSubscriptionRegistered,
    )) {
      if (subscriptions.any(
        (subscription) => subscription.isSubscriptionPaused,
      )) {
        Logger.success("All subscriptions recovered");
        onAllSubscriptionsRecovered();
      } else {
        Logger.success("All subscriptions registered");
        onAllSubscriptionsRegistered();
      }
    }
  }

  /// Callback that is called when every subscription has been established.
  /// Called from [_checkAllSubscriptionsRegistered].
  void onAllSubscriptionsRegistered() {}

  /// Callback that is called when every subscription has been reestablished.
  /// Called from [_checkAllSubscriptionsRegistered].
  void onAllSubscriptionsRecovered() {}
}
