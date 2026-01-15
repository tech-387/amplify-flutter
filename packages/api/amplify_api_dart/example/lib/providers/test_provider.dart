import 'package:example/services/subscription_user_service.dart';
import 'package:example/shared/app_lifecycle_mixin.dart';
import 'package:example/utils/logger/logger.dart';
import 'package:example/utils/subscriptions/subscription.dart';
import 'package:example/utils/subscriptions/subscription_handler.dart';
import 'package:flutter/material.dart';

class TestProvider extends ChangeNotifier
    with SubscriptionHandler, AppLifecycleMixin {
  TestProvider() {
    registerSubscriptions();
    initLifecycleListener();
  }

  @override
  late List<Subscription> subscriptions = [
    Subscription(
      id: "onUpdateUserSubscription",
      method:
          (onStreamSubscriptionEstablished, onSocketError, onGraphQLRequest) =>
              SubscriptionUserService.onUpdateUserSubscription(
                onStreamSubscriptionEstablished:
                    onStreamSubscriptionEstablished,
                onSocketError: onSocketError,
                userID: "test",
                onUpdateUser: onUpdateUser,
                onGraphQLRequest: onGraphQLRequest,
              ),
    ),
  ];

  void onUpdateUser(user) {
    Logger.log("User updated: $user");
  }

  @override
  void onPaused() {
    disposeSubscriptions();
    super.onPaused();
  }

  @override
  void onRestart() {
    registerSubscriptions();
    super.onRestart();
  }

  @override
  void dispose() {
    disposeSubscriptions();
    disposeLifecycleListener();
    super.dispose();
  }
}
