// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';

import 'package:amplify_api_dart/src/graphql/web_socket/blocs/web_socket_bloc.dart';
import 'package:amplify_api_dart/src/graphql/web_socket/state/web_socket_state.dart';
import 'package:amplify_api_dart/src/graphql/web_socket/types/connectivity_platform.dart';
import 'package:amplify_api_dart/src/graphql/web_socket/types/process_life_cycle.dart';
import 'package:amplify_api_dart/src/graphql/web_socket/types/web_socket_types.dart';
import 'package:amplify_core/amplify_core.dart';
import 'package:test/test.dart';

import '../util.dart';

const mockConnectionAck = ConnectionAckMessageEvent(
  ConnectionAckMessagePayload(300000),
);

void main() {
  late WebSocketBloc? bloc;
  late MockWebSocketService? service;

  late MockPollClient mockPollClient;

  const graphQLDocument = '''subscription MySubscription {
    onCreateBlog {
      id
      name
      createdAt
    }
  }''';
  final subscriptionRequest = GraphQLRequest<String>(document: graphQLDocument);

  final mockSubscriptionData = {
    'onCreateBlog': {
      'id': '<blog id>',
      'name': 'Unit Test Blog',
      'createdAt': '2022-09-12T18:03:36.230Z',
    },
  };

  final mockDataString = jsonEncode({
    'id': subscriptionRequest.id,
    'type': 'data',
    'payload': {'data': mockSubscriptionData},
  });

  const subscriptionOptions = GraphQLSubscriptionOptions(
    pollInterval: Duration(seconds: 1),
  );

  WebSocketBloc getWebSocketBloc({
    bool noConnectivity = false,
    int? connectionTimeoutMs,
  }) {
    if (!noConnectivity) {
      mockNetworkStreamController = StreamController<ConnectivityStatus>();
    }
    mockProcessLifeCycleController = StreamController<ProcessStatus>();
    mockPollClient = MockPollClient();
    service = MockWebSocketService();

    bloc = WebSocketBloc(
      config: testApiKeyConfig,
      authProviderRepo: getTestAuthProviderRepo(),
      wsService: service!,
      subscriptionOptions: subscriptionOptions,
      pollClientOverride: mockPollClient.client,
      connectivity: noConnectivity
          ? const ConnectivityPlatform()
          : const MockConnectivity(),
      processLifeCycle: const MockProcessLifeCycle(),
    );

    sendMockConnectionAck(
      bloc!,
      service!,
      connectionTimeoutMs: connectionTimeoutMs,
    );
    sendMockStartAck(bloc!, service!, [subscriptionRequest.id]);

    return bloc!;
  }

  group('WebSocketBloc', () {
    group('non self closing tests', () {
      tearDown(() async {
        bloc!.add(const ShutdownEvent());
        await bloc!.done.future;
        bloc = null;
        service = null; // service gets closed in  bloc
        if (mockNetworkStreamController.hasListener) {
          await mockNetworkStreamController.close();
        }
      });

      test('should init a connection & call onEstablishCallback', () async {
        final subscribeEvent = SubscribeEvent(
          subscriptionRequest,
          expectAsync0(() {}),
        );

        getWebSocketBloc().subscribe(subscribeEvent);
      });

      test('subscribe() should return a subscription stream', () async {
        final dataCompleter = Completer<String>();
        final subscribeEvent = SubscribeEvent(subscriptionRequest, () {
          service!.channel.sink.add(mockDataString);
        });

        final bloc = getWebSocketBloc();
        bloc
            .subscribe(subscribeEvent)
            .listen(
              expectAsync1((event) {
                expect(event.data, json.encode(mockSubscriptionData));
                dataCompleter.complete(event.data);
              }),
            );

        await dataCompleter.future;
      });

      test(
        'should return a subscription stream with default connectivity (empty stream)',
        () async {
          final dataCompleter = Completer<String>();
          final subscribeEvent = SubscribeEvent(subscriptionRequest, () {
            service!.channel.sink.add(mockDataString);
          });

          final bloc = getWebSocketBloc(noConnectivity: true);
          bloc
              .subscribe(subscribeEvent)
              .listen(
                expectAsync1((event) {
                  expect(event.data, json.encode(mockSubscriptionData));
                  dataCompleter.complete(event.data);
                }),
              );
          await dataCompleter.future;
        },
      );
    });

    test('should reconnect when data turns on/off', () async {
      var dataCompleter = Completer<String>();
      final subscribeEvent = SubscribeEvent(subscriptionRequest, () {
        service!.channel.sink.add(mockDataString);
      });

      final bloc = getWebSocketBloc();

      expect(
        bloc.stream,
        emitsInOrder([
          isA<DisconnectedState>(),
          isA<ConnectingState>(),
          isA<ConnectedState>(),
          isA<ReconnectingState>(),
          isA<ConnectingState>(),
          isA<ConnectedState>(),
        ]),
      );

      bloc
          .subscribe(subscribeEvent)
          .listen(
            expectAsync1((event) {
              expect(event.data, json.encode(mockSubscriptionData));
              dataCompleter.complete(event.data);
            }, count: 2),
          );

      await dataCompleter.future;
      dataCompleter = Completer<String>();

      mockNetworkStreamController
        ..add(ConnectivityStatus.disconnected)
        ..add(ConnectivityStatus.connected);

      await expectLater(bloc.stream, emitsThrough(isA<ConnectedState>()));

      service!.channel.sink.add(mockDataString);
      await dataCompleter.future;
    });

    test(
      'delivers incoming subscription data while a reconnect is in progress',
      () async {
        final firstData = Completer<String>();
        final dataDuringReconnect = Completer<String>();

        final subscribeEvent = SubscribeEvent(subscriptionRequest, () {
          service!.channel.sink.add(mockDataString);
        });

        final bloc = getWebSocketBloc();
        bloc.subscribe(subscribeEvent).listen((event) {
          if (!firstData.isCompleted) {
            firstData.complete(event.data);
          } else if (!dataDuringReconnect.isCompleted) {
            dataDuringReconnect.complete(event.data);
          }
        });

        expect(await firstData.future, json.encode(mockSubscriptionData));

        mockPollClient.induceTimeout = true;
        mockNetworkStreamController.add(ConnectivityStatus.disconnected);
        await expectLater(bloc.stream, emitsThrough(isA<ReconnectingState>()));

        service!.channel.sink.add(mockDataString);

        final data = await dataDuringReconnect.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () => throw TimeoutException(
            'Subscription data was not delivered while a reconnect was in '
            'progress.',
          ),
        );
        expect(data, json.encode(mockSubscriptionData));

        mockPollClient.induceTimeout = false;
      },
    );

    test('shuts down cleanly while a reconnect is in progress', () async {
      final established = Completer<void>();
      final bloc = getWebSocketBloc();
      bloc
          .subscribe(SubscribeEvent(subscriptionRequest, established.complete))
          .listen((_) {}, onError: (_) {});
      await established.future;

      mockPollClient.induceTimeout = true;
      mockNetworkStreamController.add(ConnectivityStatus.disconnected);
      await expectLater(bloc.stream, emitsThrough(isA<ReconnectingState>()));

      bloc.add(const ShutdownEvent());
      await bloc.done.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw TimeoutException(
          'Shutdown was blocked by an in-progress reconnect.',
        ),
      );

      mockPollClient.induceTimeout = false;
      await Future<void>.delayed(const Duration(seconds: 7));
      expect(bloc.done.isCompleted, isTrue);
    });

    test('should throttle reconnect after repeated wifi toggling', () async {
      final blocReady = Completer<void>();
      final subscribeEvent = SubscribeEvent(
        subscriptionRequest,
        blocReady.complete,
      );

      final bloc = getWebSocketBloc();

      expect(
        bloc.stream,
        emitsInOrder([
          isA<DisconnectedState>(),
          isA<ConnectingState>(),
          isA<ConnectedState>(),
          isA<ReconnectingState>(),
          isA<ConnectingState>(),
          isA<ConnectedState>(),
        ]),
        reason:
            'Bloc should debounce multiple reconnection triggers while reconnecting.',
      );

      bloc.subscribe(subscribeEvent);

      await blocReady.future;

      mockNetworkStreamController
        ..add(ConnectivityStatus.disconnected)
        ..add(ConnectivityStatus.connected)
        ..add(ConnectivityStatus.disconnected)
        ..add(ConnectivityStatus.connected)
        ..add(ConnectivityStatus.disconnected)
        ..add(ConnectivityStatus.connected)
        ..add(ConnectivityStatus.disconnected)
        ..add(ConnectivityStatus.connected)
        ..add(ConnectivityStatus.disconnected)
        ..add(ConnectivityStatus.connected);
    });

    test('should reconnect multiple times after reconnecting', () async {
      final blocReady = Completer<void>();
      final subscribeEvent = SubscribeEvent(
        subscriptionRequest,
        blocReady.complete,
      );

      final bloc = getWebSocketBloc()..subscribe(subscribeEvent);

      await blocReady.future;

      mockNetworkStreamController.add(ConnectivityStatus.disconnected);

      await expectLater(bloc.stream, emitsThrough(isA<ReconnectingState>()));

      mockNetworkStreamController.add(ConnectivityStatus.connected);

      await expectLater(bloc.stream, emitsThrough(isA<ConnectedState>()));

      mockNetworkStreamController.add(ConnectivityStatus.disconnected);

      await expectLater(bloc.stream, emitsThrough(isA<ReconnectingState>()));

      mockNetworkStreamController.add(ConnectivityStatus.connected);

      await expectLater(bloc.stream, emitsThrough(isA<ConnectedState>()));

      mockNetworkStreamController.add(ConnectivityStatus.disconnected);

      await expectLater(bloc.stream, emitsThrough(isA<ReconnectingState>()));

      mockNetworkStreamController.add(ConnectivityStatus.connected);

      await expectLater(bloc.stream, emitsThrough(isA<ConnectedState>()));
    });

    test('should reconnect after 13 seconds during retry/back off', () async {
      final subscribeEvent = SubscribeEvent(subscriptionRequest, () {
        service!.channel.sink.add(mockDataString);
      });

      final bloc = getWebSocketBloc()..subscribe(subscribeEvent);

      expect(
        bloc.stream,
        emitsInOrder([
          isA<DisconnectedState>(),
          isA<ConnectingState>(),
          isA<ConnectedState>(),
          isA<ReconnectingState>(),
          isA<ConnectingState>(),
          isA<ConnectedState>(),
        ]),
      );

      mockPollClient.induceTimeout = true;

      await Future<void>.delayed(const Duration(seconds: 13));

      mockPollClient.induceTimeout = false;
    });

    test('should keep a working connection when process resumes', () async {
      var dataCompleter = Completer<String>();
      final subscribeEvent = SubscribeEvent(subscriptionRequest, () {
        service!.channel.sink.add(mockDataString);
      });

      final bloc = getWebSocketBloc();
      final states = <WebSocketState>[];
      bloc.stream.listen(states.add);

      bloc
          .subscribe(subscribeEvent)
          .listen(
            expectAsync1((event) {
              expect(event.data, json.encode(mockSubscriptionData));
              dataCompleter.complete(event.data);
            }, count: 2),
          );

      await dataCompleter.future;
      dataCompleter = Completer<String>();
      final channel = service!.channel;

      mockProcessLifeCycleController
        ..add(ProcessStatus.paused)
        ..add(ProcessStatus.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(service!.verifyConnectionCount, 1);
      expect(
        states,
        isNot(contains(isA<ReconnectingState>())),
        reason: 'A working connection should not be replaced on resume.',
      );
      expect(bloc.currentState, isA<ConnectedState>());
      expect(service!.channel, same(channel));

      service!.channel.sink.add(mockDataString);
      await dataCompleter.future;
    });

    test(
      'should reconnect when process resumes and the connection is broken',
      () async {
        var dataCompleter = Completer<String>();
        final subscribeEvent = SubscribeEvent(subscriptionRequest, () {
          service!.channel.sink.add(mockDataString);
        });

        final bloc = getWebSocketBloc();

        expect(
          bloc.stream,
          emitsInOrder([
            isA<DisconnectedState>(),
            isA<ConnectingState>(),
            isA<ConnectedState>(),
            isA<ReconnectingState>(),
            isA<ConnectingState>(),
            isA<ConnectedState>(),
          ]),
        );

        bloc
            .subscribe(subscribeEvent)
            .listen(
              expectAsync1((event) {
                expect(event.data, json.encode(mockSubscriptionData));
                dataCompleter.complete(event.data);
              }, count: 2),
            );

        await dataCompleter.future;
        dataCompleter = Completer<String>();

        service!.isConnectionBroken = true;
        mockProcessLifeCycleController
          ..add(ProcessStatus.paused)
          ..add(ProcessStatus.resumed);

        await expectLater(bloc.stream, emitsThrough(isA<ReconnectingState>()));
        await expectLater(bloc.stream, emitsThrough(isA<ConnectedState>()));

        service!.channel.sink.add(mockDataString);
        await dataCompleter.future;
      },
    );

    test('should reconnect when the connection closes unexpectedly', () async {
      var dataCompleter = Completer<String>();
      final subscribeEvent = SubscribeEvent(subscriptionRequest, () {
        service!.channel.sink.add(mockDataString);
      });

      final bloc = getWebSocketBloc();
      final states = <WebSocketState>[];
      bloc.stream.listen(states.add);

      bloc
          .subscribe(subscribeEvent)
          .listen(
            expectAsync1((event) {
              expect(event.data, json.encode(mockSubscriptionData));
              dataCompleter.complete(event.data);
            }, count: 2),
          );

      await dataCompleter.future;
      dataCompleter = Completer<String>();

      service!.dropConnection();

      await expectLater(bloc.stream, emitsThrough(isA<ConnectedState>()));
      // The bloc closes the dropped connection itself while reconnecting,
      // which must not start another reconnection.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(states.whereType<ReconnectingState>(), hasLength(1));
      expect(bloc.currentState, isA<ConnectedState>());

      service!.channel.sink.add(mockDataString);
      await dataCompleter.future;
    });

    test(
      'should verify instead of failing when keep alive times out after a pause',
      () async {
        final blocReady = Completer<void>();
        final bloc = getWebSocketBloc(connectionTimeoutMs: 300);
        final states = <WebSocketState>[];
        bloc.stream.listen(states.add);
        bloc
            .subscribe(SubscribeEvent(subscriptionRequest, blocReady.complete))
            .listen(null, onError: (_) {});
        await blocReady.future;

        // The process is frozen past the keep alive timeout.
        mockProcessLifeCycleController.add(ProcessStatus.paused);
        await Future<void>.delayed(const Duration(milliseconds: 450));

        expect(service!.verifyConnectionCount, 1);
        expect(bloc.currentState, isA<ConnectedState>());
        expect(states, isNot(contains(isA<FailureState>())));

        // Without another pause, a missing keep alive still fails as before.
        await expectLater(bloc.stream, emitsThrough(isA<FailureState>()));
      },
    );

    test('should reconnect when keep alive times out after a pause and the '
        'connection is broken', () async {
      final blocReady = Completer<void>();
      final bloc = getWebSocketBloc(connectionTimeoutMs: 300);
      bloc
          .subscribe(SubscribeEvent(subscriptionRequest, blocReady.complete))
          .listen(null, onError: (_) {});
      await blocReady.future;

      service!.isConnectionBroken = true;
      mockProcessLifeCycleController.add(ProcessStatus.paused);

      await expectLater(bloc.stream, emitsThrough(isA<ReconnectingState>()));
      await expectLater(bloc.stream, emitsThrough(isA<ConnectedState>()));
    });

    test(
      'should retry a pending reconnection right away when process resumes',
      () async {
        final blocReady = Completer<void>();
        final bloc = getWebSocketBloc();
        bloc
            .subscribe(SubscribeEvent(subscriptionRequest, blocReady.complete))
            .listen(null, onError: (_) {});
        await blocReady.future;

        // The network is blocked while the process is in the background, so
        // the reconnection is still waiting for its first poll to time out.
        mockPollClient.induceTimeout = true;
        mockProcessLifeCycleController.add(ProcessStatus.paused);
        service!.dropConnection();
        await expectLater(bloc.stream, emitsThrough(isA<ReconnectingState>()));
        await Future<void>.delayed(const Duration(milliseconds: 500));

        mockPollClient.induceTimeout = false;
        final stopwatch = Stopwatch()..start();
        mockProcessLifeCycleController.add(ProcessStatus.resumed);

        await expectLater(bloc.stream, emitsThrough(isA<ConnectedState>()));
        expect(
          stopwatch.elapsed,
          lessThan(const Duration(seconds: 2)),
          reason: 'The poll in flight times out only after 5 seconds.',
        );
        // The replaced reconnection must not start another connection.
        await Future<void>.delayed(const Duration(seconds: 6));
        expect(bloc.currentState, isA<ConnectedState>());
      },
    );

    test('should not poll while the process is paused', () async {
      final blocReady = Completer<void>();
      final bloc = getWebSocketBloc();
      final states = <WebSocketState>[];
      bloc.stream.listen(states.add);
      bloc
          .subscribe(SubscribeEvent(subscriptionRequest, blocReady.complete))
          .listen(null, onError: (_) {});
      await blocReady.future;

      mockProcessLifeCycleController.add(ProcessStatus.paused);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // Every poll would time out.
      mockPollClient.induceTimeout = true;
      await Future<void>.delayed(const Duration(seconds: 7));

      expect(states, isNot(contains(isA<ReconnectingState>())));
      expect(bloc.currentState, isA<ConnectedState>());
      mockPollClient.induceTimeout = false;
    });

    test('should ignore a poll that fails across a pause', () async {
      final blocReady = Completer<void>();
      final bloc = getWebSocketBloc();
      final states = <WebSocketState>[];
      bloc.stream.listen(states.add);
      bloc
          .subscribe(SubscribeEvent(subscriptionRequest, blocReady.complete))
          .listen(null, onError: (_) {});
      await blocReady.future;

      // A poll is in flight when the OS suspends the process; its timeout
      // expires right after the process resumes.
      mockPollClient.induceTimeout = true;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      mockPollClient.induceTimeout = false;
      mockProcessLifeCycleController
        ..add(ProcessStatus.paused)
        ..add(ProcessStatus.resumed);
      await Future<void>.delayed(const Duration(seconds: 6));

      expect(states, isNot(contains(isA<ReconnectingState>())));
      expect(bloc.currentState, isA<ConnectedState>());
      expect(service!.verifyConnectionCount, 1);
    });

    test('should reconnect once after repeatedly resuming', () async {
      final blocReady = Completer<void>();
      final subscribeEvent = SubscribeEvent(
        subscriptionRequest,
        blocReady.complete,
      );

      final bloc = getWebSocketBloc();

      expect(
        bloc.stream,
        emitsInOrder([
          isA<DisconnectedState>(),
          isA<ConnectingState>(),
          isA<ConnectedState>(),
          isA<ReconnectingState>(),
          isA<ConnectingState>(),
          isA<ConnectedState>(),
        ]),
        reason:
            'Bloc should debounce multiple reconnection triggers while resuming.',
      );

      bloc.subscribe(subscribeEvent);

      await blocReady.future;

      service!.isConnectionBroken = true;
      mockProcessLifeCycleController
        ..add(ProcessStatus.paused)
        ..add(ProcessStatus.resumed)
        ..add(ProcessStatus.paused)
        ..add(ProcessStatus.resumed)
        ..add(ProcessStatus.paused)
        ..add(ProcessStatus.resumed)
        ..add(ProcessStatus.paused)
        ..add(ProcessStatus.resumed)
        ..add(ProcessStatus.paused)
        ..add(ProcessStatus.resumed);
    });

    test('should reconnect multiple times after resuming', () async {
      final blocReady = Completer<void>();
      final subscribeEvent = SubscribeEvent(
        subscriptionRequest,
        blocReady.complete,
      );

      final bloc = getWebSocketBloc()..subscribe(subscribeEvent);

      await blocReady.future;
      service!.isConnectionBroken = true;

      for (var i = 0; i < 3; i++) {
        mockProcessLifeCycleController
          ..add(ProcessStatus.paused)
          ..add(ProcessStatus.resumed);

        await expectLater(bloc.stream, emitsThrough(isA<ReconnectingState>()));

        mockProcessLifeCycleController
          ..add(ProcessStatus.paused)
          ..add(ProcessStatus.resumed);

        await expectLater(bloc.stream, emitsThrough(isA<ConnectedState>()));
        // The new connection is broken as well.
        service!.isConnectionBroken = true;
      }
    });

    test(
      'subscribe() ignores a WebSocket message that comes while the bloc is disconnected',
      () async {
        final establishCompleter = Completer<void>();
        final subscribeEvent = SubscribeEvent(
          subscriptionRequest,
          establishCompleter.complete,
        );

        final bloc = getWebSocketBloc();
        bloc.subscribe(subscribeEvent).listen(null);
        await establishCompleter.future;

        bloc.add(const ShutdownEvent());
        await bloc.done.future;

        service!.channel.sink.add(mockDataString);
        await expectLater(service!.channel.sink.done, completes);
      },
    );

    group('should close when', () {
      tearDown(() async {
        bloc = null;
        service = null; // service gets closed in  bloc
      });
      test('triggering FailureState on Exception during init', () async {
        final subscribeEvent = SubscribeEvent(subscriptionRequest, () {
          service!.channel.sink.add(mockDataString);
        });

        final badService = MockWebSocketService(badInit: true);
        mockNetworkStreamController = StreamController<ConnectivityStatus>();
        mockProcessLifeCycleController = StreamController<ProcessStatus>();
        final bloc = WebSocketBloc(
          config: testApiKeyConfig,
          authProviderRepo: getTestAuthProviderRepo(),
          wsService: badService,
          subscriptionOptions: subscriptionOptions,
          pollClientOverride: mockPollClient.client,
          connectivity: const MockConnectivity(),
          processLifeCycle: const MockProcessLifeCycle(),
        );

        expect(
          bloc.stream,
          emitsInOrder([
            isA<DisconnectedState>(),
            isA<ConnectingState>(),
            isA<FailureState>(),
            isA<PendingDisconnect>(),
            isA<DisconnectedState>(),
          ]),
        );

        bloc.subscribe(subscribeEvent);
        // TODO(equartey): Fix this test on web
      }, skip: zIsWeb);

      test('Exception from service and should return error to user', () async {
        final subscribeEvent = SubscribeEvent(subscriptionRequest, () {
          service!.channel.sink.addError(Exception('unknown exception'));
        });
        final bloc = getWebSocketBloc();

        expect(
          bloc.stream,
          emitsInOrder([
            isA<DisconnectedState>(),
            isA<ConnectingState>(),
            isA<ConnectedState>(),
            isA<FailureState>(),
            isA<PendingDisconnect>(),
            isA<DisconnectedState>(),
          ]),
        );

        final subscription = bloc.subscribe(subscribeEvent);
        expect(subscription, emitsError(isA<ApiException>()));
      });

      test('an exception when poll responds unhealthy', () async {
        final blocReady = Completer<void>();
        final subscribeEvent = SubscribeEvent(
          subscriptionRequest,
          blocReady.complete,
        );
        final bloc = getWebSocketBloc();

        expect(
          bloc.stream,
          emitsInOrder([
            isA<DisconnectedState>(),
            isA<ConnectingState>(),
            isA<ConnectedState>(),
            isA<ReconnectingState>(),
            isA<FailureState>(),
            isA<PendingDisconnect>(),
            isA<DisconnectedState>(),
          ]),
        );

        bloc
            .subscribe(subscribeEvent)
            .listen(
              null,
              onError: expectAsync1((event) {
                expect(event, isA<ApiException>());
              }),
            );

        await blocReady.future;
        mockPollClient.sendUnhealthyResponse = true;
      });

      test('cancel() sends a stop message', () async {
        final subscribeEvent = SubscribeEvent(subscriptionRequest, () {
          service!.channel.sink.add(mockDataString);
        });

        final dataCompleter = Completer<String>();
        final bloc = getWebSocketBloc();
        final subscription = bloc.subscribe(subscribeEvent);

        final streamSub = subscription.listen(
          (event) => dataCompleter.complete(event.data),
        );

        await dataCompleter.future;

        expect(
          service!.channel.stream,
          emitsInOrder([
            isA<String>().having(
              (event) => json.decode(event),
              'web socket stop message',
              containsPair('type', 'stop'),
            ),
            isA<String>().having(
              (event) => json.decode(event),
              'web socket complete message',
              containsPair('type', 'complete'),
            ),
          ]),
        );
        // bloc should disconnect due to no active subscriptions
        expect(bloc.stream, emitsThrough(isA<DisconnectedState>()));

        await streamSub.cancel();

        await bloc.done.future;
      });

      test('a process resumes with autoReconnect disabled', () async {
        final blocReady = Completer<void>();
        final subscribeEvent = SubscribeEvent(
          subscriptionRequest,
          blocReady.complete,
        );
        final bloc = getWebSocketBloc();

        expect(
          bloc.stream,
          emitsInOrder([
            isA<DisconnectedState>(),
            isA<ConnectingState>(),
            isA<ConnectedState>(),
            isA<FailureState>(),
            isA<PendingDisconnect>(),
            isA<DisconnectedState>(),
          ]),
        );

        // ignore: invalid_use_of_internal_member
        WebSocketOptions.autoReconnect = false;

        bloc
            .subscribe(subscribeEvent)
            .listen(
              null,
              onError: expectAsync1((event) {
                expect(event, isA<ApiException>());
              }),
            );

        await blocReady.future;

        mockProcessLifeCycleController
          ..add(ProcessStatus.paused)
          ..add(ProcessStatus.resumed);
      });
    });
  });
}
