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
    final imgFile = await Navigator.push<File?>(
      context,
      MaterialPageRoute(builder: (context) => FaceDetectionScreen()),
    );

    if (imgFile != null) {
      setState(() => _image = imgFile);
    }
  }

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
  Widget build(BuildContext context) {
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
