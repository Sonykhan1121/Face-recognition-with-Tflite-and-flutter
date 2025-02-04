import 'dart:io';
import 'dart:typed_data';
import 'package:face_detection_final/screens/face_detection_screen.dart';
import 'package:flutter/material.dart';
import 'package:face_detection_final/database/user_database.dart';
import 'package:face_detection_final/screens/homepage.dart';
import 'package:face_detection_final/services/face_embedding.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:math';
import 'package:image/image.dart' as img;


class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  File? _image;
  String? _userName;
  final _db = UserDatabase();
  final _embedder = FaceEmbedder();

  Future<void> _loginWithFace() async {
    final imgFile = await Navigator.push<File?>(
      context,
      MaterialPageRoute(builder: (context) => FaceDetectionScreen()),
    );


    if (imgFile != null) {

      final croppedFace = await cropFace(imgFile);
      setState(() => _image = croppedFace != null?croppedFace:imgFile);
    } else {
      Fluttertoast.showToast(msg: 'You do not capture any image');
      return;
    }

    try {
      await _embedder.initialize();
      final inputEmbedding = await _embedder.getEmbedding(_image!);
      double maxSimilarity = 0.0;
      String? matchedUserName;
      int? matchedUserId;

      final users = await _db.getUsers();
      if (users.isEmpty) {
        Fluttertoast.showToast(msg: "No users Registered Yet");
        return;
      }

      for (var user in users) {
        List<double> storedEmbedding = user[UserDatabase.columnEmbedding];
        double similarity =
            _calculateSimilarity(inputEmbedding, storedEmbedding);

        if (similarity > maxSimilarity) {
          maxSimilarity = similarity;
          matchedUserName = user[UserDatabase.columnName];
          matchedUserId = user[UserDatabase.columnId];
        }
      }

      if (maxSimilarity >= 0.7 &&
          matchedUserName != null &&
          matchedUserId != null) {
        setState(() => _userName = matchedUserName);

        Fluttertoast.showToast(
            msg: "Hi $_userName, You are logged in successfully.",
            toastLength: Toast.LENGTH_LONG);

       Future.delayed(Duration(seconds: 1));
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => HomePage(userId: matchedUserId!)),
          );


        return;
      } else {
        Fluttertoast.showToast(
            msg: "Your face is not recognized.",
            textColor: Colors.white,
            backgroundColor: Colors.red);
        return;
      }
    } catch (e) {
      Fluttertoast.showToast(
          msg: "Error: ${e.runtimeType.toString()}",
          textColor: Colors.white,
          backgroundColor: Colors.red);
    }
  }

  Future<File?> cropFace(File imgFile) async {
    try {
      final inputImage = InputImage.fromFile(imgFile);
      final faceDetector = GoogleMlKit.vision.faceDetector(FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: true,
        minFaceSize: 0.25,
        performanceMode: FaceDetectorMode.accurate,
      ));

      final faces = await faceDetector.processImage(inputImage);
      await faceDetector.close();

      if (faces.isEmpty) {
        Fluttertoast.showToast(msg: "⚠️ No face detected!", backgroundColor: Colors.orange);
        return null;
      }

      // Load image into a processable format
      final imageBytes = await imgFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        Fluttertoast.showToast(msg: "⚠️ Invalid image format!", backgroundColor: Colors.red);
        return null;
      }

      // Get first detected face bounds
      final face = faces.first;
      final rect = face.boundingBox;

      if (rect.width <= 0 || rect.height <= 0) {
        Fluttertoast.showToast(msg: "⚠️ Face cropping failed!", backgroundColor: Colors.red);
        return null;
      }

      // Ensure cropping dimensions do not exceed image size
      int x = rect.left.toInt().clamp(0, image.width - 1);
      int y = rect.top.toInt().clamp(0, image.height - 1);
      int width = rect.width.toInt().clamp(1, image.width - x);
      int height = rect.height.toInt().clamp(1, image.height - y);

      // Crop the face
      final croppedFace = img.copyCrop(image, x: x, y: y, width: width, height: height);

      // Convert back to File
      final croppedFile = File(imgFile.path.replaceFirst('.jpg', '_face.jpg'));
      await croppedFile.writeAsBytes(img.encodeJpg(croppedFace));

      return croppedFile;
    } catch (e) {
      Fluttertoast.showToast(msg: "⚠️ Error cropping face: $e", backgroundColor: Colors.red);
      return null;
    }
  }

  double _calculateSimilarity(List<double> emb1, List<double> emb2) {
    double dotProduct = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < emb1.length; i++) {
      dotProduct += emb1[i] * emb2[i];
      normA += emb1[i] * emb1[i];
      normB += emb2[i] * emb2[i];
    }
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Login"),
          backgroundColor: Colors.pink,
          centerTitle: true),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_userName != null)
                Text("Hi, $_userName",
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              if (_image != null)
                CircleAvatar(radius: 80, backgroundImage: FileImage(_image!)),
              SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _loginWithFace,
                icon: Icon(Icons.face),
                label: Text("Login with Face"),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Fluttertoast.showToast(msg: 'Not implement yet');
                },
                icon: Icon(Icons.login),
                label: Text("Login with Others"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
