import 'package:flutter/material.dart';

class Character {
  final double radius = 14.0;

  void draw(Canvas canvas, Size size, double birdX, double birdY) {
    final birdPaint = Paint()..color = const Color(0xFFFFD700);
    final centerX = size.width / 2 + birdX * size.width / 2;
    final centerY = size.height / 2 + birdY * size.height / 2;
    canvas.drawCircle(Offset(centerX, centerY), radius, birdPaint);
  }
}