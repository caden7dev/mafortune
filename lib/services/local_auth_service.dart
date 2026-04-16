// lib/services/local_auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class LocalAuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  static const String _lastActivityKey = 'last_activity_time';
  static const int _inactivityTimeoutMinutes = 5;

  // ========================================
  // GESTION DU PIN DANS FIREBASE
  // ========================================

  /// Sauvegarde le PIN dans Firestore (création ou réinitialisation)
  Future<void> savePin(String pin) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    try {
      await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .set({
            'pin': pin,
            'pinCreatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      
      print('✅ PIN sauvegardé dans Firebase pour ${user.uid}');
    } catch (e) {
      print('❌ Erreur sauvegarde PIN: $e');
      throw Exception('Erreur lors de la sauvegarde du PIN');
    }
  }

  /// Vérifie si l'utilisateur a un PIN (Firestore)
  Future<bool> hasPin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .get();
      
      if (!doc.exists) return false;
      
      final pin = doc.data()?['pin'];
      final hasPin = pin != null && pin.toString().isNotEmpty;
      print('🔐 hasPin pour ${user.uid}: $hasPin');
      return hasPin;
    } catch (e) {
      print('❌ Erreur hasPin: $e');
      return false;
    }
  }

  /// Vérifie le PIN saisi par l'utilisateur
  Future<bool> verifyPin(String pin) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .get();
      
      if (!doc.exists) return false;
      
      final storedPin = doc.data()?['pin']?.toString();
      final isValid = (storedPin == pin);
      
      print('🔐 Vérification PIN: ${isValid ? "✅ VALIDE" : "❌ INVALIDE"}');
      
      if (isValid) {
        await updateLastActivity();
      }
      
      return isValid;
    } catch (e) {
      print('❌ Erreur verifyPin: $e');
      return false;
    }
  }

  /// Supprime le PIN de Firestore (optionnel)
  Future<void> clearPin() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .update({
            'pin': FieldValue.delete(),
            'pinCreatedAt': FieldValue.delete(),
          });
      print('✅ PIN supprimé de Firebase pour ${user.uid}');
    } catch (e) {
      print('❌ Erreur suppression PIN: $e');
    }
  }

  // ========================================
  // GESTION DE L'INACTIVITÉ (5 minutes)
  // ========================================

  /// Met à jour le timestamp de dernière activité (appeler après chaque action)
  Future<void> updateLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_lastActivityKey, now);
    print('⏱️ Activité mise à jour à ${DateTime.now()}');
  }

  /// Vérifie si l'utilisateur est inactif depuis plus de 5 minutes
  Future<bool> isInactive() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActivity = prefs.getInt(_lastActivityKey);
    
    if (lastActivity == null) {
      print('⏱️ Pas d\'activité enregistrée → inactif');
      return true;
    }
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final difference = now - lastActivity;
    final minutes = difference / (1000 * 60);
    
    final inactive = minutes >= _inactivityTimeoutMinutes;
    print('⏱️ Inactivité: ${minutes.toStringAsFixed(1)} min → ${inactive ? "INACTIF" : "ACTIF"}');
    return inactive;
  }

  /// Efface le timestamp d'activité (déconnexion)
  Future<void> clearActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastActivityKey);
    print('⏱️ Activité effacée');
  }

  // ========================================
  // BIOMÉTRIE
  // ========================================

  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

 Future<bool> authenticateWithBiometrics() async {
  try {
    final isAuthenticated = await _localAuth.authenticate(
      localizedReason: 'Vérifiez votre identité pour accéder à MaFortune',
      // ✅ Plus d'AuthenticationOptions en v3
    );
    
    if (isAuthenticated) {
      await updateLastActivity();
    }
    
    return isAuthenticated;
  } catch (e) {
    print('❌ Erreur biométrie: $e');
    return false;
  }
}
}