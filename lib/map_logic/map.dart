import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animarker/flutter_map_marker_animation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Internet status detection
import 'package:pet_watch/map_logic/help_page.dart';
import 'package:pet_watch/map_logic/services/storage_service.dart';
import 'package:pet_watch/map_logic/geofence_manager.dart';
import 'package:pet_watch/map_logic/map_functions.dart';
import 'package:pet_watch/map_logic/services/custom-notification.dart';
import 'package:pet_watch/map_logic/services/notification_service.dart';
import 'package:pet_watch/map_logic/widgets/floating_buttons_panel.dart';
import 'package:pet_watch/map_logic/widgets/marker_functions.dart';
import 'package:pet_watch/map_logic/widgets/notifications_list_page.dart';
import 'package:pet_watch/map_logic/widgets/stat_card_window.dart';
import 'package:pet_watch/map_logic/widgets/weather_info_box.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

class MapPage extends StatefulWidget {
  final String petName;
  final String petImageUrl;
  final LatLng initialLocation;
  final String petId;

  const MapPage({
    super.key,
    required this.petId,
    required this.petName,
    required this.petImageUrl,
    required this.initialLocation,
  });
  // const MapPage({super.key, required this.petName, required this.petImageUrl});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  List<CustomNotification> notifications = [];

  List<LatLng> petPath = [];
  final Map<PolylineId, Polyline> _polylines = {};
  final storageService = StorageService();
  final user = FirebaseAuth.instance.currentUser!;
  MqttServerClient? client;

  WebSocketChannel? wsChannel;
  StreamSubscription?
      wsSubscription; //pentru folosirea WebSocket cand receptorul nu are acces la internet pt primirea datelor gps
  final GlobalKey _mapBoundaryKey = GlobalKey();

  double totalDistance = 0.0;
  final double cameraBufferZone = 0.00002;
  String? previousState;
  int stateRepeatCount = 0;
  DateTime? outStartTime;
  Duration totalOutDuration = Duration.zero;
  bool isPetHome = true;
  int geofenceExitCount = 0;
  bool useCloud = true; // Initially tries Cloud MQTT
  int retryCount = 0; // Retry attempts counter
  String latestMessage = "No incoming messages from MQTT yet";
  //incoming coords
  double latitude = 0.0;
  double longitude = 0.0;
  double altitude = 0.0;
  double speed = 0.0;
  int satellites = 0;
  String time = "";
  // LatLng initialLocation = LatLng(45.7235054321469, 21.250409338816176);
  late GoogleMapController mapController;
  final Map<String, Marker> _markers = {};
  final Map<String, Marker> _markersEvent = {};
  Color markerColor = Colors.red; //default color
  String? selectedMarkerId;
  LatLng? selectedMarkerPosition;
  String selectedPetImage = "";
  bool canConnect = true;
  final GeofenceManager geofenceManager = GeofenceManager();
  bool isSettingGeofence = false;
  bool detailedData = false;
  bool isFollowModeEnabled = false;
  final notificationService = NotificationService();

  final controller = Completer<GoogleMapController>();

  double eventLatitude = 0.0;
  double eventLongitude = 0.0;
  String eventTime = "";
  String eventType = "";

  String? notifTitle;
  String? notifBody;
  String? notifTime;
  String? notifImage;

  String? lastNotifiedState;
  DateTime? lastNotificationTime;
  Duration stateRepeatInterval = Duration(minutes: 10); // adjust as needed

  Map<String, dynamic>? currentWeather;
  DateTime? lastWeatherFetch;

  LatLng? lastFollowedLocation;
  final double followThreshold = 5.0;

  double ax = 0.0;
  double ay = 0.0;
  double az = 0.0;
  double gx = 0.0;
  double gy = 0.0;
  double gz = 0.0;
  double anx = 0.0;
  double any = 0.0;
  double anz = 0.0;
  double mag = 0.0;
  double actMag = 0.0;
  double noise = 0.0;
  String state = "UNKNOWN";
  String timeAcc = "00:00:00";

  Timer? outTimer;
  bool isDarkMap = false;
  String? _currentMapStyle;

   int rssi = 0;
   double snr = 0.0;

Future<void> _setMapStyle() async {
  final stylePath = isDarkMap
      ? 'assets/map_themes/dark_mode.json'
      : 'assets/map_themes/light_mode.json';

  final style = await DefaultAssetBundle.of(context).loadString(stylePath);
  if (mounted) {
    setState(() {
      _currentMapStyle = style;
    });
  }
}


    @override
  void initState() {
    super.initState();
    _monitorNetworkChanges(); // Check internet in real time
    _connectToMQTT();
    decideConnectionStrategy();
    geofenceManager.loadGeofence(widget.petName);
    _loadStoredData();
    startOutTimer(); // Start timer if outStartTime is already set
  }

  @override
  void dispose() {
    wsSubscription?.cancel();
    wsChannel?.sink.close();
    client?.disconnect();
    outTimer?.cancel();
    super.dispose();
  }

