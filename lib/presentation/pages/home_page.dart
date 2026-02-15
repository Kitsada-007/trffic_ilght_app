import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trffic_ilght_app/presentation/pages/camera_inference_screen.dart';
import 'package:trffic_ilght_app/presentation/pages/single_image_screen.dart';
import 'package:trffic_ilght_app/presentation/pages/video_inference_screen.dart';
import 'package:video_player/video_player.dart';

import 'package:trffic_ilght_app/presentation/widgets/bottom_navigation_bar.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final ImagePicker picker = ImagePicker();
  XFile? videoFile;
  VideoPlayerController? videoController;

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Camera Page"),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: const MyBottomNavigationBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              Expanded(child: buildVideoPlayer()),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CameraInferenceScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text(
                    'เปิดกล้องตรวจจับ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: pickVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text(
                    'อัปโหลดวิดีโอ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SingleImageScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 3, 203, 253),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.file_upload),
                  label: const Text(
                    'อัปโหลดรูปภาพ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> pickVideo() async {
    final XFile? pickedVideo = await picker.pickVideo(
      source: ImageSource.gallery,
    );
    if (pickedVideo != null) {
      final ext = pickedVideo.path.split('.').last.toLowerCase();
      if (ext != 'mp4') {
        _showSnackBar('กรุณาเลือกไฟล์วิดีโอ .mp4 เท่านั้น');
        log('Invalid video type selected: ${pickedVideo.path}');
        return;
      }

      await videoController?.dispose();
      videoFile = pickedVideo;
      videoController = VideoPlayerController.file(File(videoFile!.path))
        ..initialize()
            .then((_) {
              if (!mounted) return;
              setState(() {});
              videoController!.play();
            })
            .catchError((e) {
              _showSnackBar('ไม่สามารถเปิดวิดีโอได้');
              log('VideoPlayer initialize error: $e');
            });
      log("Picked video: ${videoFile!.path}");

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              VideoInferenceScreen(videoPath: videoFile!.path),
        ),
      );
    } else {
      log("No video selected");
    }
  }

  Widget buildVideoPlayer() {
    if (videoController == null) {
      return const Text("ยังไม่ได้เลือกวิดีโอ");
    }

    if (!videoController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: videoController!.value.aspectRatio,
            child: VideoPlayer(videoController!),
          ),
          if (!videoController!.value.isPlaying)
            const Icon(Icons.play_circle_fill, size: 64, color: Colors.white),
        ],
      ),
    );
  }
}
