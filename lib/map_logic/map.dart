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
      ),
      body: Center(
        child: Text(
          useCloud ? "Connected to Cloud MQTT" : "Using Local MQTT",
          style: TextStyle(fontSize: 18),
        ),
      ),
      backgroundColor: Colors.blue,
    );
  }
}
