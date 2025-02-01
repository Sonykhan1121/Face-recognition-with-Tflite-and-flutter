import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
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
  Face? _currentFace;
  Size? _currentImageSize;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
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
      _controller = CameraController(cameras[1], ResolutionPreset.high);
      await _controller.initialize();
      if (!mounted) return;

      setState(() => _isCameraInitialized = true);
      _initializeDetector();
      _controller.startImageStream(_processCameraImage);
    } catch (e) {
      print("Error initializing camera: $e");
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || !_controller.value.isInitialized) return;

    setState(() {
      _isProcessing = true;
      _currentImageSize = Size(image.width.toDouble(), image.height.toDouble());
    });

    final inputImage = _getInputImage(image);

    try {
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isNotEmpty) {
        _validateFace(faces.first);
      } else {
        setState(() => _isValidFace = false);
      }
    } catch (e) {
      print("Face detection error: $e");
    } finally {
      setState(() => _isProcessing = false);
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
    final isFrontal = (face.headEulerAngleY?.abs() ?? 0) < 20 &&
        (face.headEulerAngleX?.abs() ?? 0) < 20;
    final eyesOpen = (face.leftEyeOpenProbability ?? 1) > 0.8 &&
        (face.rightEyeOpenProbability ?? 1) > 0.8;

    setState(() {
      _currentFace = face;
      _isValidFace = isFrontal && eyesOpen;
    });

    if (_isValidFace) {
      Future.delayed(Duration(seconds: 2), _captureValidImage);
    }
  }

  void _captureValidImage() async {
    if (_isValidFace) {
      final image = await _controller.takePicture();
      if (mounted) Navigator.pop(context, File(image.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isCameraInitialized
          ? Stack(
        children: [
          CameraPreview(_controller),
          if (_currentFace != null && _currentImageSize != null)
            CustomPaint(
              painter: FacePainter(
                face: _currentFace!,
                imageSize: _currentImageSize!,
                isFrontCamera: true,
                isValidFace: _isValidFace,
              ),
            ),
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
            _isValidFace ? "Hold still..." : "Align face in circle",
            style: TextStyle(
              color: _isValidFace ? Colors.green : Colors.white,
              fontSize: 20,
              shadows: [Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1))],
            ),
          ),
          SizedBox(height: 20),
          _isValidFace
              ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.green))
              : Icon(Icons.face, size: 60, color: Colors.white),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceDetector.close();
    super.dispose();
  }
}

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
    double right = face.boundingBox.right * scaleX;
    double top = face.boundingBox.top * scaleY;
    double bottom = face.boundingBox.bottom * scaleY;

    if (isFrontCamera) {
      final temp = left;
      left = size.width - right;
      right = size.width - temp;
    }

    final rect = Rect.fromLTRB(
      left.clamp(0, size.width),
      top.clamp(0, size.height),
      right.clamp(0, size.width),
      bottom.clamp(0, size.height),
    );

    final center = rect.center;
    final radius = math.max(rect.width, rect.height) / 2;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) => true;
}