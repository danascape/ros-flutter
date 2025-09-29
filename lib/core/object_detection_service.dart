import 'dart:async';
import 'package:rcldart/rcldart.dart' as rcldart;
import 'package:rcldart/src/node.dart';
import 'package:rcldart/src/subscriber.dart' as rclsubscriber;
import 'package:std_msgs/std_msgs.dart';
import '../utils/simple_messages.dart';

// Use the SimpleDetection class from simple_messages.dart as DetectionResult
typedef DetectionResult = SimpleDetection;
typedef BoundingBox = SimpleBoundingBox;

class ObjectDetectionService {
  Node? _node;
  rclsubscriber.Subscriber? _detectionSubscription;
  Timer? _pollingTimer;
  late StreamController<DetectionResult> _detectionStreamController;

  Stream<DetectionResult> get detectionStream => _detectionStreamController.stream;

  ObjectDetectionService() {
    _detectionStreamController = StreamController<DetectionResult>.broadcast();
  }

  Future<void> initialize() async {
    try {
      _node = rcldart.RclDart().createNode("flutter_detection_node", "flutter_app");

      _detectionSubscription = _node!.createSubscriber<StdMsgsString>(
        topic_name: "/object_detections",
        messageType: StdMsgsString(""),
        callback: (msg) {
          print("Detection callback triggered!");
          _processDetectionMessage(msg);
        },
      );

      _detectionSubscription!.subscribe();
      await Future.delayed(Duration(milliseconds: 500));
      _startBackgroundPolling();
    } catch (e) {
      throw ObjectDetectionServiceException("Failed to initialize detection service: $e");
    }
  }

  void _processDetectionMessage(StdMsgsString msg) {
    try {
      print("Raw detection message received: '${msg.value}'");
      final detection = MessageConverter.parseDetectionMessage(msg.value);
      print("Parsed detection: ${detection.className} confidence=${detection.confidence}");
      _detectionStreamController.add(detection);
      print("Detection added to stream");
    } catch (e) {
      print("Error processing detection message: $e");
    }
  }

  void _startBackgroundPolling() {
    _pollingTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      try {
        if (_detectionSubscription != null) {
          _detectionSubscription!.take();
        }
      } catch (e) {
        // Ignore polling errors
      }
    });
  }

  bool get isInitialized => _detectionSubscription != null;

  void dispose() {
    _pollingTimer?.cancel();
    _detectionStreamController.close();
  }
}

class ObjectDetectionServiceException implements Exception {
  final String message;
  ObjectDetectionServiceException(this.message);

  @override
  String toString() => 'ObjectDetectionServiceException: $message';
}