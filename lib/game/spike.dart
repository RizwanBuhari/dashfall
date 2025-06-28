import 'package:flutter/material.dart';

class Spike {
  double x; // -1 to 1
  double y; // vertical position
  double radius;
  double speed;
  int direction; // +1 = right, -1 = left

  Spike({
    required this.x,
    required this.y,
    this.radius = 0.05,
    this.speed = 0.01,
    this.direction = 1,
  });

  void update() {
    x += speed * direction;
    if (x < -1.0) {
      x = -1.0;
      direction = 1;
    } else if (x > 1.0) {
      x = 1.0;
      direction = -1;
    }
  }

  Offset toOffset(Size size) {
    final centerX = size.width / 2 + x * size.width / 2;
    final centerY = size.height / 2 + y * size.height / 2;
    return Offset(centerX, centerY);
  }

  double getPixelRadius(Size size) => radius * size.width;
}