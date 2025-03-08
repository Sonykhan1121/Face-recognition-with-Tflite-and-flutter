import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

class FaceDetectionScreen extends StatefulWidget {
  @override
  _FaceDetectionScreenState createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  late CameraController _controller;
  late FaceDetector _faceDetector;
  bool _isValidFace = false;
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  Size? _currentImageSize;
  Rect? _faceRect;

  // Add validation rectangle parameters
   double _validationSize = 512;
  late Rect _validationRect;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }
  @override
  void dispose() {
    _faceDetector.close();
    _controller.dispose();
    super.dispose();

  }

  void _initializeDetector() {
    _faceDetector = GoogleMlKit.vision.faceDetector(
      FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableContours: true,
        enableClassification: true,
        enableTracking: true,
        minFaceSize: 0.25,
      ),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      _controller = CameraController(cameras[1], ResolutionPreset.max);

      await _controller.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;

        double previewWidth = _controller.value.previewSize!.height;
        double previewHeight = _controller.value.previewSize!.width;

        double screenWidth = MediaQuery.of(context).size.width;
        double screenHeight = MediaQuery.of(context).size.height;

        // Calculate scaling factors
        double scaleX = screenWidth / previewWidth;
        double scaleY = screenHeight / previewHeight;

        // Set validation rectangle dynamically
        _validationSize = previewWidth * 0.8 * scaleX;
        _validationRect = Rect.fromCenter(
          center: Offset(screenWidth / 2, screenHeight / 2),
          width: _validationSize,
          height: _validationSize,
        );

        print('Preview Width: $previewWidth, Preview Height: $previewHeight');
        print('Screen Width: $screenWidth, Screen Height: $screenHeight');
        print('Validation Rect: $_validationRect');
      });

      _initializeDetector();
      _controller.startImageStream(_processCameraImage);
    } catch (e) {
      print("Error initializing camera: $e");
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || !_controller.value.isInitialized) return;
    if(!mounted)
      return;

    setState(() {
      _isProcessing = true;
      _currentImageSize = Size(image.width.toDouble(), image.height.toDouble());
    });

    final inputImage = _getInputImage(image);

    try {
      final faces = await _faceDetector.processImage(inputImage);
      print(faces);
      if (faces.isNotEmpty) {
        _validateFace(faces.first);
      } else {
        setState(() => _isValidFace = false);
      }
    } catch (e) {
      print("Face detection error: $e");
    } finally {
      if(mounted)
      {
        setState(() => _isProcessing = false);
      }

    }
  }

  InputImage _getInputImage(CameraImage image) {
    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _rotationFromCamera(),
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  InputImageRotation _rotationFromCamera() {
    switch (_controller.description.sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  void _validateFace(Face face) {
    // Get the face bounding box
    final faceRect = face.boundingBox;


    // Check if the face bounding box intersects with the validation rectangle
    final isFaceFullyInside = _validationRect.overlaps(faceRect);

    // Check face orientation
    final isFrontal = (face.headEulerAngleY?.abs() ?? 0) < 20 &&
        (face.headEulerAngleX?.abs() ?? 0) < 20;

    // Check if eyes are open
    final eyesOpen = (face.leftEyeOpenProbability ?? 1) > 0.8 &&
        (face.rightEyeOpenProbability ?? 1) > 0.8;

    if(!mounted) {
      return;
    }
    setState(() {
      _isValidFace = isFaceFullyInside && isFrontal && eyesOpen;
      _faceRect = faceRect;
    });
    // print('Face bounding box: $faceRect');
    // print('Validation rectangle: $_validationRect');
    // print('Is face fully inside: $isFaceFullyInside');
    // print("Face Rect: $faceRect");
    // print("Validation Rect: $_validationRect");
    // print("Is Overlap: ${_validationRect.overlaps(faceRect)}");

    if (_isValidFace) {
      Future.delayed(Duration(seconds: 2), _captureValidImage);
    }
  }

  void _captureValidImage() async {
    if (!_isValidFace || !_isCameraInitialized) {
      return; // Prevent capture if the face is not valid or camera is not initialized
    }

    if (_isCapturing) {
      return; // Prevent multiple captures
    }
    if(!mounted) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      // Ensure that the CameraController is not disposed
      if (!_controller.value.isInitialized) {
        print("Camera not initialized.");
        return;
      }

      final image = await _controller.takePicture();

      // Check if the widget is still mounted before navigating
      if (mounted) {
        // Delay before popping the result to avoid immediate navigation
        Future.delayed(Duration(seconds: 2), () {
          // Only pop the context if the widget is still mounted
          if (mounted) {
            Navigator.pop(context, File(image.path));
          }
        });
      }
    } catch (e) {
      print("Error capturing image: $e");
    } finally {
      if(mounted)
      {
        setState(() {
          _isCapturing = false;
        });
      }

    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isCameraInitialized
          ? Stack(
        children: [
          Positioned.fill(
            child: RotatedBox(
              quarterTurns: 3, // Rotate 270 degrees (90 counter-clockwise)
              child: SizedBox.expand(
                child: CameraPreview(_controller),
              ),
            ),
          ),
          // Add validation rectangle
          Center(
            child: Container(
              width: _validationRect.width,
              height: _validationRect.height,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isValidFace ? Colors.green : Colors.white,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),

            ),
          ),

          // Optional: Draw face bounding box

          _buildInstructions(),
        ],
      )
          : Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildInstructions() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Text(
            _isValidFace ? "Hold still..." : "Align face in the square",
            style: TextStyle(
              color: _isValidFace ? Colors.green : Colors.white,
              fontSize: 20,
              shadows: [
                Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1))
              ],
            ),
          ),
          SizedBox(height: 20),
          _isValidFace
              ? CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green))
              : Icon(Icons.face, size: 60, color: Colors.white),
        ],
      ),
    );
  }


}
