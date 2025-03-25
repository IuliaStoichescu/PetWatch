import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeofenceManager {
  LatLng? geofenceCenter;
  double geofenceRadius = 100;
  bool wasOutside = false;
  Circle? geofenceCircle;

  void updateCenter(LatLng newCenter) {
    geofenceCenter = newCenter;
  }

  void updateRadius(double radius) {
    geofenceRadius = radius;
  }

  Circle buildGeofenceCircle() {
    geofenceCircle = Circle(
      circleId: CircleId('geofence'),
      center: geofenceCenter!,
      radius: geofenceRadius,
      fillColor: const Color.fromARGB(255, 61, 185, 251).withOpacity(0.2),
      strokeColor: Colors.lightBlueAccent,
      strokeWidth: 2,
    );
    return geofenceCircle!;
  }

  bool checkIfOutside(double lat, double lng) {
    if (geofenceCenter == null) return false;

    double distance = Geolocator.distanceBetween(
      lat,
      lng,
      geofenceCenter!.latitude,
      geofenceCenter!.longitude,
    );

    if (distance > geofenceRadius && !wasOutside) {
      wasOutside = true;
      return true; // Trigger alert
    } else if (distance <= geofenceRadius) {
      wasOutside = false;
    }

    return false;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000; // meters
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = 
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // SAVE
  Future<void> saveGeofence(String petId) async {
    final prefs = await SharedPreferences.getInstance();
    if (geofenceCenter != null) {
      prefs.setDouble('${petId}_lat', geofenceCenter!.latitude);
      prefs.setDouble('${petId}_lng', geofenceCenter!.longitude);
      prefs.setDouble('${petId}_radius', geofenceRadius);
    }
  }

  // LOAD
  Future<void> loadGeofence(String petId) async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('${petId}_lat');
    final lng = prefs.getDouble('${petId}_lng');
    final radius = prefs.getDouble('${petId}_radius');

    if (lat != null && lng != null && radius != null) {
      geofenceCenter = LatLng(lat, lng);
      geofenceRadius = radius;
      buildGeofenceCircle();
    }
  }
}
