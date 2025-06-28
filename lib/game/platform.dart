import 'package:flutter/material.dart';

enum PlatformType { solid, dashed }

class Platform {
  double x; // -1.0 (left) to 1.0 (right)
  double y; // vertical position
  final double width;
  final double height;
  final PlatformType type;
  bool isUsed = false; // for dashed platforms (break after 1 use)

  Platform({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.type,
  });

  Color get color {
    return type == PlatformType.solid ? Colors.grey[800]! : Colors.grey[400]!;
  }

  bool isDashed() => type == PlatformType.dashed;

  Rect toRect(Size canvasSize) {
    final cx = canvasSize.width / 2 + x * canvasSize.width / 2;
    final cy = canvasSize.height / 2 + y * canvasSize.height / 2;
    final w = width * canvasSize.width * 0.6;
    final h = height * canvasSize.height;
    return Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
  }
}