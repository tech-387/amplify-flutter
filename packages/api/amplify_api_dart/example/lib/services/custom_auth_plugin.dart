import 'dart:async';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'dart:developer' as dev;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:example/utils/logger/logger.dart';

class CustomAuthPlugin extends AmplifyAuthCognito {
  final bool enableLogs;

  CustomAuthPlugin({required this.enableLogs});

  @override
  Future<CognitoAuthSession> fetchAuthSession({
    FetchAuthSessionOptions? options,
  }) async {
    try {
      if (enableLogs) {
        dev.log(
          "CustomAuthPlugin: fetchAuthSession(): start options?.forceRefresh=${options?.forceRefresh}",
        );
      }

      // Call the parent method to fetch the session.
      CognitoAuthSession session = await super.fetchAuthSession(
        options: options,
      );

      // Log detailed session information.
      if (enableLogs) {
        dev.log(
          "CustomAuthPlugin: fetchAuthSession(): end options?.forceRefresh=${options?.forceRefresh}, "
          "isSignedIn=${session.isSignedIn}, "
          "accessToken=${session.userPoolTokensResult.valueOrNull?.accessToken}, "
          "idToken=${session.userPoolTokensResult.valueOrNull?.idToken}, "
          "refreshToken=${session.userPoolTokensResult.valueOrNull?.refreshToken}, "
          "identityId=${session.identityIdResult.valueOrNull}, "
          "credentials=${session.credentialsResult.valueOrNull?.accessKeyId}",
        );
      }
      return session;
    } catch (error, stacktrace) {
      dev.log("CustomAuthPlugin: fetchAuthSession(): error=$error");
      Logger.error(
        log: "CustomAuthPlugin: fetchAuthSession() error: $error",
        error: error,
        stacktrace: stacktrace,
      );
      return CognitoAuthSession(
        isSignedIn: false,
        userPoolTokensResult: AWSResult.error(
          UnknownException("timeout during fetchAuthSession call"),
        ),
        userSubResult: AWSResult.error(
          UnknownException("timeout during fetchAuthSession call"),
        ),
        credentialsResult: AWSResult.error(
          UnknownException("timeout during fetchAuthSession call"),
        ),
        identityIdResult: AWSResult.error(
          UnknownException("timeout during fetchAuthSession call"),
        ),
      );
    }
  }
}
