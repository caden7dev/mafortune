import 'dart:convert';
import 'package:crypto/crypto.dart'; // Nécessite l'ajout de `crypto: ^3.0.3` dans ton pubspec.yaml pour le hachage du PIN
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';

class LocalAuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  static const String _lastActivityKey = 'last_activity_time';
  static const int _inactivityTimeoutMinutes = 5;

  /// Helper pour hacher le code PIN avant stockage / comparaison
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  Future<void> savePin(String pin) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    try {
      final hashedPin = _hashPin(pin);
      await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .set({
            'pin': hashedPin, // ✅ Stockage sécurisé du PIN sous forme de Hash SHA-256
            'pinCreatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      debugPrint('✅ PIN sauvegardé (haché) dans Firebase pour ${user.uid}');
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e, stack,
        reason: 'Erreur sauvegarde PIN',
        fatal: false,
      );
     debugPrint('❌ Erreur sauvegarde PIN: $e');
      throw Exception('Erreur lors de la sauvegarde du PIN');
    }
  }

  Future<bool> hasPin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .get(const GetOptions(source: Source.serverAndCache));
      if (!doc.exists) return false;
      final pin = doc.data()?['pin'];
      return pin != null && pin.toString().isNotEmpty;
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e, stack,
        reason: 'Erreur lecture PIN',
        fatal: false,
      );
     debugPrint('❌ Erreur hasPin: $e');
      return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .get(const GetOptions(source: Source.serverAndCache));
      if (!doc.exists) return false;
      
      final storedPin = doc.data()?['pin']?.toString();
      final hashedInput = _hashPin(pin);
      final isValid = (storedPin == hashedInput);
      
     debugPrint('🔐 Vérification PIN: ${isValid ? "✅ VALIDE" : "❌ INVALIDE"}');
      if (isValid) {
        await updateLastActivity();
      }
      return isValid;
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e, stack,
        reason: 'Erreur vérification PIN Firestore',
        fatal: false,
      );
      debugPrint('❌ Erreur verifyPin: $e');
      return false;
    }
  }

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
      debugPrint('✅ PIN supprimé de Firebase pour ${user.uid}');
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e, stack,
        reason: 'Erreur suppression PIN',
        fatal: false,
      );
     debugPrint('❌ Erreur suppression PIN: $e');
    }
  }

  Future<void> updateLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_lastActivityKey, now);
  }

  Future<bool> isInactive() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActivity = prefs.getInt(_lastActivityKey);
    if (lastActivity == null) return true;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final difference = now - lastActivity;
    final minutes = difference / (1000 * 60);
    return minutes >= _inactivityTimeoutMinutes;
  }

  Future<void> clearActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastActivityKey);
  }

  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return canAuthenticateWithBiometrics && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Vérifiez votre identité pour accéder à MaFortune',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (isAuthenticated) {
        await updateLastActivity();
      }
      return isAuthenticated;
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e, stack,
        reason: 'Erreur biométrie',
        fatal: false,
      );
      debugPrint('❌ Erreur biométrie: $e');
      return false;
    }
  }
}