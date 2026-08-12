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

  // ✅ NOUVEAU : Récupérer l'utilisateur courant
  Future<UtilisateurModel?> getCurrentUser() async {
    try {
      if (_userModel == null) {
        await refreshCurrentUser();
      }
      return _userModel;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    }
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

  // ─── Connexion avec Google ───────────────────────────────────────────────
  Future<bool> loginWithGoogle() async {
    _setLoading(true);
    _clearErrors();
    try {
      _userModel = await _authService.signInWithGoogle();
      _setLoading(false);
      return _userModel != null;
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

  // ─── Inscription avec numéro de téléphone ────────────────────────────────
  Future<bool> registerWithPhone({
    required String telephone,
    required String nom,
    required String prenom,
    required String typeActivite,
    String? adresse,
  }) async {
    _setLoading(true);
    _clearErrors();
    try {
      _userModel = await _authService.signUpWithPhone(
        telephone: telephone,
        nom: nom,
        prenom: prenom,
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

  // ─── Connexion avec numéro de téléphone ──────────────────────────────────
  Future<bool> loginWithPhone(String telephone) async {
    _setLoading(true);
    _clearErrors();
    try {
      _userModel = await _authService.signInWithPhone(telephone);
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

  // ─── Enregistrer email de secours ────────────────────────────────────────
  Future<bool> saveEmailSecours(String email) async {
    _setLoading(true);
    _clearErrors();
    try {
      await _authService.enregistrerEmailSecours(email);
      await refreshCurrentUser(forceRefresh: true);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // ─── Lier compte Google ───────────────────────────────────────────────────
  Future<bool> linkGoogleAccount() async {
    _setLoading(true);
    _clearErrors();
    try {
      await _authService.lierCompteGoogle();
      await refreshCurrentUser(forceRefresh: true);
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