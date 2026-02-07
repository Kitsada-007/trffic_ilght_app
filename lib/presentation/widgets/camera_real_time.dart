import 'dart:async';
import 'dart:developer';
import 'dart:convert'; // สำหรับ jsonDecode
import 'dart:typed_data'; // สำหรับ Uint8List
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http; // สำหรับส่ง API
import 'camera_controls.dart';

class CameraRealTime extends StatefulWidget {
  const CameraRealTime({super.key});

  @override
  State<CameraRealTime> createState() => _CameraRealTimeState();
}

class _CameraRealTimeState extends State<CameraRealTime> {
  CameraController? _cameraController;
  Timer? _timer; // ใช้ Timer แทน Stream เพื่อคุม FPS ได้นิ่งกว่า
  bool _isRequesting = false; // กันส่งข้อมูลซ้อนกัน

  // ตัวแปรเก็บผลลัพธ์จาก YOLO
  List<dynamic> _detections = [];
  Size _serverImageSize = Size.zero; // ขนาดรูปต้นฉบับที่ส่งไป Server

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.medium, // ใช้ Medium ให้ภาพชัดพอแต่ไฟล์ไม่ใหญ่เกินไป
      enableAudio: false,
    );

    await _cameraController!.initialize();

    // --- ส่วนที่แก้ไข: ใช้ Timer แทน startImageStream ---
    // เหตุผล: takePicture() ได้ไฟล์ JPEG เลย สะดวกและชัวร์กว่าการแปลง CameraImage เอง
    // ตั้งเวลา 500ms (2 FPS) เพื่อไม่ให้เน็ต/Server ทำงานหนักเกินไป
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _captureAndSendFrame();
    });

    if (!mounted) return;
    setState(() {});
  }

  // ฟังก์ชันถ่ายรูปและส่งไป API
  Future<void> _captureAndSendFrame() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isRequesting) {
      return;
    }

    _isRequesting = true; // ล็อกสถานะ

    try {
      // 1. ถ่ายรูป (ได้ JPEG ทันที)
      final XFile imageFile = await _cameraController!.takePicture();
      final bytes = await imageFile.readAsBytes();

      // 2. ส่งไป FastAPI
      await _sendToYolo(bytes);
    } catch (e) {
      log("Error capturing: $e");
    } finally {
      _isRequesting = false; // ปลดล็อก
    }
  }

  // ฟังก์ชันยิง API
  Future<void> _sendToYolo(Uint8List imageBytes) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        // ⚠️ เปลี่ยน IP ตรงนี้ให้เป็น IP เครื่องคอมฯ ของคุณ (ดูด้วย ipconfig)
        // ค้นหาบรรทัดนี้ในฟังก์ชัน sendFrameToYolo
        Uri.parse('http://10.31.7.135:8000/img_object_detection_to_json'),
      );

      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: 'frame.jpg'),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));

        if (mounted) {
          setState(() {
            _detections = jsonResponse['detect_objects'] ?? [];
            // รับขนาดรูปจริงจาก Server เพื่อคำนวณสัดส่วนการวาด
            if (jsonResponse['meta'] != null) {
              _serverImageSize = Size(
                (jsonResponse['meta']['width'] as num).toDouble(),
                (jsonResponse['meta']['height'] as num).toDouble(),
              );
            }
          });
        }
      }
    } catch (e) {
      log("API Error: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // ยกเลิก Timer
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ใช้ LayoutBuilder เพื่อหาขนาดพื้นที่จริงที่กล้องแสดงผลอยู่
    return Scaffold(
      body: Stack(
        children: [
          // 1. ตัวกล้อง (Layout เดิม)
          Center(child: CameraPreview(_cameraController!)),

          // 2. ตัววาดกรอบ (ซ้อนทับอยู่ตำแหน่งเดียวกับกล้อง)
          if (_detections.isNotEmpty && _serverImageSize != Size.zero)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // ส่งขนาดหน้าจอจริงไปให้ Painter คำนวณ Scale
                  return CustomPaint(
                    painter: BoundingBoxPainter(
                      detections: _detections,
                      serverSize:
                          _serverImageSize, // ขนาดรูปต้นทาง (จาก Server)
                      previewSize:
                          _cameraController!.value.previewSize!, // ขนาด Preview
                      widgetSize:
                          constraints.biggest, // ขนาดหน้าจอที่แสดงผลอยู่
                    ),
                  );
                },
              ),
            ),

          // 3. UI เดิมของคุณ
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
              child: Text(
                // เปลี่ยนข้อความตามสิ่งที่เจอ
                _detections.isNotEmpty
                    ? "เจอ: ${_detections[0]['name']} (${(_detections[0]['confidence'] * 100).toInt()}%)"
                    : "ไฟเขียวไห้เลี้ยวซ้าย",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // ปุ่มควบคุม
          CameraControls(
            cameraController: _cameraController!,
            onClose: () async {
              _timer?.cancel();
              // ไม่ต้อง stopImageStream แล้วเพราะเราไม่ได้ใช้
              _cameraController?.dispose();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ส่วน Painter (วาดกรอบสี่เหลี่ยม)
// ==========================================
class BoundingBoxPainter extends CustomPainter {
  final List<dynamic> detections;
  final Size serverSize; // ขนาดรูปที่ส่งไป Server (เช่น 1280x720)
  final Size widgetSize; // ขนาดหน้าจอที่แสดงผลจริง (เช่น 400x800)
  final Size previewSize;

  BoundingBoxPainter({
    required this.detections,
    required this.serverSize,
    required this.widgetSize,
    required this.previewSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // คำนวณ Scale Factor
    // เนื่องจาก CameraPreview อาจจะ scale ภาพให้เต็มจอ เราต้องเทียบอัตราส่วน
    double scaleX = widgetSize.width / serverSize.width;
    double scaleY = widgetSize.height / serverSize.height;

    // ถ้ากล้องแสดงผลแบบ "Cover" (เต็มจอ) อาจต้องปรับ Logic การ Scale เล็กน้อย
    // แต่เบื้องต้นใช้สูตรนี้สำหรับการเริ่มเทสได้เลย

    for (var det in detections) {
      // ดึงค่าพิกัดจาก Server
      double x = (det['xmin'] as num).toDouble();
      double y = (det['ymin'] as num).toDouble();
      double w = (det['xmax'] as num).toDouble() - x;
      double h = (det['ymax'] as num).toDouble() - y;

      // แปลงพิกัดให้ตรงกับหน้าจอ
      final rect = Rect.fromLTWH(
        x * scaleX,
        y * scaleY,
        w * scaleX,
        h * scaleY,
      );

      // วาดกรอบ
      canvas.drawRect(rect, paint);

      // วาดชื่อรุ่น/วัตถุ
      textPainter.text = TextSpan(
        text: "${det['name']} ${(det['confidence'] * 100).toInt()}%",
        style: const TextStyle(
          color: Colors.white,
          backgroundColor: Colors.red,
          fontSize: 14,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(rect.left, rect.top - 20));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
