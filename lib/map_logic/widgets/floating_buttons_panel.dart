import 'package:flutter/material.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'dart:ui' as ui;

class FloatingButtonsPanel extends StatelessWidget {
  final VoidCallback onCenterPet;
  final VoidCallback onToggleFollowMode;
  final VoidCallback onOpenNotifications;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final bool isFollowModeEnabled;

  const FloatingButtonsPanel({
    super.key,
    required this.onCenterPet,
    required this.onToggleFollowMode,
    required this.onOpenNotifications,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.isFollowModeEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            heroTag: 'center_to_pet',
            onPressed: onCenterPet,
            child: Icon(Icons.my_location, color: ui.Color.fromARGB(255, 115, 115, 115)),
          ),
        ),
        Positioned(
          bottom: 100,
          left: 16,
          child: FloatingActionButton(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            heroTag: 'notifications',
            onPressed: onOpenNotifications,
            child: Icon(Icons.message, color: ui.Color.fromARGB(255, 115, 115, 115)),
          ),
        ),
        Positioned(
          bottom: 220,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: isFollowModeEnabled
                ? Color.fromARGB(255, 144, 230, 219)
                : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            heroTag: 'follow_mode',
            child: Icon(
              isFollowModeEnabled ? Icons.visibility : Icons.visibility_off,
              color: isFollowModeEnabled ? Colors.white : ui.Color.fromARGB(255, 115, 115, 115),
            ),
            onPressed: () {
              onToggleFollowMode();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  behavior: SnackBarBehavior.floating,
                  content: AwesomeSnackbarContent(
                    title: isFollowModeEnabled ? 'Follow Mode Off' : 'Follow Mode On',
                    message: isFollowModeEnabled
                        ? 'Manual map control enabled'
                        : 'Map will follow your pet',
                    contentType:
                        isFollowModeEnabled ? ContentType.warning : ContentType.success,
                    color: isFollowModeEnabled
                        ? Color.fromARGB(255, 214, 140, 60)
                        : Color.fromARGB(255, 60, 214, 193),
                  ),
                  duration: Duration(seconds: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: 90,
          right: 16,
          child: Column(
            children: [
              FloatingActionButton(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                heroTag: 'zoom_in',
                onPressed: onZoomIn,
                child: Icon(Icons.add, color: ui.Color.fromARGB(255, 115, 115, 115)),
              ),
              SizedBox(height: 10),
              FloatingActionButton(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                heroTag: 'zoom_out',
                onPressed: onZoomOut,
                child: Icon(Icons.remove, color: ui.Color.fromARGB(255, 115, 115, 115)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
