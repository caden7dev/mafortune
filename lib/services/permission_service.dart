import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/utilisateur_model.dart';

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

  /// ✅ NOUVELLE MÉTHODE CORRIGÉE : Vérifie le PIN en cherchant dans plusieurs clés possibles
  Future<bool> verifyPin(String enteredPin) async {
    try {
      final user = _auth.currentUser;
      final prefs = await SharedPreferences.getInstance();
      
      // On vérifie les clés les plus courantes utilisées pour stocker le PIN
      String? savedPin = prefs.getString('pin');
      savedPin ??= prefs.getString('user_pin');
      savedPin ??= prefs.getString('code_pin');
      
      if (user != null) {
        savedPin ??= prefs.getString('pin_${user.uid}');
      }
      
      if (savedPin == null) {
        debugPrint('⚠️ Aucun PIN trouvé dans le stockage local.');
        debugPrint('   Clés vérifiées: "pin", "user_pin", "code_pin", "pin_${user?.uid}"');
        return false; 
      }
      
      return savedPin == enteredPin;
    } catch (e) {
      debugPrint('❌ Erreur vérification PIN: $e');
      return false;
    }
  }
}