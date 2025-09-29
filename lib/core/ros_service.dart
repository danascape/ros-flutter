import 'dart:async';
import 'package:rcldart/rcldart.dart' as rcldart;
import 'package:rcldart/src/node.dart';
import 'package:rcldart/src/publisher.dart' as publish;
import 'package:rcldart/src/subscriber.dart' as rclsubscriber;
import 'package:std_msgs/std_msgs.dart';
import '../utils/message_utils.dart';

class RosService {
  Node? _node;
  publish.Publisher? _publisher;
  rclsubscriber.Subscriber? _subscription;
  Timer? _pollingTimer;
  late StreamController<String> _messageStreamController;

  Stream<String> get messageStream => _messageStreamController.stream;

  RosService() {
    _messageStreamController = StreamController<String>.broadcast();
  }

  Future<void> initialize() async {
    try {
      _node = rcldart.RclDart().createNode("flutter_ros_node", "flutter_app");

      _publisher = _node!.createPublisher<StdMsgsString>(
        topic_name: "/flutter_messages",
        messageType: StdMsgsString(""),
      );

      _subscription = _node!.createSubscriber<StdMsgsString>(
        topic_name: "/ros_messages",
        messageType: StdMsgsString(""),
        callback: (msg) {
          _messageStreamController.add(msg.value);
        },
      );

      _subscription!.subscribe();

      await Future.delayed(Duration(milliseconds: 500));

      _startBackgroundPolling();
    } catch (e) {
      throw RosInitializationException("Failed to initialize ROS: $e");
    }
  }

  void _startBackgroundPolling() {
    _pollingTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      try {
        if (_subscription != null) {
          _subscription!.take();
        }
      } catch (e) {
        // Ignore polling errors
      }
    });
  }

  Future<void> sendMessage(String messageText) async {
    if (_publisher == null) {
      throw RosPublishException("Publisher not initialized");
    }

    if (!MessageUtils.isValidMessage(messageText)) {
      throw RosPublishException("Message is empty");
    }

    try {
      final message = MessageUtils.createFixedStdMsgsString(messageText);
      _publisher!.publish(message);
    } catch (e) {
      throw RosPublishException("Failed to publish message: $e");
    }
  }

  bool get isInitialized => _publisher != null && _subscription != null;

  void dispose() {
    _pollingTimer?.cancel();
    _messageStreamController.close();
  }
}

class RosException implements Exception {
  final String message;
  RosException(this.message);

  @override
  String toString() => 'RosException: $message';
}

class RosInitializationException extends RosException {
  RosInitializationException(String message) : super(message);
}

class RosPublishException extends RosException {
  RosPublishException(String message) : super(message);
}