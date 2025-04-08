import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:connectivity_plus/connectivity_plus.dart';  // Internet status detection
import 'package:pet_watch/map_logic/geofence_manager.dart';
import 'package:pet_watch/map_logic/map_functions.dart';
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
  final GeofenceManager geofenceManager = GeofenceManager();
  bool isSettingGeofence = false;

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
    geofenceManager.loadGeofence(widget.petName);
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
    decideConnectionStrategy();  // redecide la schimbarea conexiunii
  });
}

void _listenToMessages() {
    client!.updates!.listen((messages) {
      final recMessage = messages[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(recMessage.payload.message);
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
    });
  }

  void _parseAccelData(String payload) {
  try {
    // Regex for the first simple format: State and Time only
    RegExp simpleRegex = RegExp(
      r'(\w+),TIME\s*:\s*([0-9:]+)',
      caseSensitive: false,
    );

    // Regex for the detailed format with accelerometer, gyroscope, and angle data
    RegExp detailedRegex = RegExp(
      r'AX\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*AY\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*AZ\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*GX\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*GY\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*GZ\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*ANX\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*ANY\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*ANZ\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*MAG\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*ACTMAG\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*NOISE\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*STATE\s*:\s*(\w+),\s*TIME\s*:\s*([0-9:]+)',
      caseSensitive: false,
    );

    // Try to match the simple format first
    Match? simpleMatch = simpleRegex.firstMatch(payload);

    if (simpleMatch != null) {
      state = simpleMatch.group(1)!;
       timeAcc = simpleMatch.group(2)!;

      print("Parsed Simple Accelerometer Data: STATE=$state, TIME=$time");

      setState(() {
        latestMessage = "Accelerometer: State=$state, Time=$timeAcc";
      });
      return;
    }

    // Try to match the detailed format if simple format fails
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
       actMag = double.parse(detailedMatch.group(11)!);
       noise = double.parse(detailedMatch.group(12)!);
       state = detailedMatch.group(13)!;
       timeAcc = detailedMatch.group(14)!;

      print("Parsed Detailed Accelerometer Data:");
      print("AX=$ax, AY=$ay, AZ=$az");
      print("GX=$gx, GY=$gy, GZ=$gz");
      print("ANX=$anx, ANY=$any, ANZ=$anz");
      print("MAG=$mag, ACTMAG=$actMag, NOISE=$noise");
      print("STATE=$state, TIME=$timeAcc");

      setState(() {
        latestMessage = "Accelerometer: AX=$ax, AY=$ay, AZ=$az, GX=$gx, GY=$gy, GZ=$gz, ANX=$anx, ANY=$any, ANZ=$anz, MAG=$mag, ACTMAG=$actMag, NOISE=$noise, STATE=$state, TIME=$timeAcc";
      });
      return;
    }

    print("Error: Unrecognized accelerometer data format");
  } catch (e) {
    print("Error parsing accelerometer data: $e");
  }
}


  void _parseEventData(String payload)
  {
    
  }

