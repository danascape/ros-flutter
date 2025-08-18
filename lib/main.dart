import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:rcldart/rcldart.dart' as rcldart;
import 'package:rcldart/src/node.dart';
import 'package:rcldart/src/publisher.dart' as publish;
import 'package:rcldart/src/subscriber.dart' as rclsubscriber;
import 'package:std_msgs/std_msgs.dart';
import 'package:rcldart_utils/rcldart_utils.dart';

// Helper function to create a properly initialized StdMsgsString
StdMsgsString createFixedStdMsgsString(String message) {
  // Create the message with empty string first
  final msg = StdMsgsString("");
  
  // Manually set up the string with proper capacity
  final utf8String = message.toNativeUtf8();
  msg.data.ref.data = utf8String.cast<ffi.Char>();
  msg.data.ref.size = message.length;
  msg.data.ref.capacity = message.length + 1; // +1 for null terminator
  
  return msg;
}

void main() {
  rcldart.RclDart().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter ROS2 App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const RosHomePage(title: 'Flutter ROS2 Communication'),
    );
  }
}

class RosHomePage extends StatefulWidget {
  const RosHomePage({super.key, required this.title});

  final String title;

  @override
  State<RosHomePage> createState() => _RosHomePageState();
}

class _RosHomePageState extends State<RosHomePage> {
  Node? _node;
  publish.Publisher? _publisher;
  rclsubscriber.Subscriber? _subscription;
  final List<String> _receivedMessages = [];
  final TextEditingController _messageController = TextEditingController();
  late StreamController<String> _messageStreamController;
  late StreamSubscription<String> _messageSubscription;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _messageStreamController = StreamController<String>.broadcast();
    _initializeRos();
    _startBackgroundPolling();
    
    _messageSubscription = _messageStreamController.stream.listen((message) {
      if (mounted) {
        setState(() {
          _receivedMessages.add("Received: $message");
        });
      }
    });
  }

  void _initializeRos() async {
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
      
      // Wait a bit for publisher to establish connections
      await Future.delayed(Duration(milliseconds: 500));
      
      setState(() {
        _receivedMessages.add("ROS node initialized successfully");
        _receivedMessages.add("Publisher ready - you can now send messages");
      });
    } catch (e) {
      setState(() {
        _receivedMessages.add("Error initializing ROS: $e");
      });
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

  void _sendMessage() {
    if (_publisher == null) {
      setState(() {
        _receivedMessages.add("Error: Publisher not initialized");
      });
      return;
    }
    
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) {
      setState(() {
        _receivedMessages.add("Error: Message is empty");
      });
      return;
    }
    
    try {
      print("Sending message: '$messageText'");
      
      // Use our helper function to create properly initialized string
      final message = createFixedStdMsgsString(messageText);
      print("Fixed message created with value: '${message.value}'");
      print("Capacity should be: ${messageText.length + 1}");
      
      _publisher!.publish(message);
      print("Message published successfully with fixed capacity");
      
      setState(() {
        _receivedMessages.add("Sent: $messageText");
      });
      _messageController.clear();
    } catch (e) {
      setState(() {
        _receivedMessages.add("Error sending message: $e");
      });
      print("Publish error: $e");
      print("Error type: ${e.runtimeType}");
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageSubscription.cancel();
    _messageStreamController.close();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send Message to ROS',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              labelText: 'Message',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _sendMessage,
                          child: const Text('Send'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ROS Messages',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _receivedMessages.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Text(
                                _receivedMessages[index],
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
