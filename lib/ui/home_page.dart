import 'package:flutter/material.dart';
import 'dart:async';
import '../core/ros_service.dart';
import '../utils/message_utils.dart';

class RosHomePage extends StatefulWidget {
  const RosHomePage({super.key, required this.title});

  final String title;

  @override
  State<RosHomePage> createState() => _RosHomePageState();
}

class _RosHomePageState extends State<RosHomePage> {
  final RosService _rosService = RosService();
  final List<String> _receivedMessages = [];
  final TextEditingController _messageController = TextEditingController();
  late StreamSubscription<String> _messageSubscription;

  @override
  void initState() {
    super.initState();
    _initializeRos();
    _setupMessageListener();
  }

  void _initializeRos() async {
    try {
      await _rosService.initialize();
      if (mounted) {
        setState(() {
          _receivedMessages.add("ROS node initialized successfully");
          _receivedMessages.add("Publisher ready - you can now send messages");
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _receivedMessages.add("Error initializing ROS: $e");
        });
      }
    }
  }

  void _setupMessageListener() {
    _messageSubscription = _rosService.messageStream.listen((message) {
      if (mounted) {
        setState(() {
          _receivedMessages.add(MessageUtils.formatReceivedMessage(message));
        });
      }
    });
  }

  void _sendMessage() async {
    final messageText = _messageController.text.trim();

    try {
      await _rosService.sendMessage(messageText);
      setState(() {
        _receivedMessages.add(MessageUtils.formatSentMessage(messageText));
      });
      _messageController.clear();
    } catch (e) {
      setState(() {
        _receivedMessages.add("Error: ${e.toString().replaceFirst('RosPublishException: ', '')}");
      });
    }
  }

  @override
  void dispose() {
    _messageSubscription.cancel();
    _messageController.dispose();
    _rosService.dispose();
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
            _buildMessageInputCard(context),
            const SizedBox(height: 16),
            _buildMessagesCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInputCard(BuildContext context) {
    return Card(
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
    );
  }

  Widget _buildMessagesCard(BuildContext context) {
    return Expanded(
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
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}