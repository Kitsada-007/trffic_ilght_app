import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraControls extends StatelessWidget {
  final CameraController cameraController;
  final VoidCallback onClose;

  const CameraControls({
    super.key,
    required this.cameraController,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 40,
          left: 20,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.black54,
            child: const Icon(Icons.close),
            onPressed: onClose,
          ),
        ),
      ],
    );
  }
}