  CustomNotification buildNotification({
    required String source, // "accel" or "event"
    required String value,
    required String time,
  }) {
    String title = "Activity Alert";
    String body = "";

    final rand = Random();
    final String upperValue = value.toUpperCase();

    List<String> options;

    switch (upperValue) {
      case "SLEEP":
        options = [
          "😴 Your pet is snoozing peacefully.",
          "😌 Nap time! Your buddy is asleep.",
          "🌙 A well-deserved rest for your pet.",
          "💤 Looks like a deep sleep going on!",
          "🐾 Resting mode activated.",
        ];
        break;

      case "WALK":
        options = [
          "🚶‍♂️ Your pet is going for a walk.",
          "🐕 Strolling around like a champ!",
          "🐾 A casual walk detected.",
          "🦴 Exploring the area step by step.",
          "😎 Your pet is on the move.",
        ];
        break;

      case "RUN":
        options = [
          "🏃 Your pet is running full speed!",
          "🐶 Zoomies activated!",
          "💨 High energy detected!",
          "🏞️ On a wild run through the terrain.",
          "⚡ Sprint mode enabled!",
        ];
        break;

      case "FALL":
        title = "⚠️ Fall Detected!";
        options = [
          "🪨 Your pet may have fallen.",
          "🚨 Sudden drop in activity. Check in!",
          "🐾 Fall alert triggered!",
          "😟 Your buddy might have slipped.",
          "📉 Acceleration indicates a fall.",
        ];
        break;

      case "IMPACT":
        title = "💥 Impact Detected!";
        options = [
          "💢 A strong impact has been recorded.",
          "🚨 Something just hit hard!",
          "🐾 Impact alert: sudden motion spike!",
          "🧱 Pet experienced a jolt!",
          "⚠️ High-force movement detected.",
        ];
        break;

      default:
        options = ["Activity: $value"];
        break;
    }

    body = options[rand.nextInt(options.length)];

    return CustomNotification(
      title: title,
      body: body,
      imageUrl: widget.petImageUrl,
      time: time,
    );
  }

  Future<Map<String, dynamic>?> fetchWeather(double lat, double lon) async {
    final apiKey = '35164c34f69748ee990103832251004';
    final url =
        'https://api.weatherapi.com/v1/current.json?key=$apiKey&q=$lat,$lon';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("WeatherAPI error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Weather fetch error: $e");
    }

