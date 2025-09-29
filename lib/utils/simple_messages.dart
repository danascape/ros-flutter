import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:std_msgs/std_msgs.dart';

class SimpleImageData {
  final String data;
  final String format;
  final DateTime timestamp;
  final int width;
  final int height;
  final String? base64Data;

  SimpleImageData({
    required this.data,
    required this.format,
    required this.timestamp,
    this.width = 640,
    this.height = 480,
    this.base64Data,
  });

  factory SimpleImageData.fromString(String imageString) {
    return SimpleImageData(
      data: imageString,
      format: 'jpeg',
      timestamp: DateTime.now(),
    );
  }

  bool get hasImageData => base64Data != null && base64Data!.isNotEmpty;
}

class SimpleBoundingBox {
  final double x;
  final double y;
  final double width;
  final double height;

  SimpleBoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory SimpleBoundingBox.fromString(String bboxString) {
    final parts = bboxString.split(',');
    if (parts.length >= 4) {
      return SimpleBoundingBox(
        x: double.tryParse(parts[0]) ?? 0.0,
        y: double.tryParse(parts[1]) ?? 0.0,
        width: double.tryParse(parts[2]) ?? 0.0,
        height: double.tryParse(parts[3]) ?? 0.0,
      );
    }
    return SimpleBoundingBox(x: 0, y: 0, width: 0, height: 0);
  }

  @override
  String toString() {
    return '$x,$y,$width,$height';
  }
}

class SimpleDetection {
  final String className;
  final double confidence;
  final SimpleBoundingBox boundingBox;
  final DateTime timestamp;
  final String? distance;
  final String? dangerLevel;

  SimpleDetection({
    required this.className,
    required this.confidence,
    required this.boundingBox,
    required this.timestamp,
    this.distance,
    this.dangerLevel,
  });

  factory SimpleDetection.fromString(String detectionString) {
    final parts = detectionString.split('|');
    if (parts.length >= 3) {
      return SimpleDetection(
        className: parts[0],
        confidence: double.tryParse(parts[1]) ?? 0.0,
        boundingBox: SimpleBoundingBox.fromString(parts[2]),
        timestamp: DateTime.now(),
        distance: parts.length > 3 ? parts[3] : null,
        dangerLevel: parts.length > 4 ? parts[4] : null,
      );
    }
    return SimpleDetection(
      className: 'unknown',
      confidence: 0.0,
      boundingBox: SimpleBoundingBox(x: 0, y: 0, width: 0, height: 0),
      timestamp: DateTime.now(),
    );
  }

  bool get isCritical => dangerLevel == 'critical';
  bool get isWarning => dangerLevel == 'warning' || dangerLevel == 'critical';

  @override
  String toString() {
    String result = '$className|$confidence|${boundingBox.toString()}';
    if (distance != null) result += '|$distance';
    if (dangerLevel != null) result += '|$dangerLevel';
    return result;
  }
}

class MessageConverter {
  static StdMsgsString createImageMessage(SimpleImageData imageData) {
    final messageText = 'IMG:${imageData.format}:${imageData.data.length}:${imageData.width}x${imageData.height}';
    final msg = StdMsgsString("");

    final utf8String = messageText.toNativeUtf8();
    msg.data.ref.data = utf8String.cast<ffi.Char>();
    msg.data.ref.size = messageText.length;
    msg.data.ref.capacity = messageText.length + 1;

    return msg;
  }

  static StdMsgsString createDetectionMessage(SimpleDetection detection) {
    final messageText = 'DET:${detection.toString()}';
    final msg = StdMsgsString("");

    final utf8String = messageText.toNativeUtf8();
    msg.data.ref.data = utf8String.cast<ffi.Char>();
    msg.data.ref.size = messageText.length;
    msg.data.ref.capacity = messageText.length + 1;

    return msg;
  }

  static SimpleImageData parseImageMessage(String message) {
    // Handle new format: IMG_DATA:format:width:height:base64_data
    if (message.startsWith('IMG_DATA:')) {
      final parts = message.substring(9).split(':');
      if (parts.length >= 4) {
        final format = parts[0];
        final width = int.tryParse(parts[1]) ?? 320;
        final height = int.tryParse(parts[2]) ?? 240;
        final base64Data = parts.length > 3 ? parts.sublist(3).join(':') : '';

        return SimpleImageData(
          data: 'Image data (${base64Data.length} chars encoded)',
          format: format,
          timestamp: DateTime.now(),
          width: width,
          height: height,
          base64Data: base64Data,
        );
      }
    }
    // Handle old format: IMG:format:size:dimensions
    else if (message.startsWith('IMG:')) {
      final parts = message.substring(4).split(':');
      if (parts.length >= 4) {
        final format = parts[0];
        final dataLength = int.tryParse(parts[1]) ?? 0;
        final dimensions = parts[2].split('x');
        final width = int.tryParse(dimensions[0]) ?? 640;
        final height = int.tryParse(dimensions.length > 1 ? dimensions[1] : '480') ?? 480;

        return SimpleImageData(
          data: 'Binary data ($dataLength bytes)',
          format: format,
          timestamp: DateTime.now(),
          width: width,
          height: height,
        );
      }
    }
    return SimpleImageData(
      data: message,
      format: 'unknown',
      timestamp: DateTime.now(),
    );
  }

  static SimpleDetection parseDetectionMessage(String message) {
    if (message.startsWith('DET:')) {
      return SimpleDetection.fromString(message.substring(4));
    }
    return SimpleDetection.fromString(message);
  }
}