import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class FaceEmbedder {
  late Interpreter _interpreter;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/facenet_512.tflite',
        options: InterpreterOptions()..threads = 4,
      );
      _verifyModel();
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize model: ${e.toString()}');
    }
  }

  Future<List<double>> getEmbedding(File imageFile) async {
    if (!_isInitialized) throw Exception('Embedder not initialized');

    try {
      final input = await _preprocessImage(imageFile);
      final output = Float32List(512);
      _interpreter.run(input.buffer, output.buffer);
      return _normalize(output);
    } catch (e) {
      throw Exception('Embedding failed: ${e.toString()}');
    }
  }

  Future<Float32List> _preprocessImage(File file) async {
    final image = img.decodeImage(await file.readAsBytes())!;
    final resized = img.copyResize(image, width: 160, height: 160);

    // Convert to RGB format and normalize pixels to [-1, 1] range
    final inputBuffer = Float32List(1 * 160 * 160 * 3);
    int index = 0;

    for (int y = 0; y < 160; y++) {
      for (int x = 0; x < 160; x++) {
        final pixel = resized.getPixel(x, y);
        // Verify channel order matches model expectations (RGB)
        inputBuffer[index++] = (pixel.r / 127.5) - 1.0; // Red
        inputBuffer[index++] = (pixel.g / 127.5) - 1.0; // Green
        inputBuffer[index++] = (pixel.b / 127.5) - 1.0; // Blue
      }
    }

    return inputBuffer;
  }

  List<double> _normalize(Float32List embedding) {
    final sum = embedding.fold(0.0, (p, c) => p + c * c);
    final norm = sqrt(sum);
    if (norm < 1e-12) throw Exception('Invalid embedding detected');
    return embedding.map((x) => x / norm).toList();
  }

  void _verifyModel() {
    final input = _interpreter.getInputTensors()[0];
    final output = _interpreter.getOutputTensors()[0];

    if (!(input.shape[0] == 1 &&
        input.shape[1] == 160 &&
        input.shape[2] == 160 &&
        input.shape[3] == 3)) {
      throw Exception('Invalid input shape: ${input.shape}');
    }

    if (!(output.shape[0] == 1 && output.shape[1] == 512)) {
      throw Exception('Invalid output shape: ${output.shape}');
    }

    if (input.type != TensorType.float32) {
      throw Exception('Input tensor must be Float32');
    }
  }

  void dispose() {
    _interpreter.close();
    _isInitialized = false;
  }
}