void _updateMarkerPosition(String id, LatLng newPosition) {
  final marker = _markers[id];
  if (marker != null) {
    final updatedMarker = marker.copyWith(
      positionParam: newPosition,
    );
    setState(() {
      _markers[id] = updatedMarker;
    });
  }
}
  void _parseGPSData(String payload) {
    try {
      RegExp regex = RegExp(
        r'LAT\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*LON\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*ALT\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*SPD\s*:\s*([-+]?[0-9]*\.?[0-9]+),\s*SAT\s*:\s*([0-9]+),\s*TIME\s*:\s*([0-9:]+)',

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

          LatLng newLocation = LatLng(latitude, longitude);//update marker position on map
          if(_markers.isEmpty){
            addMarker(widget.petName, newLocation, widget.petImageUrl);//add pet marker for first time
            mapController.animateCamera(CameraUpdate.newLatLng(newLocation));//focus on marker
          }else{
            _updateMarkerPosition(widget.petName,newLocation);
          }
        });
      }
        if (geofenceManager.checkIfOutside(latitude, longitude)) {
               _showGeofenceAlert();
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
      print("WebSocket message received: $message");
      setState(() {
      canConnect = true;  // Connection confirmed via data
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
        client!.subscribe("accel/tracker", MqttQos.atMostOnce);
        client!.subscribe("event/tracker", MqttQos.atMostOnce);
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

void _centerToPetMarker() {
  if (latitude != 0.0 && longitude != 0.0) {
    LatLng petLocation = LatLng(latitude, longitude);
    mapController.animateCamera(CameraUpdate.newLatLng(petLocation));
    print("Centered to pet at: $latitude, $longitude");
  } else {
    print("Pet location not available yet.");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Pet location not available yet."),
        duration: Duration(seconds: 2),
      ),
    );
  }
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
      myLocationButtonEnabled: false,
      circles: geofenceManager.geofenceCircle != null ? {geofenceManager.geofenceCircle!} : {},
      initialCameraPosition: CameraPosition(target: initialLocation, zoom: 14),
      onMapCreated: (controller) {
        mapController = controller;
        //addMarker('test', initialLocation, widget.petImageUrl);
      },
      markers: _markers.values.toSet(),
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
    Positioned(
  bottom: 16,
  right: 16,
  child: FloatingActionButton(
    backgroundColor: ui.Color.fromARGB(255, 255, 255, 255),
    shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              ),
    heroTag: 'center_to_pet',
    child: Icon(Icons.my_location,color: const ui.Color.fromARGB(255, 115, 115, 115),),
    onPressed: () {
      _centerToPetMarker();
    },
  ),
),

 Positioned(
  bottom: 100,
  left: 16,
  child: FloatingActionButton(
    backgroundColor: ui.Color.fromARGB(255, 255, 255, 255),
    shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              ),
    heroTag: 'updates/messages',
    child: Icon(Icons.message,color: const ui.Color.fromARGB(255, 115, 115, 115),),
    onPressed: () {
      
    },
  ),
),

Positioned(
  bottom: 90,
  right: 16,
  child: Column(
    children: [
      FloatingActionButton(
        backgroundColor: ui.Color.fromARGB(255, 255, 255, 255),
    shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              ),
        heroTag: 'zoom_in',
        child: Icon(Icons.add,color: const ui.Color.fromARGB(255, 115, 115, 115)),
        onPressed: () {
          mapController.animateCamera(CameraUpdate.zoomIn());
        },
      ),
      SizedBox(height: 10),
      FloatingActionButton(
        backgroundColor: ui.Color.fromARGB(255, 255, 255, 255),
    shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              ),
        heroTag: 'zoom_out',
        child: Icon(Icons.remove,color: const ui.Color.fromARGB(255, 115, 115, 115)),
        onPressed: () {
          mapController.animateCamera(CameraUpdate.zoomOut());
        },
      ),
    ],
  ),
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
              content:AwesomeSnackbarContent(title: 'Set Geofence', message: '📍 Tap on map to set geofence center', 
              contentType: ContentType.warning,
              color: ui.Color.fromARGB(255, 60, 214, 193),
              ) ,
              duration: Duration(seconds: 3),
              shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              ),
              ),
          );
        },
        backgroundColor: ui.Color.fromARGB(255, 255, 255, 255),
        child: Icon(Icons.place,color: const ui.Color.fromARGB(255, 107, 107, 107),),
      ),
    ),
  ],
),
);
}

void addMarker(String id, LatLng location, String imageUrl) async {
  BitmapDescriptor markerIcon = await MapFunctions.createCustomMarker(imageUrl);

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


  setState(() {  _markers[id] = marker;}); // Refresh UI to update the marker
}

void _showRadiusSlider() {
  MapFunctions.showRadiusSlider(
    context: context,
    geofenceManager: geofenceManager,
    onConfirm: () async{
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

}