    return null;
  }

  void startOutTimer() {
    outTimer?.cancel(); // Cancel any existing timer

    if (outStartTime != null) {
      outTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (mounted) setState(() {}); // Forces UI refresh every second
      });
    }
  }

  Future<void> _loadStoredData() async {
    final loadedPath = await storageService.loadPolyline(widget.petId);
    final loadedNotifications = await storageService.loadNotifications(widget.petId);
    final sessionData = await storageService.loadSessionState(widget.petId);
    final lastMarkerPos =await storageService.loadLastKnownMarker(widget.petId);
    final eventMarkers = await storageService.loadEventMarkers(widget.petId, context);
    geofenceExitCount = await storageService.loadGeofenceExitCount(widget.petId);

    // Check if we have a valid session in progress
    bool hasValidSession = sessionData['outStartTime'] != null;
    // Only add marker if coordinates are valid (not 0,0)
    if (lastMarkerPos != null &&
        lastMarkerPos.latitude != 0.0 &&
        lastMarkerPos.longitude != 0.0 &&
        hasValidSession) {
      addMarker(widget.petId, lastMarkerPos, widget.petImageUrl);
      latitude = lastMarkerPos.latitude;
      longitude = lastMarkerPos.longitude;
    } 
      if (eventMarkers.isNotEmpty) {
        setState(() {
          _markersEvent.addAll(eventMarkers);
        });
      }

    setState(() {
      petPath = sessionData['polyline'];
      totalDistance = sessionData['distance'];
      outStartTime = sessionData['outStartTime'];
      isPetHome = sessionData['isPetHome'];

      if (petPath.isNotEmpty) _updatePolyline();
      if (loadedNotifications.isNotEmpty) notifications = loadedNotifications;
    });
  }

  Future<void> _saveSessionToFirebase() async {
  if (outStartTime == null) return;

  try {
    final endTime = DateTime.now();
    final duration = endTime.difference(outStartTime!);

    List<Map<String, double>> pathData = petPath
        .map((point) => {"lat": point.latitude, "lon": point.longitude})
        .toList();

    List<Map<String, dynamic>> eventList = _markersEvent.entries.map((entry) {
      final marker = entry.value;
      final parts = entry.key.split("_"); // e.g., FALL_12345
      return {
        "type": parts.first,
        "time": eventTime, 
        "lat": marker.position.latitude,
        "lon": marker.position.longitude,
      };
    }).toList();

    Map<String, dynamic>? weatherData;
    if (currentWeather != null) {
      weatherData = {
        "temp_c": currentWeather!["current"]["temp_c"],
        "condition": currentWeather!["current"]["condition"]["text"],
        "icon": currentWeather!["current"]["condition"]["icon"]
      };
    }

    final sessionData = {
      "start_time": outStartTime!.toIso8601String(),
      "end_time": endTime.toIso8601String(),
      "duration_seconds": duration.inSeconds,
      "distance_meters": totalDistance,
      "path": pathData,
      "events": eventList,
      "weather": weatherData,
      "geofence_exit_count": geofenceExitCount,
    };

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("pets")
        .doc(widget.petId)
        .collection("pet_info")
        .doc("data")
        .collection("sessions")
        .add(sessionData);

    print("Full session saved to Firebase with weather and path.");
  } catch (e) {
    print("Failed to save full session: $e");
  }
}


  Future<bool> espHasInternet() async {
    try {
      final response = await http
          .get(Uri.parse('http://192.168.4.1/status'))
          .timeout(Duration(seconds: 2));
      if (response.statusCode == 200) {
        final json = response.body;
        return json.contains('"internet":true');
      }
    } catch (e) {
      print("ESP32 disnt answer to /status: $e");
    }
    return false;
  }

    void _connectToWebSocket() {
    print("Connecting to WebSocket at ws://192.168.4.1/ws ...");

    wsChannel = IOWebSocketChannel.connect('ws://192.168.4.1/ws');

    wsSubscription = wsChannel!.stream.listen(
      (message) {
        print("WebSocket message received: $message");
        setState(() {
          canConnect = true; // Connection confirmed via data
        });
        _parseGPSData(message); // refolosim parserul MQTT
      },
      onError: (error) {
        print("WebSocket error: $error");
        setState(() {
          canConnect = false;
        });
      },
      onDone: () {
        print("WebSocket connection closed.");
        setState(() {
          canConnect = false;
        });
      },
    );
  }

  Future<void> _connectToMQTT() async {
    if (retryCount > 10) {
      print("Max retry attempts reached. Stopping MQTT connection attempts.");
      return;
    }

    String broker = useCloud
        ? "4e8b407740ce42b18fba5f234af6b314.s1.eu.hivemq.cloud"
        : "192.168.4.1";

    client = MqttServerClient(broker, "flutter_client");
    client!.port = useCloud
        ? 8883
        : 1883; // TLS (8883) for cloud, Unsecure (1883) for local
    client!.logging(on: true);
    client!.keepAlivePeriod = 60;

    if (useCloud) {
      client!.secure = true; // enable TLS only for cloud
      client!.onBadCertificate =
          (dynamic cert) => true; // ignoring SSL certificate errors
    }

    final connMessage = MqttConnectMessage()
        .withClientIdentifier("flutter_client")
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    client!.connectionMessage = connMessage;

    client!.onDisconnected = () {
      print(" MQTT Disconnected.");
      setState(() {
        canConnect = false;
      });
    };

    try {
      await client!.connect("Iuli25", "Iuli369147");
      client!.subscribe("gps/tracker", MqttQos.atMostOnce);
      client!.subscribe("accel/tracker", MqttQos.atMostOnce);
      client!.subscribe("event/tracker", MqttQos.atMostOnce);
      client!.subscribe("signal/tracker", MqttQos.atMostOnce);
      _listenToMessages(); // Start listening to messages
      setState(() {}); // Update UI instantly after connecting
      print("Connected to MQTT: $broker");
    } catch (e) {
      print("Did not connect to MQTT: $e");
      setState(() {
        canConnect = false;
        useCloud = false; // Switch to local mode immediately
        retryCount++;
      });
      Future.delayed(Duration(seconds: 3), _connectToMQTT); // Retry after 3 sec
    }
  }

  Future<void> decideConnectionStrategy() async {
    final connectivity = await Connectivity().checkConnectivity();
    final bool phoneOnline = connectivity != ConnectivityResult.none;
    final bool espOnline = await espHasInternet();

    print("Phone online: $phoneOnline, ESP online: $espOnline");

    if (phoneOnline && espOnline) {
      // Caz ideal: MQTT Cloud, si telefonul si esp32 au internet
      useCloud = true;
      canConnect = true;
      _connectToMQTT();
    } else if (!phoneOnline && !espOnline) {
      // Caz fallback: local WebSocket, cand si telefonul si esp nu au internet
      useCloud = false;
      canConnect = true;
      _connectToWebSocket();
    } else if (phoneOnline && !espOnline) {
      // Telefonul are net, ESP32 nu => imposibil MQTT
      canConnect = false;
      print(
          "⚠️ ESP32 nu poate publica în cloud. Nu sunt disponibile date GPS.");
    } else if (!phoneOnline && espOnline) {
      // Telefonul nu e online => poate fi conectat la ESP AP
      canConnect = false;
      print(
          "⚠️ ESP are internet, dar telefonul nu este conectat la vreo rețea.");
    }
    if(mounted){
      setState(() {});
    }
    
  }

  /// Monitors real-time internet connectivity changes
  void _monitorNetworkChanges() {
    Connectivity().onConnectivityChanged.listen((_) {
      decideConnectionStrategy(); // redecide la schimbarea conexiunii
    });
  }

  void _listenToMessages() {
    client!.updates!.listen((messages) {
      final recMessage = messages[0].payload as MqttPublishMessage;
      final payload =
          MqttPublishPayload.bytesToStringAsString(recMessage.payload.message);
      final topic = messages[0].topic;
      setState(() {
        canConnect = true;
      });
      if (topic == "gps/tracker") {
        print("Received GPS data: $payload");
        _parseGPSData(payload);
      } else if (topic == "accel/tracker") {
        print("Received Accelerometer data: $payload");
        _parseAccelData(payload);
      } else if (topic == "event/tracker") {
        print("Received Event data: $payload");
        _parseEventData(payload);
      }
      else if(topic == "signal/tracker"){
        _parseSignalData(payload);
      }
    });
  }

  void _parseSignalData(String payload) {
  try {
    final rssiRegex = RegExp(r'RSSI\s*:\s*(-?\d+)');
    final snrRegex = RegExp(r'SNR\s*:\s*(-?\d+\.?\d*)');

    final rssiMatch = rssiRegex.firstMatch(payload);
    final snrMatch = snrRegex.firstMatch(payload);

    if (rssiMatch != null && snrMatch != null) {
      rssi = int.parse(rssiMatch.group(1)!);
      snr = double.parse(snrMatch.group(1)!);

      print("📡 Signal Strength: RSSI = $rssi dBm, SNR = $snr dB");

      setState(() {
        latestMessage = "Signal Info: RSSI = $rssi dBm, SNR = $snr dB";
      });

    } else {
      print("RSSI or SNR not found in payload: $payload");
    }
  } catch (e) {
    print("Error parsing signal data: $e");
  }
}


  void _parseAccelData(String payload) async {
    try {
      // Regex for the detailed format with accelerometer, gyroscope, and angle data
      RegExp detailedRegex = RegExp(
        r'AX\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*AY\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*AZ\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*GX\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*GY\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*GZ\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*ANX\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*ANY\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*ANZ\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*MAG\s*:\s*([-+]?[0-9]*\.?[0-9]+)',
        caseSensitive: false,
      );

      // Try to match the detailed format first
      Match? detailedMatch = detailedRegex.firstMatch(payload);

      if (detailedMatch != null) {
        ax = double.parse(detailedMatch.group(1)!);
        ay = double.parse(detailedMatch.group(2)!);
        az = double.parse(detailedMatch.group(3)!);
        gx = double.parse(detailedMatch.group(4)!);
        gy = double.parse(detailedMatch.group(5)!);
        gz = double.parse(detailedMatch.group(6)!);
        anx = double.parse(detailedMatch.group(7)!);
        any = double.parse(detailedMatch.group(8)!);
        anz = double.parse(detailedMatch.group(9)!);
        mag = double.parse(detailedMatch.group(10)!);

        // Try to extract ACTMAG if it exists
        RegExp actMagRegex = RegExp(r'ACTMAG\s*:\s*([-+]?[0-9]*\.?[0-9]+)',
            caseSensitive: false);
        Match? actMagMatch = actMagRegex.firstMatch(payload);
        if (actMagMatch != null) {
          actMag = double.parse(actMagMatch.group(1)!);
        }

        // Look for optional fields
        RegExp stateTimeRegex = RegExp(
            r'STATE\s*:\s*(\w+),\s*TIME\s*:\s*([0-9:]+)',
            caseSensitive: false);
        Match? stateTimeMatch = stateTimeRegex.firstMatch(payload);
        if (stateTimeMatch != null) {
          state = stateTimeMatch.group(1)!;
          timeAcc = stateTimeMatch.group(2)!;
        }

        RegExp noiseRegex =
            RegExp(r'NOISE\s*:\s*([-+]?[0-9]*\.?[0-9]+)', caseSensitive: false);
        Match? noiseMatch = noiseRegex.firstMatch(payload);
        if (noiseMatch != null) {
          noise = double.parse(noiseMatch.group(1)!);
        }

        setState(() {
          detailedData = true;
          latestMessage = "Accelerometer: AX=$ax, AY=$ay, AZ=$az, MAG=$mag";
        });
        return;
      }

      // If detailed didn't match, try simple format (just state and time)
      RegExp simpleRegex = RegExp(
        r'(\w+),TIME\s*:\s*([0-9:]+)',
        caseSensitive: false,
      );

      Match? simpleMatch = simpleRegex.firstMatch(payload);
      if (simpleMatch != null) {
        state = simpleMatch.group(1)!;
        timeAcc = simpleMatch.group(2)!;

        setState(() {
          detailedData = false;
          latestMessage = "Accelerometer: State=$state, Time=$timeAcc";
        });

        String currentState = state.toUpperCase();
        DateTime now = DateTime.now();

        bool shouldNotify = false;

        if (currentState != lastNotifiedState) {
          shouldNotify = true;
        } else if (lastNotificationTime == null ||
            now.difference(lastNotificationTime!) >= stateRepeatInterval) {
          shouldNotify = true;
        }

        if (["SLEEP", "WALK", "RUN"].contains(currentState)) {
          if (currentState == previousState) {
            stateRepeatCount++;
          } else {
            previousState = currentState;
            stateRepeatCount = 1;
          }

          if (stateRepeatCount >= 3 && currentState != lastNotifiedState) {
            CustomNotification notif = buildNotification(
              source: "accel",
              value: currentState,
              time: timeAcc,
            );

            setState(() {
              notifications.add(notif);
              lastNotifiedState = currentState;
            });

            await storageService.saveNotifications(
                widget.petId, notifications);
            notificationService.showCustomNotification(notif);
          }
        }
        return;
      }

      print("Error: Unrecognized accelerometer data format");
    } catch (e) {
      print("Error parsing accelerometer data: $e");
    }
  }

  void _parseEventData(String payload) async {
    try {
      RegExp regex = RegExp(
        r'(?:PRIORITY:)?TYPE\s*:\s*(\w+),\s*LAT\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*LON\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*TIME\s*:\s*([0-9:]+)',
        caseSensitive: false,
      );

      Match? match = regex.firstMatch(payload);
      if (match != null) {
        setState(() {
          eventType = match.group(1)!;
          eventLatitude = double.parse(match.group(2)!);
          eventLongitude = double.parse(match.group(3)!);
          eventTime = match.group(4)!;

          notifTitle = "Event detected";
          notifBody = "Your pet triggered a '$eventType' event.";
          notifImage = widget.petImageUrl;
          notifTime = eventTime;
        });

        if (["FALL", "IMPACT"].contains(eventType.toUpperCase())) {
          CustomNotification notif = buildNotification(
              source: "event", value: eventType, time: eventTime);
          setState(() {
            notifications.add(notif);
          });
          await storageService.saveNotifications(widget.petId, notifications);
          notificationService.showCustomNotification(notif);

          await MarkerFunctions.addEventMarker(
            context: context, 
            markerMap: _markersEvent,
            updateMarkers: (newMarkers) {
              setState(() {
               // _markersEvent.clear();
                _markersEvent.addAll(newMarkers);
              });
            },
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            location: LatLng(eventLatitude, eventLongitude),
            type: eventType,
          );
          await storageService.saveEventMarkers(widget.petId, _markersEvent);
        }

        print("Parsed Event and showed notification.");
      }
    } catch (e) {
      print("Error parsing event data: $e");
    }
  }

  void _updateMarkerPosition(String id, LatLng newPosition) {
    final marker = _markers[id];
    if (marker != null) {
      final updatedMarker = marker.copyWith(
        rotationParam: 0.0,
        positionParam: newPosition,
      );
      setState(() {
        _markers[id] = updatedMarker;
      });
    }
  }

  void _updatePolyline() {
    final polylineId = PolylineId("pet_path");

    final polyline = Polyline(
      polylineId: polylineId,
      color: const ui.Color.fromARGB(
          255, 67, 166, 237), // You can change color or add gradient logic
      width: 5,
      points: petPath,
      patterns: [PatternItem.dash(20), PatternItem.gap(10)], // dashed look
      jointType: JointType.round,
      endCap: Cap.roundCap,
      startCap: Cap.roundCap,
    );

    setState(() {
      _polylines[polylineId] = polyline;
    });
  }

  double _distanceBetween(LatLng a, LatLng b) {
    final dx = a.latitude - b.latitude;
    final dy = a.longitude - b.longitude;
    return sqrt(dx * dx + dy * dy) * 111139; // approximate meters
  }

  Duration _calculateCurrentOutTime() {
    if (outStartTime != null) {
      return totalOutDuration + DateTime.now().difference(outStartTime!);
    }
    return totalOutDuration;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

void _handleFollowModeCamera(LatLng newLocation) async {
  if (!isFollowModeEnabled || !controller.isCompleted) return;

  final movedDistance = lastFollowedLocation == null
      ? double.infinity
      : Geolocator.distanceBetween(
          lastFollowedLocation!.latitude,
          lastFollowedLocation!.longitude,
          newLocation.latitude,
          newLocation.longitude,
        );

  if (lastFollowedLocation == null || movedDistance > followThreshold) {
    lastFollowedLocation = newLocation;

    final mapCtrl = await controller.future; // <- wait for it to be ready

    mapCtrl.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: newLocation,
        zoom: 17.0,
        bearing: 0.0,
        tilt: 0.0,
      ),
    ));

    print("📍 Camera following pet. Distance moved: $movedDistance m");
  } else {
    print("✅ No camera update. Pet only moved $movedDistance m");
  }
}


