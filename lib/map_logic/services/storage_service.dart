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

  String _today() => DateTime.now().toIso8601String().substring(0, 10);
  bool _isToday(String? stored) => stored == _today();
}
