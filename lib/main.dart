import 'dart:async';
// No JSON import required here; add `import 'dart:convert';` if needed later.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
// 'http' import currently unused; keep it commented in case you need direct HTTP calls later.
// import 'package:http/http.dart' as http;
import 'services/route_check_api.dart';
import 'services/offline_queue_service.dart';
import 'config/environment.dart';
import 'models/gps_location_data.dart';
import 'screens/login_screen.dart';
import 'screens/about_screen.dart';
import 'services/auth_service.dart';

/// Determine the current position of the device.
///
/// When the location services are not enabled or permissions
/// are denied the `Future` will return an error.
Future<Position> _determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the 
    // App to enable the location services.
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale 
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      return Future.error('Location permissions are denied');
    }
  }
  
  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately. 
    return Future.error(
      'Location permissions are permanently denied, we cannot request permissions.');
  } 

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  return await Geolocator.getCurrentPosition();
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    // Load saved theme preference (defaults to light)
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getBool('isDark') ?? false;
      setState(() {
        _themeMode = saved ? ThemeMode.dark : ThemeMode.light;
      });
      debugPrint('MyAppState: loaded isDark=$saved');
    });
  }

  // Public setter so other widgets can toggle theme (e.g. LoginScreen)
  void setDark(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
    // Persist preference in background so callers don't need to await.
    SharedPreferences.getInstance().then((prefs) async {
      try {
        final ok = await prefs.setBool('isDark', isDark);
        final readBack = prefs.getBool('isDark');
        debugPrint('MyAppState: saved isDark=$isDark (ok=$ok) readBack=$readBack');
      } catch (e) {
        debugPrint('MyAppState: failed to save isDark=$isDark -> $e');
      }
    }).catchError((e) { debugPrint('MyAppState: SharedPreferences.getInstance() failed -> $e'); return null; });
  }

  // Public getter for current dark state
  bool get isDark => _themeMode == ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Mulo GPS Tracker App',
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFCB3231), titleTextStyle: TextStyle(color: Colors.white)),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF212121),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFCB3231), titleTextStyle: TextStyle(color: Colors.white)),
      ),
      home: FutureBuilder<bool>(
        future: AuthService().isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          } else if (snapshot.hasData && snapshot.data == true) {
            return MyHomePage(title: 'Flutter Mulo GPS Tracker App', isDark: isDark, onThemeChanged: setDark);
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.isDark, required this.onThemeChanged});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  int _counter = 0;
  String url = "https://mulo.dk/";
  Position? _location;
  bool isRunning = false;
  Timer? restart;
  String trackerId = 'Six7';
  int recordId = 1; // Incremental id for demo; replace with real source if needed.
  final RouteCheckApi _api = RouteCheckApi();
  String? _lastStatus; // Holds last POST status/info
  int _queuedCount = 0; // Number of queued points
  late final TextEditingController _trackerIdController;
  late final TextEditingController _pingUrlController;


  void _toggle() {
    // toggle running state
    if (isRunning) {
      setState(() { isRunning = false; });
      restart?.cancel();
    } else {
      setState(() { isRunning = true; });
      _getLocation();
    }
  }

  @override
  void initState() {
    super.initState();
    _trackerIdController = TextEditingController(text: trackerId);
    _pingUrlController = TextEditingController(text: url);
    _refreshQueuedCount();
  }

  @override
  void dispose() {
    _trackerIdController.dispose();
    _pingUrlController.dispose();
    super.dispose();
  }

  Future<void> _sendCoordinate(Position pos) async {
    try {
      final data = GPSLocationData(
        id: recordId++,
        timestamp: pos.timestamp, // Position.timestamp is non-null per SDK
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      final response = await _api.sendLocationData(trackerId: trackerId, data: data);
      setState(() {
        _lastStatus = (response.statusCode >= 200 && response.statusCode < 300)
            ? 'Success ${response.statusCode}'
            : 'Fail ${response.statusCode}: ${response.body}';
      });
      if(_lastStatus == 'Success ${response.statusCode}') {
        _counter++;
      }
      debugPrint('Send status ${response.statusCode}');
      _refreshQueuedCount();
    } catch (e) {
      setState(() { _lastStatus = 'Error: $e'; });
      debugPrint('Error sending coordinate: $e');
      _refreshQueuedCount();
    }
  }

  Future<void> _refreshQueuedCount() async {
    try {
      final count = await OfflineQueueService().getCount();
      if (mounted) {
        setState(() {
          _queuedCount = count;
        });
      }
    } catch (e) {
      debugPrint('Failed to get queued count: $e');
    }
  }

  void _getLocation() {
    // query position (will return a Future)
    Future<Position> pos = _determinePosition();

    // when the future is resolved:
    pos.then(
      (value) { 
        debugPrint(value.toString()); 
        setState(() {
          _location = value;
        });
        //_sendLocation(trackerId, value.timestamp, value.latitude, value.longitude); // send to backend
        _sendCoordinate(value); // send to backend
      }
    );
    debugPrint("_getLocation done");

    // restart in 5 seconds
    restart = Timer(const Duration(seconds: 5), _getLocation);
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF212121),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            color: Colors.white,
            tooltip: 'About',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
        ],
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            TextFormField(
              controller: _pingUrlController,
              readOnly: true,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: 'Ping URL (read-only)', floatingLabelAlignment: FloatingLabelAlignment.center),
            ),
            TextFormField(
              controller: _trackerIdController,
              onChanged: (value) { setState(() { trackerId = value; }); },
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: 'Tracker ID', floatingLabelAlignment: FloatingLabelAlignment.center),
            ),
            Text('Backend Base URL: ${Environment.effectiveBaseUrl()}', textAlign: TextAlign.center,),
            Text('Location update # $_counter\n$_location', textAlign: TextAlign.center,),
            Text('Last send: ${_lastStatus ?? 'No sends yet'}', textAlign: TextAlign.center,),
            Text('Queued points: $_queuedCount', textAlign: TextAlign.center,),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _toggle,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCB3231),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(isRunning ? 'STOP TRACKING' : 'START TRACKING'),
          ),
        ),
      ),
    );
  }
}
