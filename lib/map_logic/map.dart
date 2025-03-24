import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lottie/lottie.dart' show Lottie;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:connectivity_plus/connectivity_plus.dart';  // Internet status detection
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';


class MapPage extends StatefulWidget {
  final String petName;
  final String petImageUrl;
  const MapPage({Key? key, required this.petName, required this.petImageUrl}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MqttServerClient? client;

  WebSocketChannel? wsChannel;
  StreamSubscription? wsSubscription;//pentru folosirea WebSocket cand receptorul nu are acces la internet pt primirea datelor gps

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
  String? selectedMarkerId;
  LatLng? selectedMarkerPosition; 
  String selectedPetImage = ""; 
  bool canConnect = true;

  LatLng? geofenceCenter;
  double geofenceRadius = 100;
  bool isSettingGeofence = false;
  Circle? geofenceCircle;
  bool wasOutside = false;


  void resetCoords()
  {
   latitude = 0.0;
   longitude = 0.0;
   altitude = 0.0;
   speed = 0.0;
   satellites = 0;
   time = "";
  }

  @override
  void initState() {
    super.initState();
    _monitorNetworkChanges(); // Check internet in real time
    _connectToMQTT();
    decideConnectionStrategy();
  }

Future<bool> espHasInternet() async {
  try {
    final response = await http.get(Uri.parse('http://192.168.4.1/status')).timeout(Duration(seconds: 2));
    if (response.statusCode == 200) {
      final json = response.body;
      return json.contains('"internet":true');
    }
  } catch (e) {
    print("ESP32 disnt answer to /status: $e");
  }
  return false;
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
    print("⚠️ ESP32 nu poate publica în cloud. Nu sunt disponibile date GPS.");
  } else if (!phoneOnline && espOnline) {
    // Telefonul nu e online => poate fi conectat la ESP AP
    canConnect = false;
    print("⚠️ ESP are internet, dar telefonul nu este conectat la vreo rețea.");
  }

  setState(() {});
}
  /// Monitors real-time internet connectivity changes
  void _monitorNetworkChanges() {
  Connectivity().onConnectivityChanged.listen((_) {
    decideConnectionStrategy();  // 🔄 redecide la schimbarea conexiunii
  });
}

void _listenToMessages() {
    client!.updates!.listen((messages) {
      final recMessage = messages[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(recMessage.payload.message);

      setState(() {
      canConnect = true;  
      });
      _parseGPSData(payload);
    });
  }

  void _parseGPSData(String payload) {
    try {
      RegExp regex = RegExp(
        r'LAT\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*LONG\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*ALT\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*SPEED\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*SAT\s*:\s*([0-9]+),\s*TIME\s*:\s*([0-9:]+)', 
        caseSensitive: false)
        ;
      Match? match = regex.firstMatch(payload);

      if (match != null) {
        setState(() {
          latitude = double.parse(match.group(1)!);
          longitude = double.parse(match.group(2)!);
          altitude = double.parse(match.group(3)!);
          speed = double.parse(match.group(4)!);
          satellites = int.parse(match.group(5)!);
          time = match.group(6)!;
        });
      }
      if (geofenceCenter != null) {
        double dist = Geolocator.distanceBetween(
          latitude,
          longitude,
          geofenceCenter!.latitude,
          geofenceCenter!.longitude,
        );

        if (dist > geofenceRadius && !wasOutside) {
          _showGeofenceAlert(); 
          wasOutside = true;
        } else if (dist <= geofenceRadius) {
          wasOutside = false;
        }
      }

    } catch (e) {
      print("Parse error: $e");
    }
  }

void _showGeofenceAlert()
{
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text("🚨 Geofence Alert"),
      content: Text("Animal has exited the safe zone!"),
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
                  Row(
                        children: [
                          Icon(
                            Icons.circle,
                            color: canConnect
                                ? (useCloud ? Colors.greenAccent : Colors.amberAccent)
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
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ],
                      ),

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

void _connectToWebSocket() {
  print("Connecting to WebSocket at ws://192.168.4.1/ws ...");

  wsChannel = IOWebSocketChannel.connect('ws://192.168.4.1/ws');

  wsSubscription = wsChannel!.stream.listen(
    (message) {
      print("📨 WebSocket message received: $message");
      setState(() {
      canConnect = true;  // ✅ Connection confirmed via data
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
      canConnect = false;
    },
  );
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

    client!.onDisconnected = () {
        print(" MQTT Disconnected.");
        setState(() {
          canConnect = false;
        });
      };


    try {
        await client!.connect("Iuli25", "Iuli369147");
        client!.subscribe("gps/tracker", MqttQos.atMostOnce);
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

@override
void dispose() {
  wsSubscription?.cancel();
  wsChannel?.sink.close();
  client?.disconnect();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  appBar: PreferredSize(
    preferredSize: Size.fromHeight(60),
    child: Container(
      decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [ui.Color.fromARGB(255, 144, 230, 219), ui.Color.fromARGB(255, 248, 165, 239), ui.Color.fromARGB(255, 244, 116, 186)],
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
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text("GPS Tracker",style: TextStyle(color: Colors.white),),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline,color: Colors.white,),
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
    GoogleMap(
      circles: geofenceCircle != null ? {geofenceCircle!} : {},
      initialCameraPosition: CameraPosition(target: initialLocation, zoom: 14),
      onMapCreated: (controller) {
        mapController = controller;
        addMarker('test', initialLocation, widget.petImageUrl);
      },
      markers: _markers.values.toSet(),
      onTap: (LatLng tappedPoint) {
  if (isSettingGeofence) {
    setState(() {
      geofenceCenter = tappedPoint;
    });
    _showRadiusSlider(); // slider de radius
  } else {
    setState(() {
      selectedMarkerId = null;
    });
  }
},
    ),

    // Custom Info Window
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
                child: Image.network(selectedPetImage, height: 50, width: 50, fit: BoxFit.cover),
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.circle,color: Colors.greenAccent,size: 5,),
                  SizedBox(width: 5,),
                  Expanded(
                    child: Text(
                      "Currently tracking: ${widget.petName}",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
                child: Text("Close"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.purple),
              ),
            ],
          ),
        ),
      ),
      Positioned(
      left: 16,
      bottom: 16,
      child: FloatingActionButton(
        onPressed: () {
          setState(() {
            isSettingGeofence = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              elevation: 0,
              backgroundColor: Colors.transparent, 
              behavior: SnackBarBehavior.floating,
              content:AwesomeSnackbarContent(title: 'Set Geofence', message: '📍 Tap on map to set geofence center', 
              contentType: ContentType.warning,
              color: ui.Color.fromARGB(255, 60, 214, 193),
              ) ,
              duration: Duration(seconds: 3),
              ),
          );
        },
        backgroundColor: ui.Color.fromARGB(255, 74, 140, 255),
        child: Icon(Icons.place,color: Colors.white,),
      ),
),
  ],
),

  );
  }

void addMarker(String id, LatLng location, String imageUrl) async {
  BitmapDescriptor markerIcon = await createCustomMarker(imageUrl);

  var marker = Marker(
    markerId: MarkerId(id),
    position: location,
    icon: markerIcon,
    onTap: () {
      setState(() {
        selectedMarkerId = id; // Store the marker ID for info window visibility
        selectedMarkerPosition = location;
        selectedPetImage = imageUrl;
      });
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

Future<BitmapDescriptor> createCustomMarker(String imageUrl) async {
  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  final double markerSize = 180.0; 
  final double circleSize = 140.0; 

  final http.Response response = await http.get(Uri.parse(imageUrl));
  final Uint8List imageData = response.bodyBytes;
  final ui.Codec codec = await ui.instantiateImageCodec(imageData, targetWidth: circleSize.toInt(), targetHeight: circleSize.toInt());
  final ui.FrameInfo frameInfo = await codec.getNextFrame();
  final ui.Image image = frameInfo.image;

  final Paint paint = Paint()..color = Colors.redAccent; 

  Offset center = Offset(markerSize / 2, markerSize / 2);
  canvas.drawCircle(center, markerSize / 2, paint);

  final Paint borderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 8.0;
  canvas.drawCircle(center, circleSize / 2 + 4, borderPaint);

  Path clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: circleSize / 2));
  canvas.save();
  canvas.clipPath(clipPath);
  canvas.drawImage(image, Offset((markerSize - circleSize) / 2, (markerSize - circleSize) / 2), Paint());
  canvas.restore();

  final ui.Image markerAsImage = await pictureRecorder.endRecording().toImage(markerSize.toInt(), markerSize.toInt());
  final ByteData? byteData = await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
  final Uint8List markerData = byteData!.buffer.asUint8List();

  return BitmapDescriptor.fromBytes(markerData);
}

void _showRadiusSlider() {
  showModalBottomSheet(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Select Geofence Radius (meters)', style: TextStyle(fontSize: 16)),
                Slider(
                  min: 50,
                  max: 500,
                  divisions: 9,
                  label: '${geofenceRadius.toInt()} m',
                  value: geofenceRadius,
                  onChanged: (value) {
                    setModalState(() => geofenceRadius = value);
                  },
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isSettingGeofence = false;
                      geofenceCircle = Circle(
                        circleId: CircleId('geofence'),
                        center: geofenceCenter!,
                        radius: geofenceRadius,
                        fillColor: const ui.Color.fromARGB(255, 61, 185, 251).withOpacity(0.2),
                        strokeColor: Colors.lightBlueAccent,
                        strokeWidth: 2,
                      );
                    });
                    Navigator.pop(context);
                  },
                  child: Text("Confirm"),
                )
              ],
            ),
          );
        },
      );
    },
  );
}

}

