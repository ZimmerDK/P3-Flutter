import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'services/route_check_api.dart';
import 'config/environment.dart';
import 'models/gps_location_data.dart';
import 'screens/login_screen.dart';
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Mulo GPS Tracker',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: FutureBuilder<bool>(
        future: AuthService().isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          } else if (snapshot.hasData && snapshot.data == true) {
            return const MyHomePage(title: 'Flutter Mulo GPS Tracker Home Page');
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

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
  late final TextEditingController _trackerIdController;

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
  }

  @override
  void dispose() {
    _trackerIdController.dispose();
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
    } catch (e) {
      setState(() { _lastStatus = 'Error: $e'; });
      debugPrint('Error sending coordinate: $e');
    }
  }

  Future<void> _sendLocation(String trackerId, DateTime timestamp, double latitude, double longitude) async {
    final url = Uri.parse('http://localhost:8080/api/route/$trackerId');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'timestamp': DateTime.now().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude
      }),
    );

    if (response.statusCode == 200) {
      print('Location updated successfully.');
    } else {
      print('Failed to update location: ${response.statusCode}');
      print('Response body: ${response.body}');
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
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
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
          children: <Widget>[
            TextFormField(initialValue: url, onFieldSubmitted: (value) { setState(() { url = value; }); }, decoration: const InputDecoration(labelText: 'Ping URL (optional)'),),
            TextFormField(controller: _trackerIdController, onChanged: (value) { setState(() { trackerId = value; }); }, decoration: const InputDecoration(labelText: 'Tracker ID'),),
            TextFormField(initialValue: recordId.toString(), onFieldSubmitted: (value) { final parsed = int.tryParse(value); if (parsed != null) recordId = parsed; }, decoration: const InputDecoration(labelText: 'Next Record ID'),),
            Text('Backend Base URL: ${Environment.effectiveBaseUrl()}'),
            Text("Location update # $_counter: $_location"),
            Text('Last send: ${_lastStatus ?? 'No sends yet'}'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggle,
        tooltip: 'Location Updates',
        child: Icon((isRunning) ? Icons.pause : Icons.play_arrow),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
