import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  /// An instance of [FirebaseAnalyticsObserver] used to observe navigation events and track screen views in Firebase Analytics.
  ///
  /// This observer enables automatic tracking of screen transitions.
  /// It captures each screen view as users navigate through the app, which can help analyze user engagement, behavior, and popular screens.
  /// Analytics data is collected only in release mode for privacy in development environments.

  static final FirebaseAnalyticsObserver analyticsObserver =
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);

  static Future<void> initialize() async {
    // Initializes Firebase app:
    // NOTE: google services config file should be added to both Android and iOS in order to initialize app.
    // NOTE: On Android verify that you have firebase plugins in android/build.gradle and android/app/build.gradle.
    await Firebase.initializeApp();

    FlutterError.onError = (details) {
      // Record Flutter error to Firebase Crashlytics.
      FirebaseCrashlytics.instance.recordFlutterError(details);

      // Default behaviour to show Flutter error.
      FlutterError.presentError(details);
    };

    // Async exceptions.
    PlatformDispatcher.instance.onError = (error, stack) {
      // Record non fatal error to Firebase Crashlytics.
      FirebaseCrashlytics.instance.recordError(error, stack);
      return true;
    };
  }

  /// Method that initializes crashlytics and analytics services.
  static void initializeFirebaseServices() {
    // Enables automatic crash reporting. Firebase Crashlytics will automatically send events to the server.
    // NOTE: Events are only being sent in a release mode.
    FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(kReleaseMode);

    // Sets custom key to indicate which mode the app is running on.
    // NOTE: Debug crashes and logs can still be sent to the Crashlytics.
    FirebaseCrashlytics.instance.setCustomKey(
      "mode",
      kReleaseMode ? "release" : "debug",
    );

    // Enables automatic analytics reporting. Firebase Analytics will automatically send events to the server.
    // NOTE: Events are only being sent in a release mode in PRODUCTION environment.
    FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(kReleaseMode);
  }
}
