import 'dart:convert';
import 'package:flutter/material.dart';

class FullScreenImage extends StatelessWidget {
  final String imageBase64;
  final String heroTag;

  const FullScreenImage({
    super.key,
    required this.imageBase64,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 10,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Hero(
            tag: heroTag,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image.memory(
                base64Decode(imageBase64),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
