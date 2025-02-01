import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final int userId;

  const HomePage({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Welcome')),
      body: Center(child: Text('Welcome User #$userId')),
    );
  }
}