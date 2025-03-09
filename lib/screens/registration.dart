import 'dart:io';

import 'package:face_detection_final/database/user_database.dart';
import 'package:face_detection_final/screens/face_detection_screen.dart';
import 'package:face_detection_final/screens/homepage.dart';
import 'package:face_detection_final/screens/login.dart';
import 'package:face_detection_final/services/face_embedding.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  File? _image;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final imgFile = await Navigator.push<File?>(
        context,
        MaterialPageRoute(builder: (context) => FaceDetectionScreen()),
      );

      if (imgFile == null) {
        Fluttertoast.showToast(msg: "⚠️ No image selected!", backgroundColor: Colors.orange);
        return;
      }

      // final croppedFace = await cropFace(imgFile);
      setState(() => _image =imgFile); // Use cropped face or original

      if (_image == null) {
        Fluttertoast.showToast(msg: "⚠️ Face not detected properly!", backgroundColor: Colors.orange);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "⚠️ Error picking image: $e", backgroundColor: Colors.red);
    }
  }


  // Future<File?> cropFace(File imgFile) async {
  //   try {
  //     final inputImage = InputImage.fromFile(imgFile);
  //     final faceDetector = GoogleMlKit.vision.faceDetector(FaceDetectorOptions(
  //       enableContours: true,
  //       enableClassification: true,
  //       enableLandmarks: true,
  //       enableTracking: true,
  //       minFaceSize: 0.25,
  //       performanceMode: FaceDetectorMode.accurate,
  //     ));
  //
  //     final faces = await faceDetector.processImage(inputImage);
  //     await faceDetector.close();
  //
  //     if (faces.isEmpty) {
  //       Fluttertoast.showToast(msg: "⚠️ No face detected!", backgroundColor: Colors.orange);
  //       return null;
  //     }
  //
  //     // Load image into a processable format
  //     final imageBytes = await imgFile.readAsBytes();
  //     final image = img.decodeImage(imageBytes);
  //     if (image == null) {
  //       Fluttertoast.showToast(msg: "⚠️ Invalid image format!", backgroundColor: Colors.red);
  //       return null;
  //     }
  //
  //     // Get first detected face bounds
  //     final face = faces.first;
  //     final rect = face.boundingBox;
  //
  //     if (rect.width <= 0 || rect.height <= 0) {
  //       Fluttertoast.showToast(msg: "⚠️ Face cropping failed!", backgroundColor: Colors.red);
  //       return null;
  //     }
  //
  //     // Ensure cropping dimensions do not exceed image size
  //     int x = rect.left.toInt().clamp(0, image.width - 1);
  //     int y = rect.top.toInt().clamp(0, image.height - 1);
  //     int width = rect.width.toInt().clamp(1, image.width - x);
  //     int height = rect.height.toInt().clamp(1, image.height - y);
  //
  //     // Crop the face
  //     final croppedFace = img.copyCrop(image, x: x, y: y, width: width, height: height);
  //
  //     // Convert back to File
  //     final croppedFile = File(imgFile.path.replaceFirst('.jpg', '_face.jpg'));
  //     await croppedFile.writeAsBytes(img.encodeJpg(croppedFace));
  //
  //     return croppedFile;
  //   } catch (e) {
  //     Fluttertoast.showToast(msg: "⚠️ Error cropping face: $e", backgroundColor: Colors.red);
  //     return null;
  //   }
  // }


  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate() || _image == null) {
      Fluttertoast.showToast(
        msg: "⚠️ Please fill up all the fields",
        textColor: Colors.red,
        backgroundColor: Colors.white,
      );
      return;
    }

    setState(() => _isProcessing = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final db = UserDatabase();
      if (await db.emailExists(_emailController.text)) {
        Navigator.pop(context); // Close loading dialog
        Fluttertoast.showToast(
          msg: "Email already registered!",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        setState(() => _isProcessing = false);
        return;
      }


      final embedder = FaceEmbedder();
      await embedder.initialize();
      final embedding = await embedder.getEmbedding(_image!);
      embedder.dispose();

      final userId = await db.insertUser({
        UserDatabase.columnName: _nameController.text,
        UserDatabase.columnEmail: _emailController.text,
        UserDatabase.columnEmbedding: embedding,
      });

      Navigator.pop(context); // Close loading dialog
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage(userId: userId)),
      );
    } catch (e) {
      Navigator.pop(context);
      Fluttertoast.showToast(
        msg: "Registration failed: ${e.toString()}",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context)



  {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Registration',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.pink,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 100,
                  backgroundImage: _image != null ? FileImage(_image!) : null,
                  child: _image == null ? const Icon(Icons.add_a_photo, size: 60) : null,
                ),
              ),
              const SizedBox(height: 20,),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => value!.isEmpty ? 'Enter name' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter email';
                  if (!isValidEmail(value)) return 'Enter valid email';
                  return null;
                },
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _registerUser,
                    child: const Text('Register'),
                  ),
                  const SizedBox(width: 100),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      );
                    },
                    child: const Text('Login'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool isValidEmail(String value) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value);
  }
}
