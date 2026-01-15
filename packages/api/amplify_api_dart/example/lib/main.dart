import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:example/amplifyconfiguration.dart';
import 'package:example/providers/test_provider.dart';
import 'package:example/services/custom_auth_plugin.dart';
import 'package:example/services/firebase_service.dart';
import 'package:example/utils/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Amplify.isConfigured) {
    await Future.wait([
      Amplify.addPlugin(CustomAuthPlugin(enableLogs: false)),
      Amplify.addPlugin(AmplifyAPI()),
      Amplify.configure(amplifyconfig),
    ]);

    AmplifyLogger().logLevel = LogLevel.verbose;
  }

  await FirebaseService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      navigatorObservers: [
        /// Firebase Analytics will track how the user is navigating trough the app.
        /// For instance, it tracks which screens users visit, in what order, and how much time they spend on each.
        /// This can give us insights into how users are using the app and which parts of the app are most engaging or need improvement.
        FirebaseService.analyticsObserver,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final int _counter = 0;

  Future<void> _login() async {
    final result = await Amplify.Auth.signIn(
      username: "ispahic+13@buzzerfan.com",
      password: "12345678",
    );

    Logger.log("Login result: ${result.isSignedIn}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: ChangeNotifierProvider(
        create: (context) => TestProvider(),
        lazy: false,
        builder: (context, child) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('You have pushed the button this many times:'),
              Text(
                '$_counter',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _login,
        tooltip: 'Login',
        child: const Icon(Icons.add),
      ),
    );
  }
}
