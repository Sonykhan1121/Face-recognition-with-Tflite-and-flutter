import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

class FacePainter extends CustomPainter {
  final Face face;
  final Size imageSize;
  final bool isFrontCamera;
  final bool isValidFace;

  FacePainter({
    required this.face,
    required this.imageSize,
    required this.isFrontCamera,
    required this.isValidFace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = isValidFace ? Colors.green : Colors.blue;

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    double left = face.boundingBox.left * scaleX;
    double top = face.boundingBox.top * scaleY;
    double width = face.boundingBox.width * scaleX;
    double height = face.boundingBox.height * scaleY;

    double right = left + width;
    double bottom = top + height;

    if (isFrontCamera) {
      final tempLeft = left;
      left = size.width - right;
      right = size.width - tempLeft;
    }

    final rect = Rect.fromLTRB(
      left.clamp(0, size.width),
      top.clamp(0, size.height),
      right.clamp(0, size.width),
      bottom.clamp(0, size.height),
    );

    final center = rect.center;
    final radius = math.max(width, height) / 2;

    canvas.drawCircle(center, radius, paint);

    // Optional Debugging Output
    print("Face detected at: Left=$left, Top=$top, Width=$width, Height=$height");
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) => true;
}
