import 'package:example/utils/logger/logger.dart';
import 'package:flutter/material.dart';

/// Mixin for handling app lifecycle events.
/// Implement all necessary logic for events in the corresponding method.
/// For more documentation about specific events see [https://api.flutter.dev/flutter/widgets/AppLifecycleListener-class.html].
mixin AppLifecycleMixin on ChangeNotifier {
  AppLifecycleListener? appLifecycleListener;

  AppLifecycleState? appLifecycleState;

  /// This must be called in the constructor of the provider extending this mixin.
  ///
  /// Calls the [onInitState] method and initializes the [appLifecycleListener].
  void initLifecycleListener() {
    onInitState();
    appLifecycleListener?.dispose();
    appLifecycleListener = AppLifecycleListener(
      onResume: onResumed,
      onPause: onPaused,
      onDetach: onDetach,
      onInactive: onInactive,
      onHide: onHide,
      onRestart: onRestart,
      onShow: onShow,
      onStateChange: onStateChange,
    );
  }

  /// This must be called in the dispose method of the provider extending this mixin.
  ///
  /// Disposes the [appLifecycleListener].
  void disposeLifecycleListener() {
    Logger.log("notifierName=${runtimeType.toString()}");
    appLifecycleListener?.dispose();
    appLifecycleListener = null;
  }

  /// A callback that is called only once when the provider is initialized.
  @mustCallSuper
  void onInitState() {
    Logger.log("notifierName=${runtimeType.toString()}");
  }

  /// A callback that is called when a view in the application gains input focus.
  @mustCallSuper
  void onResumed() async {
    Logger.log("notifierName=${runtimeType.toString()}");
  }

  /// A callback that is called when the application is paused.
  @mustCallSuper
  void onPaused() {
    Logger.log("notifierName=${runtimeType.toString()}");
  }

  /// A callback that is called when an application has exited, and detached all host views from the engine.
  @mustCallSuper
  void onDetach() {
    Logger.log("notifierName=${runtimeType.toString()}");
  }

  /// A callback that is called when the application is resumed after being paused.
  @mustCallSuper
  void onRestart() {
    Logger.log("notifierName=${runtimeType.toString()}");
  }

  /// A callback that is called when the application is hidden.
  @mustCallSuper
  void onHide() {
    Logger.log("notifierName=${runtimeType.toString()}");
  }

  /// A callback that is called when the application is shown.
  @mustCallSuper
  void onShow() {
    Logger.log("notifierName=${runtimeType.toString()}");
  }

  /// A callback that is called when the application loses input focus.
  @mustCallSuper
  void onInactive() {
    Logger.log("notifierName=${runtimeType.toString()}");
  }

  /// Called anytime the state changes, passing the new state.
  @mustCallSuper
  void onStateChange(AppLifecycleState state) {
    appLifecycleState = state;
    Logger.log("state=$state, notifierName=${runtimeType.toString()}");
  }
}
