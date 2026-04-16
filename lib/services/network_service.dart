import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class NetworkService extends ChangeNotifier {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _subscription;
  
  bool _isConnected = true;
  bool get isConnected => _isConnected;
  
  ConnectivityResult _connectionType = ConnectivityResult.none;
  ConnectivityResult get connectionType => _connectionType;

  Future<void> initialize() async {
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);
    
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      _updateConnectionStatus(result);
    });
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final isConnected = result != ConnectivityResult.none;
    if (_isConnected != isConnected) {
      _isConnected = isConnected;
      _connectionType = result;
      notifyListeners();
    }
  }

  Future<bool> hasInternet() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
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