Future<void> _parseGPSData(String payload) async {
  try {
    RegExp regex = RegExp(
      r'LAT\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*LON\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*ALT\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*SPD\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*SAT\s*:\s*([0-9]+),\s*TIME\s*:\s*([0-9:]+)',
      caseSensitive: false,
    );

    Match? match = regex.firstMatch(payload);

    if (match != null) {
      double lat = double.parse(match.group(1)!);
      double lon = double.parse(match.group(2)!);
      LatLng newLocation = LatLng(lat, lon);

      // First location received - initialize tracker state
      if (petPath.isEmpty) {
        double distanceFromHome = _distanceBetween(newLocation, widget.initialLocation);
        isPetHome = distanceFromHome <= 20; // Set initial home status

        // If pet already away from home on first detection, start timer
        if (!isPetHome && outStartTime == null) {
          outStartTime = DateTime.now();
          startOutTimer(); // Start timer for UI updates
          print("🏃 Pet already away from home area. Session started.");
        }
      }

      CustomNotification? notif;
      bool addedToPath = false;
        
      setState(() {
        latitude = lat;
        longitude = lon;
        altitude = double.parse(match.group(3)!);
        speed = double.parse(match.group(4)!);
        satellites = int.parse(match.group(5)!);
        time = match.group(6)!;

        // Update polyline path if moved enough
        if (petPath.isEmpty || _distanceBetween(petPath.last, newLocation) > 5) {
          double distance = _distanceBetween(petPath.lastOrNull ?? newLocation, newLocation);
          totalDistance += distance;
          petPath.add(newLocation);
          _updatePolyline();
          addedToPath = true;
        }

        // Move marker
        if (latitude == 0.0 && longitude == 0.0) {
          addMarker(widget.petId, newLocation, widget.petImageUrl);
        } else if (!_markers.containsKey(widget.petId)) {
          addMarker(widget.petId, newLocation, widget.petImageUrl);
          // Check if pet is leaving home area
          if (isPetHome) {
            double distanceFromHome = _distanceBetween(newLocation, widget.initialLocation);

            if (distanceFromHome > 20) { // customize threshold if needed
              outStartTime = DateTime.now();
              isPetHome = false;
              startOutTimer(); // Start timer for UI updates
              print("🏃 Pet left home area. Session started.");
              notif = CustomNotification(
                title: "🏠 Pet Left Home",
                body: "${widget.petName} has left home at $time.",
                imageUrl: widget.petImageUrl,
                time: time,
              );
              notifications.add(notif!);
            }
          }
        } else {
          _updateMarkerPosition(widget.petId, newLocation);
          _handleFollowModeCamera(newLocation);
          // Also check on every location update if pet is leaving home
          if (isPetHome) {
            double distanceFromHome = _distanceBetween(newLocation, widget.initialLocation);
            
            if (distanceFromHome > 20) {
              outStartTime = DateTime.now();
              isPetHome = false;
              startOutTimer(); // Start timer for UI updates
              print("🏃 Pet left home area. Session started.");
              notif = CustomNotification(
                title: "🏠 Pet Left Home",
                body: "${widget.petName} has left home at $time.",
                imageUrl: widget.petImageUrl,
                time: time,
              );
              notifications.add(notif!);
            }
          }
        }
      });
      
      await storageService.saveLastKnownMarker(widget.petId, newLocation);
      if (notif != null) {
        await storageService.saveNotifications(widget.petId, notifications);
        notificationService.showCustomNotification(notif!);
      }
      
      final weatherData = await fetchWeather(lat, lon);
      if (weatherData != null) {
        setState(() {
          currentWeather = weatherData;
          print("🌤️ Weather: $weatherData");
        });
      }

      if (addedToPath) {
        await storageService.savePolyline(widget.petId, petPath);
        await storageService.saveSessionState(
          widget.petId,
          polyline: petPath,
          distance: totalDistance,
          outStartIso: outStartTime?.toIso8601String(),
          isPetHome: isPetHome,
        );
      }
           
      if (geofenceManager.checkIfOutside(latitude, longitude)) {
        geofenceExitCount++;
        await storageService.saveGeofenceExitCount(widget.petId, geofenceExitCount);
        _showGeofenceAlert();
        final notif = CustomNotification(
          title: "📍 Geofence Alert",
          body: "${widget.petName} exited the safe zone at $time.",
          imageUrl: widget.petImageUrl,
          time: time,
        );

        setState(() {
          notifications.add(notif);
        });

        await storageService.saveNotifications(widget.petId, notifications);
      }
    }
  } catch (e) {
    print("Parse error: $e");
  }
}

  void _showGeofenceAlert() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("🚨 Geofence Alert"),
        content: Text("Animal has exited the safe zone at $time!"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("OK"),
          )
        ],
      ),
    );
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
                  color: !isDarkMap? Colors.white : ui.Color.fromARGB(255, 11, 84, 111),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 5),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          color: canConnect
                              ? (useCloud
                                  ? Colors.greenAccent
                                  : Colors.amberAccent)
                              : Colors.redAccent,
                          size: 20,
                        ),
                        SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            canConnect
                                ? (useCloud
                                    ? "Connected to Cloud MQTT"
                                    : "Using Local WebSocket")
                                : "No connection to GPS data",
                            style: TextStyle(fontSize: 18,color: isDarkMap? Colors.white:Colors.black),
                          ),
                        ),
                      ],
                    ),
                    Text("GPS Information",
                        style: TextStyle(fontWeight: FontWeight.bold,color: isDarkMap? Colors.white:Colors.black)),
                    Divider(),
                    if (latitude == 0.0 && longitude == 0.0) ...[
                      Text("⚠️  Gps data not recorded yet!",style: TextStyle(color: isDarkMap? Colors.white:Colors.black),),
                      Text("💡Try getting your pet outside",style: TextStyle(color: isDarkMap? Colors.white:Colors.black))
                    ] else ...[
                      Text("Latitude: $latitude",style: TextStyle(color: isDarkMap? Colors.white:Colors.black)),
                      Text("Longitude: $longitude",style: TextStyle(color: isDarkMap? Colors.white:Colors.black)),
                      Text("Altitude: $altitude m",style: TextStyle(color: isDarkMap? Colors.white:Colors.black)),
                      Text("Speed: $speed m/s",style: TextStyle(color: isDarkMap? Colors.white:Colors.black)),
                      Text("Satellites: $satellites",style: TextStyle(color: isDarkMap? Colors.white:Colors.black)),
                      Text("Time: $time"),
                      Text(
                          "Distance walked: ${(totalDistance / 1000).toStringAsFixed(2)} km",style: TextStyle(color: isDarkMap? Colors.white:Colors.black)),
                    ],
                    SizedBox(height: 5),
                    Text("Accelometer Information",
                        style: TextStyle(fontWeight: FontWeight.bold,color: isDarkMap? Colors.white:Colors.black)),
                    Divider(),
                    if (detailedData) ...[
                      Text("Acceleration: AX: $ax, AY: $ay, AZ: $az",style: TextStyle(color: isDarkMap? Colors.white:Colors.black)),
                      Text("Gyroscope: GX: $gx, GY: $gy, GZ: $gz",style: TextStyle(color: isDarkMap? Colors.white:Colors.black)),
                      Text("Angle: ANX: $anx, ANY: $any, ANZ: $anz",style: TextStyle(color: isDarkMap? Colors.white:Colors.black)),
                      Text("Magnitude: $mag",style: TextStyle(color: isDarkMap? Colors.white:Colors.black)),
                      if (actMag != 0.0) Text("Active Magnitude: $actMag",style: TextStyle(color: isDarkMap? Colors.white:Colors.black)),
                      if (noise != 0.0) Text("Noise: $noise",style: TextStyle(color: isDarkMap? Colors.white:Colors.black)),
                      Text("State: $state",style: TextStyle(color: isDarkMap? Colors.white:Colors.black)),
                      Text("Time: $timeAcc",style: TextStyle(color: isDarkMap? Colors.white:Colors.black)),
                    ] else ...[
                      Text("State: $state",style: TextStyle(color: isDarkMap? Colors.white:Colors.black)),
                      Text("Time: $timeAcc",style: TextStyle(color: isDarkMap? Colors.white:Colors.black)),
                    ],
                    SizedBox(height: 5,),
                    Text("Signal and Radio Noise Status",style: TextStyle(fontWeight: FontWeight.bold,color: isDarkMap? Colors.white:Colors.black)),
                    Divider(),
                    if(rssi == 0 && snr==0.0)...[
                      Text("Signal and Noise not recorded yet!",style: TextStyle(color: isDarkMap? Colors.white:Colors.black),),
                    ]
                    else ...[
                      if(rssi>=-30 || rssi>=-60)...[
                        Row(
                          children: [
                            Icon(Icons.circle,color: Colors.greenAccent,size: 10),
                            SizedBox(width: 10,),
                            Text("Signal is excelent",style: TextStyle(color: isDarkMap? Colors.white:Colors.black),),
                          ],
                        ),
                      ]else if(rssi>=-61 || rssi>=-90)...[
                        Row(
                          children: [
                            Icon(Icons.circle,color: Colors.yellow,size: 10),
                            SizedBox(width: 10,),
                            Text("Signal is decent",style: TextStyle(color: isDarkMap? Colors.white:Colors.black),),
                          ],
                        ),
                      ]else if(rssi<=-91)...[
                        Row(
                          children: [
                            Icon(Icons.circle,color: Colors.red,size: 10,),
                            SizedBox(width: 10,),
                            Text("Signal is weak",style: TextStyle(color: isDarkMap? Colors.white:Colors.black),),
                          ],
                        ),
                      ],

                       if(snr>8)...[
                        Row(
                          children: [
                            Icon(Icons.circle,color: Colors.greenAccent,size: 10),
                            SizedBox(width: 10,),
                            Text("Radio Noise is excelent",style: TextStyle(color: isDarkMap? Colors.white:Colors.black),),
                          ],
                        ),
                      ]else if(snr>5)...[
                        Row(
                          children: [
                            Icon(Icons.circle,color: Colors.yellow,size: 10),
                            SizedBox(width: 10,),
                            Text("Radio Noise is good",style: TextStyle(color: isDarkMap? Colors.white:Colors.black),),
                          ],
                        ),
                      ]else if(snr<0)...[
                        Row(
                          children: [
                            Icon(Icons.circle,color: Colors.red,size: 10),
                            SizedBox(width: 10,),
                            Text("Radio Noise is bad",style: TextStyle(color: isDarkMap? Colors.white:Colors.black),),
                          ],
                        ),
                      ]
                    ] ,
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          overlayEntry.remove();
                        },
                        child: Text("Close",style: TextStyle(color: isDarkMap? Colors.white:const ui.Color.fromARGB(255, 47, 36, 66))),
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

    overlayState.insert(
        overlayEntry); //inserts the overlayEntry into the Overlay system, making it visible on the screen

    // periodically refresh overlay if widget is still mounted
    Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        overlayEntry.remove();
        return;
      }
      overlayEntry
          .markNeedsBuild(); // refresh overlay to update values from mqtt, prevents showing the new data
      // only if you open and close the info
    });
  }

  void _centerToPetMarker() {
    if (latitude != 0.0 && longitude != 0.0) {
      LatLng petLocation = LatLng(latitude, longitude);
      mapController.animateCamera(CameraUpdate.newLatLng(petLocation));
      print("Centered to pet at: $latitude, $longitude");
    } else {
      print("Pet location not available yet.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          content: AwesomeSnackbarContent(
            title: 'Hold on',
            message: 'Pet Location not available yet',
            contentType: ContentType.failure,
            color: ui.Color.fromARGB(255, 214, 60, 73),
          ),
          duration: Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      );
    }
  }

  Future<void> _addHomeMarker(LatLng location) async {
    // Option 1: Use a default marker with a different color
    // BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

    // Option 2: Create a fully custom home icon
    BitmapDescriptor markerIcon = await BitmapDescriptor.asset(
      ImageConfiguration(size: Size(48, 48)),
      'assets/home_green.png', // Add this image to your assets
    );

    final homeMarker = Marker(
      markerId: MarkerId('home'),
      position: location,
      icon: markerIcon,
      infoWindow: InfoWindow(title: 'Home Base'),
    );

    setState(() {
      _markers['home'] = homeMarker;
    });
  }

  void addMarker(String id, LatLng location, String imageUrl) async {
    BitmapDescriptor markerIcon =
        await MapFunctions.createCustomMarker(imageUrl);

    var marker = Marker(
      markerId: MarkerId(id),
      position: location,
      icon: markerIcon,
      rotation: 0.0,
      onTap: () {
        setState(() {
          selectedMarkerId =
              id; // Store the marker ID for info window visibility
          selectedMarkerPosition = location;
          selectedPetImage = imageUrl;
        });
      },
    );
    setState(() {
      _markers[id] = marker;
    }); // Refresh UI to update the marker
  }

  void _showRadiusSlider() {
    MapFunctions.showRadiusSlider(
      context: context,
      geofenceManager: geofenceManager,
      onConfirm: () async {
        setState(() {
          isSettingGeofence = false;
          geofenceManager.buildGeofenceCircle();
        });
        await geofenceManager.saveGeofence(widget.petName);
      },
      onRadiusChanged: (value) {
        geofenceManager.updateRadius(value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMap? ui.Color.fromARGB(255, 24, 38, 96): Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(           
              colors: isDarkMap ?
              [
                ui.Color.fromARGB(255, 11, 84, 111),
                ui.Color.fromARGB(255, 68, 45, 65),
                ui.Color.fromARGB(255, 97, 46, 74)
              ]
              :[
                 ui.Color.fromARGB(255, 144, 230, 219),
                ui.Color.fromARGB(255, 248, 165, 239),
                ui.Color.fromARGB(255, 244, 116, 186)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: AppBar(
            centerTitle: true,
            backgroundColor: Colors.transparent,
            iconTheme: IconThemeData(color: Colors.white),
            elevation: 0,
            title: Text(
              "GPS Tracker",
              style: TextStyle(color: Colors.white),
            ),
            automaticallyImplyLeading: true,
            actions: [
              IconButton(
                icon: Icon(
                  isDarkMap ? Icons.dark_mode : Icons.light_mode,
                  color:isDarkMap? Colors.white: const ui.Color.fromARGB(255, 255, 243, 79),
                ),
                onPressed: () async {
                  setState(() {
                    isDarkMap = !isDarkMap;
                  });
                  await _setMapStyle();
                },
              ),
              IconButton(
                icon: const Icon(Icons.help_outline, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HelpPage()),
                  );
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.info_outline,
                  color: Colors.white,
                ),
                onPressed: () {
                  _showGPSCoords(context);
                },
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Animarker(
            shouldAnimateCamera: false,
            mapId: controller.future.then<int>(
                (value) => value.mapId), // assign this in onMapCreated
            curve: Curves.easeInOut,
            duration: Duration(milliseconds: 800),
            markers: Set<Marker>.of({..._markers,..._markersEvent}.values),
            child: GoogleMap(
              style: _currentMapStyle,
              polylines: Set<Polyline>.of(_polylines.values),
              myLocationButtonEnabled: false,
              circles: geofenceManager.geofenceCircle != null
                  ? {geofenceManager.geofenceCircle!}
                  : {},
              initialCameraPosition: CameraPosition(target: widget.initialLocation, zoom: 14),
              onMapCreated: (controller) {              
                mapController = controller;
                this.controller.complete(controller);
                _addHomeMarker(widget.initialLocation);
                _setMapStyle();
              },
              onTap: (LatLng tappedPoint) {
                if (isSettingGeofence) {
                  setState(() {
                    geofenceManager.updateCenter(tappedPoint);
                  });
                  _showRadiusSlider(); // slider de radius
                } else {
                  setState(() {
                    selectedMarkerId = null;
                  });
                }
              },
            ),
          ),
         StatCardWindow(
            totalDistance: totalDistance,
            formattedDuration: _formatDuration(_calculateCurrentOutTime()),
          ),

          if (currentWeather != null)
            WeatherInfoBox(weatherData: currentWeather!),
           FloatingButtonsPanel(
              onCenterPet: _centerToPetMarker,
              onToggleFollowMode: () {
                setState(() {
                  isFollowModeEnabled = !isFollowModeEnabled;
                });
                if (isFollowModeEnabled && latitude != 0.0 && longitude != 0.0) {
                  _centerToPetMarker();
                }
              },
              onOpenNotifications: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NotificationListPage(notifications: notifications),
                  ),
                );
              },
              onZoomIn: () => mapController.animateCamera(CameraUpdate.zoomIn()),
              onZoomOut: () => mapController.animateCamera(CameraUpdate.zoomOut()),
              isFollowModeEnabled: isFollowModeEnabled,
            ),
          if (selectedMarkerId != null)
            Positioned(
              left: MediaQuery.of(context).size.width * 0.3,
              top: MediaQuery.of(context).size.height * 0.5,
              child: Container(
                padding: EdgeInsets.all(12),
                width: 250,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.fromARGB(255, 144, 230, 219),
                      Color.fromARGB(255, 248, 165, 239),
                      Color.fromARGB(255, 244, 116, 186)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Image.network(selectedPetImage,
                          height: 50, width: 50, fit: BoxFit.cover),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.circle,
                          color: Colors.greenAccent,
                          size: 5,
                        ),
                        SizedBox(
                          width: 5,
                        ),
                        Expanded(
                          child: Text(
                            "Currently tracking: ${widget.petName}",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          selectedMarkerId = null;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.purple),
                      child: Text("Close"),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 16,
            right: 150,
            child: FloatingActionButton.extended(
                heroTag: 'home_button',
                backgroundColor: Colors.white,
                label: Text("I'm Home", style: TextStyle(color: Colors.black)),
                icon: Icon(Icons.home, color: Colors.black),
                onPressed: () async {
                  if (outStartTime != null) {
                    await storageService.saveGeofenceExitCount(widget.petId, 0);
                    await storageService.saveTrackingStatus(widget.petId, false);
                    await _saveSessionToFirebase();
                    await storageService.clearSessionState(widget.petId);
                    await storageService.savePolyline(widget.petId, []);
                    await storageService.saveLastKnownMarker(
                        widget.petId, LatLng(0, 0));
                    await storageService.saveNotifications(widget.petId, []);
                    await storageService.clearEventMarkers(widget.petId); 
                    outTimer?.cancel();

                    setState(() {
                      geofenceExitCount = 0;
                      totalOutDuration +=DateTime.now().difference(outStartTime!);
                      outStartTime = null;
                      startOutTimer(); 
                      isPetHome = true;
                      totalDistance = 0.0;
                      petPath.clear();
                      _polylines.clear();
                      latitude = 0.0;
                      longitude = 0.0;
                      _markers.remove(widget.petId);
                      _markersEvent.clear();
                    });
                    print("Session saved!!");
                  }
                }),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: FloatingActionButton(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              onPressed: () {
                setState(() {
                  isSettingGeofence = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    behavior: SnackBarBehavior.floating,
                    content: AwesomeSnackbarContent(
                      title: 'Set Geofence',
                      message: '📍 Tap on map to set geofence center',
                      contentType: ContentType.warning,
                      color: ui.Color.fromARGB(255, 60, 214, 193),
                    ),
                    duration: Duration(seconds: 3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                );
              },
              backgroundColor: ui.Color.fromARGB(255, 255, 255, 255),
              child: Icon(
                Icons.place,
                color: const ui.Color.fromARGB(255, 107, 107, 107),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
