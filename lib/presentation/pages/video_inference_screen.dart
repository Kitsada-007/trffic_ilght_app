import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:trffic_ilght_app/core/models/models.dart';
import 'package:trffic_ilght_app/services/model_manager.dart';
import 'package:ultralytics_yolo/utils/error_handler.dart';
import 'package:ultralytics_yolo/utils/map_converter.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoInferenceScreen extends StatefulWidget {
  final String videoPath;

  const VideoInferenceScreen({super.key, required this.videoPath});

  @override
  State<VideoInferenceScreen> createState() => _VideoInferenceScreenState();
}

class _VideoInferenceScreenState extends State<VideoInferenceScreen> {
  VideoPlayerController? _videoController;

  late final ModelManager _modelManager;
  YOLO? _yolo;
  bool _isModelReady = false;
  bool _isRunning = false;

  Uint8List? _lastAnnotatedFrame;
  List<Map<String, dynamic>> _lastDetections = [];
  String? _error;

  Timer? _timer;
  int _frameIndex = 0;

  static const Duration _sampleEvery = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _modelManager = ModelManager();
    _init();
  }

  Future<void> _init() async {
    await _initVideo();
    await _initModel();
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.file(File(widget.videoPath));
    _videoController = controller;
    await controller.initialize();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _initModel() async {
    try {
      final modelPath = await _modelManager.getModelPath(ModelType.bestFloat16traffic);
      if (modelPath == null) {
        throw Exception('Model path is null');
      }

      final yolo = YOLO(modelPath: modelPath, task: YOLOTask.detect);
      await yolo.loadModel();
      _yolo = yolo;

      if (!mounted) return;
      setState(() {
        _isModelReady = true;
        _error = null;
      });
    } catch (e) {
      final error = YOLOErrorHandler.handleError(e, 'Failed to load model');
      if (!mounted) return;
      setState(() {
        _error = error.message;
      });
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggleRun() async {
    if (!_isModelReady || _yolo == null) {
      _showSnackBar('Model is not ready');
      return;
    }

    if (_isRunning) {
      _stop();
      return;
    }

    setState(() {
      _isRunning = true;
      _error = null;
    });

    _frameIndex = 0;
    await _videoController?.play();

    _timer?.cancel();
    _timer = Timer.periodic(_sampleEvery, (_) => _processCurrentFrame());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _videoController?.pause();
    if (!mounted) return;
    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _processCurrentFrame() async {
    final vc = _videoController;
    final yolo = _yolo;
    if (vc == null || yolo == null) return;
    if (!vc.value.isInitialized) return;

    try {
      final positionMs = vc.value.position.inMilliseconds;
      final frameBytes = await VideoThumbnail.thumbnailData(
        video: widget.videoPath,
        imageFormat: ImageFormat.JPEG,
        timeMs: positionMs,
        quality: 75,
      );

      if (frameBytes == null) return;

      final result = await yolo.predict(frameBytes);

      if (!mounted) return;
      setState(() {
        _frameIndex++;
        _lastDetections = result['boxes'] is List
            ? MapConverter.convertBoxesList(result['boxes'] as List)
            : [];
        _lastAnnotatedFrame = result['annotatedImage'] as Uint8List?;
      });
    } catch (e) {
      final error = YOLOErrorHandler.handleError(e, 'Video inference failed');
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isRunning = false;
      });
      _stop();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vc = _videoController;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video MP4 Inference'),
        actions: [
          IconButton(
            onPressed: _toggleRun,
            icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
            tooltip: _isRunning ? 'Stop' : 'Run',
          ),
        ],
      ),
      body: Column(
        children: [
          if (vc == null || !vc.value.isInitialized)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            AspectRatio(
              aspectRatio: vc.value.aspectRatio,
              child: VideoPlayer(vc),
            ),

          if (!_isModelReady)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Model loading...'),
                ],
              ),
            ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Frame: $_frameIndex'),
                  const SizedBox(height: 8),
                  if (_lastAnnotatedFrame != null)
                    SizedBox(
                      height: 280,
                      child: Image.memory(_lastAnnotatedFrame!, fit: BoxFit.contain),
                    ),
                  const SizedBox(height: 8),
                  const Text('Detections:'),
                  Text(_lastDetections.toString()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
