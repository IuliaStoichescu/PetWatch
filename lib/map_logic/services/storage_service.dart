import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pet_watch/map_logic/services/custom-notification.dart';

class StorageService {
  // Save notifications
  Future<void> saveNotifications(String petId, List<CustomNotification> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${petId}_notifications';
    final dateKey = '${petId}_saved_date';

    List<String> notifJsonList = notifications.map((n) => jsonEncode({
      'title': n.title,
      'body': n.body,
      'imageUrl': n.imageUrl,
      'time': n.time,
    })).toList();

    await prefs.setStringList(key, notifJsonList);
    await prefs.setString(dateKey, _today());
  }

  Future<List<CustomNotification>> loadNotifications(String petId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${petId}_notifications';
    final dateKey = '${petId}_saved_date';

    if (!_isToday(prefs.getString(dateKey))) {
      await prefs.remove(key);
      return [];
    }

    final List<String>? notifJsonList = prefs.getStringList(key);
    if (notifJsonList == null) return [];

    return notifJsonList.map((j) {
      final data = jsonDecode(j);
      return CustomNotification(
        title: data['title'],
        body: data['body'],
        imageUrl: data['imageUrl'],
        time: data['time'],
      );
    }).toList();
  }

  // Save polyline
  Future<void> savePolyline(String petId, List<LatLng> path) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${petId}_polyline';
    final dateKey = '${petId}_saved_date';

    List<String> pathList = path.map((point) => jsonEncode({
      'lat': point.latitude,
      'lon': point.longitude,
    })).toList();

    await prefs.setStringList(key, pathList);
    await prefs.setString(dateKey, _today());
  }

  Future<List<LatLng>> loadPolyline(String petId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${petId}_polyline';
    final dateKey = '${petId}_saved_date';

    if (!_isToday(prefs.getString(dateKey))) {
      await prefs.remove(key);
      return [];
    }

    final List<String>? pathList = prefs.getStringList(key);
    if (pathList == null) return [];

    return pathList.map((j) {
      final data = jsonDecode(j);
      return LatLng(data['lat'], data['lon']);
    }).toList();
  }

  Future<void> saveSessionState(String petId, {
  required List<LatLng> polyline,
  required double distance,
  required String? outStartIso,
  required bool isPetHome,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final prefix = '${petId}_session';

  await prefs.setStringList('${prefix}_polyline', polyline.map((p) => jsonEncode({'lat': p.latitude, 'lon': p.longitude})).toList());
  await prefs.setDouble('${prefix}_distance', distance);
  if (outStartIso != null) await prefs.setString('${prefix}_start', outStartIso);
  await prefs.setBool('${prefix}_home', isPetHome);
}

Future<Map<String, dynamic>> loadSessionState(String petId) async {
  final prefs = await SharedPreferences.getInstance();
  final prefix = '${petId}_session';

  List<LatLng> polyline = (prefs.getStringList('${prefix}_polyline') ?? []).map((j) {
    final p = jsonDecode(j);
    return LatLng(p['lat'], p['lon']);
  }).toList();

  double distance = prefs.getDouble('${prefix}_distance') ?? 0.0;
  String? outStartIso = prefs.getString('${prefix}_start');
  bool isPetHome = prefs.getBool('${prefix}_home') ?? true;
  DateTime? outStart = outStartIso != null ? DateTime.tryParse(outStartIso) : null;

  return {
    'polyline': polyline,
    'distance': distance,
    'outStartTime': outStart,
    'isPetHome': isPetHome,
  };
}

Future<void> clearSessionState(String petId) async {
  final prefs = await SharedPreferences.getInstance();
  final prefix = '${petId}_session';

  await prefs.remove('${prefix}_polyline');
  await prefs.remove('${prefix}_distance');
  await prefs.remove('${prefix}_start');
  await prefs.remove('${prefix}_home');
  await prefs.remove('${petId}_marker');
}

Future<void> saveLastKnownMarker(String petId, LatLng position) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble('${petId}_last_lat', position.latitude);
  await prefs.setDouble('${petId}_last_lng', position.longitude);
}

Future<LatLng?> loadLastKnownMarker(String petId) async {
  final prefs = await SharedPreferences.getInstance();
  final lat = prefs.getDouble('${petId}_last_lat');
  final lng = prefs.getDouble('${petId}_last_lng');
  if (lat != null && lng != null) {
    return LatLng(lat, lng);
  }
  return null;
}

Future<void> saveTrackingStatus(String petId, bool isTracking) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('${petId}_tracking', isTracking);
}

Future<bool> loadTrackingStatus(String petId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('${petId}_tracking') ?? false;
}


  String _today() => DateTime.now().toIso8601String().substring(0, 10);
  bool _isToday(String? stored) => stored == _today();
}
