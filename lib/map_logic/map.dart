import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:connectivity_plus/connectivity_plus.dart';  // Internet status detection

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MqttServerClient? client;
  bool useCloud = true;  // Initially tries Cloud MQTT
  int retryCount = 0;    // Retry attempts counter
  String latestMessage="No incoming messages from MQTT yet";
  //incoming coords
  double latitude = 0.0;
  double longitude = 0.0;
  double altitude = 0.0;
  double speed = 0.0;
  int satellites = 0;
  String time = "";

  @override
  void initState() {
    super.initState();
    _monitorNetworkChanges(); // Check internet in real time
    _connectToMQTT();
  }

  /// Monitors real-time internet connectivity changes
  void _monitorNetworkChanges() {
  Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
    // Ensure the list is not empty before accessing the first element
    if (results.isNotEmpty) {
      ConnectivityResult result = results.first;

      if (result == ConnectivityResult.none) {
        setState(() {
          useCloud = false;  // No internet, switch to local MQTT
          _connectToMQTT();  // Reconnect immediately
        });
      } else if (result == ConnectivityResult.wifi || result == ConnectivityResult.mobile) {
        setState(() {
          useCloud = true;   // Internet is back, try Cloud MQTT
          _connectToMQTT();  // Reconnect immediately
        });
      }
    }
  });
}

void _listenToMessages() {
  client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
    final MqttPublishMessage recMessage = messages[0].payload as MqttPublishMessage;
    final String payload = MqttPublishPayload.bytesToStringAsString(recMessage.payload.message);

    print("Received MQTT Message: $payload");

   try {
    RegExp regex = RegExp(
      r'LAT\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*LONG\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*ALT\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*SPEED\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*SAT\s*:\s*([0-9]+),\s*TIME\s*:\s*([0-9:]+)',
      caseSensitive: false,
    );

    Match? match = regex.firstMatch(payload);

    if (match != null) {
      double newLatitude = double.parse(match.group(1)!);
      double newLongitude = double.parse(match.group(2)!);
      double newAltitude = double.parse(match.group(3)!);
      double newSpeed = double.parse(match.group(4)!);
      int newSatellites = int.parse(match.group(5)!);
      String newTime = match.group(6)!;

        setState(() {
          latitude = newLatitude;
          longitude = newLongitude;
          altitude = newAltitude;
          speed = newSpeed;
          satellites = newSatellites;
          time = newTime;
        });
    } else {
      print("Regex didn't match, invalid format.");
    }
  } catch (e) {
    print("Error parsing GPS data: $e");
  }
  });
}

void _showGPSCoords(BuildContext context) {
  if (!mounted) return;

  OverlayState overlayState = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: AppBar().preferredSize.height + 10, // Below the AppBar
      right: 10, // Align to right
      child: Material(
        color: Colors.transparent,
        child: StatefulBuilder(
          builder: (context, setPopupState) {
            return Container(
              padding: EdgeInsets.all(10),
              width: 250,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 5),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                  useCloud ? "Connected to Cloud MQTT" : "Using Local MQTT",
                  style: TextStyle(fontSize: 18),),
                  Text("GPS Information", style: TextStyle(fontWeight: FontWeight.bold)),
                  Divider(),
                  Text("Latitude: $latitude"),
                  Text("Longitude: $longitude"),
                  Text("Altitude: $altitude m"),
                  Text("Speed: $speed m/s"),
                  Text("Satellites: $satellites"),
                  Text("Time: $time"),
                  SizedBox(height: 5),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        overlayEntry.remove();
                      },
                      child: Text("Close"),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );

  overlayState.insert(overlayEntry);//inserts the overlayEntry into the Overlay system, making it visible on the screen

  // periodically refresh overlay if widget is still mounted
  Timer.periodic(Duration(seconds: 1), (timer) {
    if (!mounted) {
      timer.cancel();
      overlayEntry.remove();
      return;
    }
    overlayEntry.markNeedsBuild(); // refresh overlay to update values from mqtt, prevents showing the new data
                                  // only if you open and close the info
  });
}



  Future<void> _connectToMQTT() async {
    if (retryCount > 10) {
      print("Max retry attempts reached. Stopping MQTT connection attempts.");
      return;
    }

    String broker = useCloud ? "4e8b407740ce42b18fba5f234af6b314.s1.eu.hivemq.cloud" : "192.168.4.1";

    client = MqttServerClient(broker, "flutter_client");
    client!.port = useCloud ? 8883 : 1883; // TLS (8883) for cloud, Unsecure (1883) for local
    client!.logging(on: true);
    client!.keepAlivePeriod = 60;

    if (useCloud) {
      client!.secure = true;  // enable TLS only for cloud
      client!.onBadCertificate = (dynamic cert) => true; // ignoring SSL certificate errors
    }

    final connMessage = MqttConnectMessage()
        .withClientIdentifier("flutter_client")
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    client!.connectionMessage = connMessage;

    try {
        await client!.connect("Iuli25", "Iuli369147");
        client!.subscribe("gps/tracker", MqttQos.atMostOnce);
        _listenToMessages(); // Start listening to messages
        setState(() {}); // Update UI instantly after connecting
        print("Connected to MQTT: $broker");
         } catch (e) {
        print("Did not connect to MQTT: $e");
        setState(() {
          useCloud = false; // Switch to local mode immediately
          retryCount++;
        });
        Future.delayed(Duration(seconds: 3), _connectToMQTT); // Retry after 3 sec
        }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  appBar: AppBar(
    title: Text("GPS Tracker"),
    automaticallyImplyLeading: true,
    backgroundColor: const Color.fromARGB(255, 196, 175, 254),
    actions: [
      IconButton(
        icon: Icon(Icons.info_outline),
        onPressed: () {
          _showGPSCoords(context);
        },
      ),
],

  ),
);

  }
}

