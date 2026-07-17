import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/utilisateur_model.dart';
import 'package:flutter/foundation.dart';

class PermissionService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Vérifie si l'utilisateur actuel est un administrateur
  Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .get();
      
      if (!doc.exists) return false;
      
      final utilisateur = UtilisateurModel.fromFirestore(doc);
      
      return utilisateur.typeUtilisateur == TypeUtilisateur.administrateur;
    } catch (e) {
     debugPrint('❌ Erreur vérification admin: $e');
      return false;
    }
  }

  /// Obtenir le type d'utilisateur actuel
  Future<TypeUtilisateur?> getCurrentUserType() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .get();
      
      if (!doc.exists) return null;
      
      final utilisateur = UtilisateurModel.fromFirestore(doc);
      
      return utilisateur.typeUtilisateur;
    } catch (e) {
      debugPrint('❌ Erreur récupération type utilisateur: $e');
      return null;
    }
  }
}