import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerFunctions {
  static Future<void> addEventMarker({
    required Map<String, Marker> markerMap,
    required Function(Map<String, Marker>) updateMarkers,
    required String id,
    required LatLng location,
    required String type,
    required BuildContext context,
  }) async {
    String assetPath;
    String message ;
    final markerKey = "${type.toUpperCase()}_$id";
    switch (type.toUpperCase()) {
      case "FALL":
        assetPath = 'assets/fall_detected.png';
        message = "⚠️ Your pet may have fallen at this location.";
        break;
      case "IMPACT":
        assetPath = 'assets/impact_detected.webp';
        message = "💥 An impact was detected around this area.";
        break;
      default:
        return;
    }

    final BitmapDescriptor customIcon =
        await bitmapFromAsset(assetPath);

    final marker = Marker(
      markerId: MarkerId(markerKey),
      position: location,
      icon: customIcon,
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text("📍 $type Detected"),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("OK"),
              )
            ],
          ),
        );
      },
    );
    markerMap[markerKey] = marker;
    updateMarkers({...markerMap});
  }

  static Future<BitmapDescriptor> bitmapFromAsset(String path) async {
    return BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(48, 48)),
      path,
    );
  }
  static Future<Marker> createEventMarkerFromData({
  required BuildContext context,
  required String id,
  required LatLng position,
  required String type,
}) async {
  String assetPath;
  String message;

  switch (type.toUpperCase()) {
    case "FALL":
      assetPath = 'assets/fall_detected.png';
      message = "⚠️ Your pet may have fallen at this location.";
      break;
    case "IMPACT":
      assetPath = 'assets/impact_detected.png';
      message = "💥 A strong impact was detected here.";
      break;
    case "RUN":
      assetPath = 'assets/running_detected.png';
      message = "🏃 Your pet started running from this spot.";
      break;
    default:
      assetPath = 'assets/default_marker.png';
      message = "Event detected here.";
  }

  final customIcon = await bitmapFromAsset(assetPath);

  return Marker(
    markerId: MarkerId(id),
    position: position,
    icon: customIcon,
    infoWindow: InfoWindow(title: type),
    onTap: () {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("📍 $type"),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text("OK"))
          ],
        ),
      );
    },
  );
}

}