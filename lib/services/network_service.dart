import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class NetworkService extends ChangeNotifier {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _subscription; // ✅ List<>

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  ConnectivityResult _connectionType = ConnectivityResult.none;
  ConnectivityResult get connectionType => _connectionType;

  Future<void> initialize() async {
    final results = await _connectivity.checkConnectivity(); // ✅ retourne List
    _updateConnectionStatus(results);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _updateConnectionStatus(results); // ✅ List
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) { // ✅ List
    final primary = results.isNotEmpty ? results.first : ConnectivityResult.none;
    final isConnected = primary != ConnectivityResult.none;

    if (_isConnected != isConnected || _connectionType != primary) {
      _isConnected = isConnected;
      _connectionType = primary;
      notifyListeners();
    }
  }

  Future<bool> hasInternet() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none); // ✅
  }

  String getConnectionTypeLabel() {
    switch (_connectionType) {
      case ConnectivityResult.wifi:
        return 'Wi-Fi';
      case ConnectivityResult.mobile:
        return 'Réseau mobile';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      default:
        return 'Aucune connexion';
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}