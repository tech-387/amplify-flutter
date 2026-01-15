import 'package:example/utils/subscriptions/subscription_listener_callback_params.dart';

class SubscriptionListener {
  final String subscriptionID;
  final String listenerID;
  final void Function(SubscriptionListenerCallbackParams params) callback;

  SubscriptionListener({
    required this.subscriptionID,
    required this.listenerID,
    required this.callback,
  });

  @override
  String toString() {
    return "SubscriptionListener(subscriptionID=$subscriptionID, listenerID=$listenerID)";
  }

  @override
  int get hashCode => subscriptionID.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is! SubscriptionListener) {
      return false;
    }
    return listenerID == other.listenerID &&
        subscriptionID == other.subscriptionID;
  }
}
