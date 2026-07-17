import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Choisir une image depuis la galerie
  Future<File?> pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 500,
        maxHeight: 500,
      );
      
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
     debugPrint('❌ Erreur sélection image: $e');
      return null;
    }
  }

  // Prendre une photo avec l'appareil photo
  Future<File?> pickImageFromCamera() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 500,
        maxHeight: 500,
      );
      
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
     debugPrint('❌ Erreur prise de photo: $e');
      return null;
    }
  }

  // Uploader l'image vers Firebase Storage
  Future<String?> uploadImage(String userId, File imageFile) async {
    try {
      final fileName = 'profile_$userId.jpg';
      final ref = _storage.ref().child('profile_photos/$fileName');
      
      await ref.putFile(imageFile);
      final downloadUrl = await ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Erreur upload: $e');
      return null;
    }
  }

  // Supprimer l'image de Firebase Storage
  Future<void> deleteImage(String userId) async {
    try {
      final fileName = 'profile_$userId.jpg';
      final ref = _storage.ref().child('profile_photos/$fileName');
      await ref.delete();
    } catch (e) {
      debugPrint('❌ Erreur suppression: $e');
    }
  }
}