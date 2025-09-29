import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../core/camera_service.dart';
import '../core/object_detection_service.dart';
import '../utils/detection_utils.dart';
import '../utils/simple_messages.dart';

class ObjectDetectionPage extends StatefulWidget {
  const ObjectDetectionPage({super.key});

  @override
  State<ObjectDetectionPage> createState() => _ObjectDetectionPageState();
}

class _ObjectDetectionPageState extends State<ObjectDetectionPage> {
  final CameraService _cameraService = CameraService();
  final ObjectDetectionService _detectionService = ObjectDetectionService();

  List<String> _detectionResults = [];
  List<String> _systemMessages = [];
  SimpleImageData? _currentImageData;
  bool _isConnected = false;

  late StreamSubscription<SimpleImageData> _imageSubscription;
  late StreamSubscription<DetectionResult> _detectionSubscription;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() async {
    try {
      await _cameraService.initialize();
      await _detectionService.initialize();

      _setupImageListener();
      _setupDetectionListener();

      if (mounted) {
        setState(() {
          _isConnected = true;
          _systemMessages.add("Camera and detection services initialized");
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _systemMessages.add("Error initializing services: $e");
        });
      }
    }
  }

  void _setupImageListener() {
    _imageSubscription = _cameraService.imageStream.listen((imageData) {
      if (mounted) {
        setState(() {
          _currentImageData = imageData;
        });
      }
    });
  }

  void _setupDetectionListener() {
    _detectionSubscription = _detectionService.detectionStream.listen((result) {
      print("UI received detection result: ${result.className}");
      if (mounted) {
        setState(() {
          _detectionResults.add(DetectionUtils.formatDetectionResult(result));
          _systemMessages.add("Detection received: ${result.className}");
          if (_detectionResults.length > 50) {
            _detectionResults.removeAt(0);
          }
          if (_systemMessages.length > 20) {
            _systemMessages.removeAt(0);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _imageSubscription.cancel();
    _detectionSubscription.cancel();
    _cameraService.dispose();
    _detectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Object Detection'),
        actions: [
          Icon(
            _isConnected ? Icons.wifi : Icons.wifi_off,
            color: _isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildCameraStreamCard(context),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildDetectionResultsCard(context)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSystemMessagesCard(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraStreamCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Camera Stream',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _currentImageData != null
                  ? _currentImageData!.hasImageData
                      ? _buildImageDisplay()
                      : _buildImageInfo()
                  : const Center(
                      child: Text(
                        'No camera stream available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionResultsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detection Results',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _detectionResults.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      _detectionResults[index],
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMessagesCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Messages',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _systemMessages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      _systemMessages[index],
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageDisplay() {
    try {
      final imageBytes = base64Decode(_currentImageData!.base64Data!);
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Image.memory(
              imageBytes,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(height: 8),
                      Text(
                        'Error displaying image: $error',
                        style: const TextStyle(color: Colors.red, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              '${_currentImageData!.width}x${_currentImageData!.height} • ${_currentImageData!.format}',
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ),
        ],
      );
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image, color: Colors.orange),
            const SizedBox(height: 8),
            Text(
              'Failed to decode image: $e',
              style: const TextStyle(color: Colors.orange, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildImageInfo() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Image: ${_currentImageData!.data}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          Text(
            'Format: ${_currentImageData!.format}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          Text(
            'Resolution: ${_currentImageData!.width}x${_currentImageData!.height}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}