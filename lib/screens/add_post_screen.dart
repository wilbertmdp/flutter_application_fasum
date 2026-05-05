import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  XFile? _pickedFile;
  Uint8List? _imageBytes;
  String? _base64Image;
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  double? _latitude;
  double? _longitude;

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Choose Image Source"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
            child: Text("Camera"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
            child: Text("Gallery"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    // final pickedFile = await _picker.pickImage(source: source);
    // if (pickedFile != null) {
    //   setState(() {
    //     _image = File(pickedFile.path);
    //   });
    //   await _compressAndEncodeImage();
    // }

    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _pickedFile = pickedFile;
          _imageBytes = bytes;
          _descriptionController.clear();
        });
        await _compressAndEncodeImage();
        //await _generateDescriptionWithAI();
        if (_imageBytes == null) return;

        _base64Image = base64Encode(_imageBytes!);

        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _compressAndEncodeImage() async {
    if (_pickedFile == null || _imageBytes == null) return;
    if (kIsWeb) {
      // flutter_image_compress tidak mendukung web, gunakan bytes langsung
      setState(() {
        _base64Image = base64Encode(_imageBytes!);
      });
    } else {
      final compressedImage = await FlutterImageCompress.compressWithFile(
        File(_pickedFile!.path).path,
        quality: 50,
      );
      if (compressedImage == null) return;
      setState(() {
        _base64Image = base64Encode(compressedImage);
      });
    }
  }

  Future<void> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 10));
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      debugPrint('Failed to retrieve location: $e');
      setState(() {
        _latitude = null;
        _longitude = null;
      });
    }
  }

  Future<void> _submitPost() async {
    if (_base64Image == null || _descriptionController.text.isEmpty) return;
    setState(() => _isUploading = true);
    final now = DateTime.now().toIso8601String();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('User not found.')));
      return;
    }
    try {
      await _getLocation();
      // Ambil nama lengkap dari koleksi users
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final fullName = userDoc.data()?['fullName'] ?? 'Anonymous';
      await FirebaseFirestore.instance.collection('posts').add({
        'image': _base64Image,
        'description': _descriptionController.text,
        'category': 'Tidak diketahui',
        'createdAt': now,
        'latitude': _latitude,
        'longitude': _longitude,
        'fullName': fullName,
        'userId': uid, // optional: jika ingin simpan UID juga,
      });
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Upload failed: $e');
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload the post.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Post')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // container untuk menampilkan gambar yang dipilih atau ikon tambah foto jika belum ada gambar
          GestureDetector(
            onTap: _showImageSourceDialog,
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: _imageBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _imageBytes!,
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.add_a_photo,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // textfield untuk deskripsi
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Add a brief description...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // tombol kirim post
          ElevatedButton(
            onPressed: _isUploading ? null : _submitPost,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16),
              backgroundColor: Colors.green,
            ),
            child: _isUploading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Post', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
