import 'dart:async';
import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:example/models/user.dart';
import 'package:example/utils/logger/logger.dart';

abstract class SubscriptionUserService {
  static Future<void> onUpdateUserSubscription({
    required void Function(StreamSubscription) onStreamSubscriptionEstablished,
    required void Function() onSocketError,
    required String userID,
    required Function(User) onUpdateUser,
    required void Function(GraphQLRequest) onGraphQLRequest,
  }) async {
    String graphQLDocument = '''subscription OnUpdateUserSubscription {
  onUpdateUser {
    id
    status
    onboardingStatus
    givenName
    familyName
    description
    nickname
    allowPushNotifications
    whoCanSeeMyOnlineStatus
    allowChatReadReceipts
    whoCanMessageMe
    createdAt
    updatedAt
    picture
    pictureThumbnail
    pictureThumbnailJpg
  }
}''';

    Logger.log('graphQLDocument: $graphQLDocument');

    try {
      StreamSubscription? streamSubscription;

      Stream<GraphQLResponse> graphQLResponseStream = Amplify.API.subscribe(
        GraphQLRequest<String>(document: graphQLDocument),
        onEstablished: () {
          Logger.success("established");
          // Sets created subscription to the caller that is responsible for handling its lifecycle.
          if (streamSubscription != null) {
            onStreamSubscriptionEstablished.call(streamSubscription);
            onGraphQLRequest.call(
              GraphQLRequest<String>(document: graphQLDocument),
            );
          }
          Logger.success('established');
        },
      );

      streamSubscription = graphQLResponseStream.listen(
        (graphQLResponse) async {
          if (graphQLResponse.data == null) {
            throw Exception(
              'response data is null, response errors: ${graphQLResponse.errors}',
            );
          }

          var data = jsonDecode(graphQLResponse.data);

          Logger.log('data: $data');

          if (data["onUpdateUser"] == null) {
            if (graphQLResponse.errors.isNotEmpty) {
              throw Exception(
                'data is null, response errors: ${graphQLResponse.errors}',
              );
            }
            return;
          }

          final User user = User.fromJson(data["onUpdateUser"]);
          Logger.success('User updated successfully!');

          onUpdateUser(user);
        },
        onError: (error, stacktrace) {
          Logger.error(
            log: "error=$error",
            error: error,
            stacktrace: stacktrace,
          );

          // Web socket crashed because of internet connection then we will dispose subscription.
          // Subscriptions will be reinitialized after internet is back online.
          if (error is NetworkException || error is TimeoutException) {
            onSocketError.call();
          }
        },
      );
    } catch (error, stacktrace) {
      Logger.error(log: "error=$error", error: error, stacktrace: stacktrace);
    }
  }
}
