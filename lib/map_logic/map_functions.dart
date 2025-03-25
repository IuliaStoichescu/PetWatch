import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:pet_watch/map_logic/geofence_manager.dart';

class MapFunctions {
  static Future<BitmapDescriptor> createCustomMarker(String imageUrl) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final double markerSize = 180.0;
    final double circleSize = 140.0;

    final http.Response response = await http.get(Uri.parse(imageUrl));
    final Uint8List imageData = response.bodyBytes;
    final ui.Codec codec = await ui.instantiateImageCodec(
      imageData,
      targetWidth: circleSize.toInt(),
      targetHeight: circleSize.toInt(),
    );
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

    final ui.Image markerAsImage = await pictureRecorder.endRecording().toImage(
      markerSize.toInt(),
      markerSize.toInt(),
    );
    final ByteData? byteData = await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List markerData = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(markerData);
  }

  static void showRadiusSlider({
    required BuildContext context,
    required GeofenceManager geofenceManager,
    required VoidCallback onConfirm,
    required Function(double) onRadiusChanged,
  }) {
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
                    activeColor: ui.Color.fromARGB(255, 60, 214, 193),
                    min: 50,
                    max: 500,
                    divisions: 9,
                    label: '${geofenceManager.geofenceRadius.toInt()} m',
                    value: geofenceManager.geofenceRadius,
                    onChanged: (value) {
                      setModalState(() => onRadiusChanged(value));
                    },
                  ),
                  ElevatedButton(
                    onPressed: () {
                      onConfirm();
                      Navigator.pop(context);
                    },
                    style: ButtonStyle(backgroundColor: MaterialStateProperty.all(Color(0xFF3CD6C1))),
                    child: Icon(Icons.check,color: Colors.white,),
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
