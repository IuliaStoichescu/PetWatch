import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PulsingCircle extends StatefulWidget {
  final LatLng position;
  final double radius;
  final double opacity;
  final GoogleMapController mapController;
  final Color color;

  const PulsingCircle({
    super.key,
    required this.position,
    required this.radius,
    required this.opacity,
    required this.mapController,
    required this.color
  });

  @override
  State<PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<PulsingCircle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _radiusAnimation;

  Offset? screenPosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: false);

    _radiusAnimation = Tween<double>(begin: 0, end: widget.radius).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _updateScreenPosition();
  }

  Future<void> _updateScreenPosition() async {
    final projection = await widget.mapController.getScreenCoordinate(widget.position);
    setState(() {
      screenPosition = Offset(projection.x.toDouble(), projection.y.toDouble());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

   @override
  Widget build(BuildContext context) {
    return FutureBuilder<ScreenCoordinate>(
      future: widget.mapController.getScreenCoordinate(widget.position),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox.shrink();

        final screenPos = Offset(
          snapshot.data!.x.toDouble(),
          snapshot.data!.y.toDouble(),
        );

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final size = _radiusAnimation.value;
            return Positioned(
              left: screenPos.dx - size / 2,
              top: screenPos.dy - size / 2,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withOpacity(widget.opacity * (1 - _controller.value)),
                ),
              ),
            );
          },
        );
      },
    );
  }

}
