import 'dart:io';
import 'dart:typed_data';
import 'package:face_detection_final/screens/face_detection_screen.dart';
import 'package:flutter/material.dart';
import 'package:face_detection_final/database/user_database.dart';
import 'package:face_detection_final/screens/homepage.dart';
import 'package:face_detection_final/services/face_embedding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:math';

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
      setState(() => _image = imgFile);
    }

    try {
      await _embedder.initialize();
      final inputEmbedding = await _embedder.getEmbedding(_image!);
      double maxSimilarity = 0.0;
      String? matchedUserName;
      int? matchedUserId;

      final users = await _db.getUsers();

      for (var user in users) {
        List<double> storedEmbedding = user[UserDatabase.columnEmbedding];
        double similarity = _calculateSimilarity(inputEmbedding, storedEmbedding);

        if (similarity > maxSimilarity) {
          maxSimilarity = similarity;
          matchedUserName = user[UserDatabase.columnName];
          matchedUserId = user[UserDatabase.columnId];
        }
      }

      if (maxSimilarity >= 0.7 && matchedUserName != null && matchedUserId != null) {
        setState(() => _userName = matchedUserName);

        Fluttertoast.showToast(msg: "Hi $_userName, You are logged in successfully.");
        await Future.delayed(Duration(seconds: 3));

        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(builder: (context) => HomePage(userId: matchedUserId!)),
        // );
      }


      Fluttertoast.showToast(msg: "Your face is not recognized.", textColor: Colors.white, backgroundColor: Colors.red);
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: ${e.toString()}", textColor: Colors.white, backgroundColor: Colors.red);
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
      appBar: AppBar(title: Text("Login"), backgroundColor: Colors.pink, centerTitle: true),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_userName != null) Text("Hi, $_userName", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              if (_image != null) CircleAvatar(radius: 80, backgroundImage: FileImage(_image!)),
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
