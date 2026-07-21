import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/utilisateur_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  UtilisateurModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;

  // ─── Getters ────────────────────────────────────────────────────────────────
  UtilisateurModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _userModel != null;

  // ─── Constructeur — écoute Firebase Auth en temps réel ───────────────────
  AuthProvider() {
    _authService.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser == null) {
        _userModel = null;
        notifyListeners();
      } else {
        await refreshCurrentUser();
      }
    });
  }

  // ─── Rafraîchir les données utilisateur ──────────────────────────────────
  Future<void> refreshCurrentUser({bool forceRefresh = false}) async {
    try {
      _userModel = await _authService.getCurrentUserData(
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  // ─── Connexion ────────────────────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearErrors();
    try {
      _userModel = await _authService.signIn(email: email, password: password);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // ─── Inscription commerçant ───────────────────────────────────────────────
  Future<bool> registerCommercant({
    required String email,
    required String password,
    required String nom,
    required String prenom,
    required String telephone,
    required String typeActivite,
    String? adresse,
  }) async {
    _setLoading(true);
    _clearErrors();
    try {
      _userModel = await _authService.signUpCommercant(
        email: email,
        password: password,
        nom: nom,
        prenom: prenom,
        telephone: telephone,
        typeActivite: typeActivite,
        adresse: adresse,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // ─── Mise à jour profil ───────────────────────────────────────────────────
  Future<bool> updateProfile(UtilisateurModel updatedUser) async {
    _setLoading(true);
    _clearErrors();
    try {
      _userModel = await _authService.updateUserProfile(updatedUser);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // ─── Déconnexion ──────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _authService.signOut();
    _userModel = null;
    notifyListeners();
  }

  // ─── Reset mot de passe ───────────────────────────────────────────────────
  Future<bool> sendPasswordReset(String email) async {
    _clearErrors();
    try {
      await _authService.resetPassword(email: email);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // ─── Helpers internes ────────────────────────────────────────────────────
  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _clearErrors() {
    _errorMessage = null;
  }
}