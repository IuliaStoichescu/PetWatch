import 'package:flutter/material.dart';

class SquareFab extends StatefulWidget {
  final VoidCallback onPressed;

  const SquareFab({Key? key, required this.onPressed}) : super(key: key);

  @override
  _SquareFabState createState() => _SquareFabState();
}

class _SquareFabState extends State<SquareFab> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200), // Smooth transition
        decoration: BoxDecoration(
          color: _isHovered
              ? const Color.fromARGB(255, 130, 90, 100) // Darker when hovered
              : const Color.fromARGB(255, 108, 76, 87),
          borderRadius: BorderRadius.circular(15), // Slightly rounded corners
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: const Color.fromARGB(32, 0, 0, 0),
                    blurRadius: 8,
                    spreadRadius: 5,
                    offset: Offset(0, 4),
                  ),
                ]
              : []
        ),
        child: FloatingActionButton(
          onPressed: widget.onPressed,
          backgroundColor: Colors.transparent, // Transparent to allow decoration
          elevation: 0, // Remove default shadow
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(Icons.add, size: 28, color: Colors.white),
        ),
      ),
    );
  }
}
