import 'package:face_detection_final/FaceView/face_detection_view.dart';
import 'package:face_detection_final/screens/face_detection_screen.dart';

import 'package:face_detection_final/screens/registration.dart';
import 'package:flutter/material.dart';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Face Detection final",
      home: RegistrationScreen(),
    );
  }
}
