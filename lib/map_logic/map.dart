import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lottie/lottie.dart' show Lottie;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:connectivity_plus/connectivity_plus.dart';  // Internet status detection

class MapPage extends StatefulWidget {
  final String petName;
  final String petImageUrl;
  const MapPage({Key? key, required this.petName, required this.petImageUrl}) : super(key: key);

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
  LatLng initialLocation = LatLng(45.7235054321469, 21.250409338816176);
  late GoogleMapController mapController;
  final Map<String,Marker> _markers = {};
  Color markerColor = Colors.red;//default color
  

  @override
  void initState() {
    super.initState();
    _monitorNetworkChanges(); // Check internet in real time
    _connectToMQTT();
  }

  void showColorPicker() {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text("Select Marker Color"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 10,
              children: [
                for (var color in [
                     Colors.red,
                     Colors.blue,
                     Colors.green, 
                     const ui.Color.fromARGB(255, 147, 46, 228),
                     Colors.orange, 
                     Colors.pink,
                     Colors.yellow,
                     Colors.cyanAccent,
                     Colors.brown,
                     Colors.white,
                     Colors.black
                     ])
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        markerColor = color;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
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
  body: GoogleMap(
    initialCameraPosition: CameraPosition(target: initialLocation,zoom: 14),
    onMapCreated: (controller) {
      mapController = controller;
      addMarker('test',initialLocation,widget.petImageUrl);
    },
    markers: _markers.values.toSet(),
   ),
  );
  }

void addMarker(String id, LatLng location, String imageUrl) async {
  BitmapDescriptor markerIcon = await createCustomMarker(imageUrl, markerColor);

  var marker = Marker(
    markerId: MarkerId(id),
    position: location,
    icon: markerIcon,
    onTap: () {
      _showCustomInfoWindow(id, location, imageUrl);
    },
  );

  _markers[id] = marker;

  setState(() {}); // Refresh UI to update the marker
}
void _showCustomInfoWindow(String markerId, LatLng location, String imageUrl) {
  showModalBottomSheet(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    backgroundColor: Colors.white,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.circle,color: Colors.greenAccent,),
                SizedBox(width: 10,),
                Text(
                  "Currently tracking : ${widget.petName}",
                  
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 10),
            Image.network(imageUrl, height: 80, width: 80, fit: BoxFit.cover), // Pet Image
            SizedBox(height: 10),
            Text("Customize your marker color:"),
            SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                for (var color in [
                     Colors.red,
                     Colors.blue,
                     Colors.green, 
                     const ui.Color.fromARGB(255, 147, 46, 228),
                     Colors.orange, 
                     Colors.pink,
                     Colors.yellow,
                     Colors.cyanAccent,
                     Colors.brown,
                     Colors.white,
                     Colors.black
                     ])
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        markerColor = color; // Update color
                        addMarker(markerId, location, imageUrl); // Update marker with new color
                      });
                      Navigator.pop(context); // Close the InfoWindow
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(width: 2, color: Colors.black),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.pop(context), // Close InfoWindow
              child: Text("Close"),
            ),
          ],
        ),
      );
    },
  );
}

Future<BitmapDescriptor> createCustomMarker(String imageUrl, Color markerColor) async {
  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  final double markerWidth = 180.0;
  final double markerHeight = 200.0;

  final Paint paint = Paint()..color = markerColor;

  Path path = Path();
  path.moveTo(markerWidth / 2, markerHeight); // Bottom point
  path.lineTo(markerWidth * 0.1, markerHeight * 0.4); // Left side
  path.arcToPoint(
    Offset(markerWidth * 0.9, markerHeight * 0.4), // Right side curve
    radius: Radius.circular(50),
  );
  path.lineTo(markerWidth / 2, markerHeight); // Closing the pin shape
  canvas.drawPath(path, paint);

  // Draw the rounded head (a big circle at the top)
  final Paint headPaint = Paint()..color = markerColor;
  Offset headCenter = Offset(markerWidth / 2, markerHeight * 0.3);
  double headRadius = 45;
  canvas.drawCircle(headCenter, headRadius, headPaint);

  // Draw a white circular cutout in the center
  final Paint cutoutPaint = Paint()..color = Colors.white;
  double circleRadius = 50;
  canvas.drawCircle(headCenter, circleRadius, cutoutPaint);

  // Load pet image and clip it to a circle
  final http.Response response = await http.get(Uri.parse(imageUrl));
  final Uint8List imageData = response.bodyBytes;
  final ui.Codec codec = await ui.instantiateImageCodec(imageData, targetWidth: 120,targetHeight: 100);
  final ui.FrameInfo frameInfo = await codec.getNextFrame();

  // Clip pet image into a perfect circle
  final ui.Image image = frameInfo.image;
  final ui.Path clipPath = Path()
    ..addOval(Rect.fromCircle(center: headCenter, radius: circleRadius));

  canvas.save();
  canvas.clipPath(clipPath);
  canvas.drawImage(image, Offset(headCenter.dx - circleRadius, headCenter.dy - circleRadius), Paint());
  canvas.restore();

  // Convert to BitmapDescriptor
  final ui.Image markerAsImage = await pictureRecorder.endRecording().toImage(markerWidth.toInt(), markerHeight.toInt());
  final ByteData? byteData = await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
  final Uint8List markerData = byteData!.buffer.asUint8List();

  return BitmapDescriptor.fromBytes(markerData);
}

}

