import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'camera_controls.dart';

class CameraRealTime extends StatefulWidget {
  const CameraRealTime({super.key});

  @override
  State<CameraRealTime> createState() => _CameraRealTimeState();
}

class _CameraRealTimeState extends State<CameraRealTime> {
  CameraController? _cameraController;
  List<CameraDescription>? cameras;
  DateTime? _lastCaptureTime;

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    cameras = await availableCameras();
    final backCamera = cameras!.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );

    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();

    // await _cameraController!.startImageStream((CameraImage image) {
    //   log(_cameraController.toString());
    //   // TODO: ส่ง frame เข้า YOLO/ML
    //   // 1 วินาที่ ตัด 3 ภาพ
    //   // 1 วินาที นั้น ตัดได้กี่ fram
    // });
    await _cameraController!.startImageStream((CameraImage image) {
      final now = DateTime.now();

      // ตัดภาพทุก 333 ms (≈ 3 ภาพ / วินาที)
      if (_lastCaptureTime == null ||
          now.difference(_lastCaptureTime!).inMilliseconds >= 333) {
        _lastCaptureTime = now;

        log("📸 Capture frame at $now");

        //  TODO: แปลง CameraImage → Image / JPEG
        //  TODO: ส่งไป YOLO / FastAPI
      }
    });

    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    if (_cameraController != null) {
      // เช็กว่า initialized และยังไม่ disposed
      if (_cameraController!.value.isInitialized) {
        if (_cameraController!.value.isStreamingImages) {
          _cameraController!.stopImageStream();
        }
        _cameraController!.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          Center(child: CameraPreview(_cameraController!)),

          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "ไฟเขียวไห้เลี้ยวซ้าย",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          CameraControls(
            cameraController: _cameraController!,
            onClose: () async {
              if (_cameraController!.value.isStreamingImages) {
                await _cameraController!.stopImageStream();
              }
              _cameraController?.dispose();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
