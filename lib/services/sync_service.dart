import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'local_database_service.dart';
import 'network_service.dart';

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final LocalDatabaseService _localDb = LocalDatabaseService();
  final NetworkService _networkService = NetworkService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  
  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;
  
  int _pendingSyncCount = 0;
  int get pendingSyncCount => _pendingSyncCount;

  Future<void> initialize() async {
    // Écouter les changements de connexion
    _networkService.addListener(_onNetworkChanged);
    await updatePendingCount();
  }

  void _onNetworkChanged() {
    if (_networkService.isConnected) {
      // Connexion rétablie, synchroniser
      syncData();
    }
  }

  Future<void> syncData() async {
    if (_isSyncing) return;
    if (!_networkService.isConnected) return;
    
    _isSyncing = true;
    notifyListeners();
    
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // 1. Envoyer les modifications locales vers Firestore
      await _syncLocalChangesToFirestore(user.uid);
      
      // 2. Récupérer les données distantes
      await _syncFirestoreToLocal(user.uid);
      
      _lastSyncTime = DateTime.now();
      
      // 3. Mettre à jour le compteur
      await updatePendingCount();
      
      print('✅ Synchronisation terminée avec succès');
    } catch (e) {
      print('❌ Erreur lors de la synchronisation: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _syncLocalChangesToFirestore(String userId) async {
    final pendingItems = await _localDb.getPendingSyncItems();
    
    for (var item in pendingItems) {
      try {
        final data = jsonDecode(item['data']);
        final collection = item['collection'];
        final operation = item['operation'];
        
        switch (operation) {
          case 'INSERT':
            await _firestore.collection(collection).add(data);
            break;
          case 'UPDATE':
            if (data['id'] != null) {
              await _firestore.collection(collection).doc(data['id']).update(data);
            }
            break;
          case 'DELETE':
            if (data['id'] != null) {
              await _firestore.collection(collection).doc(data['id']).delete();
            }
            break;
        }
        
        // Supprimer de la file d'attente après succès
        await _localDb.removeFromSyncQueue(item['id']);
        
      } catch (e) {
        // Incrémenter le compteur de tentatives
        await _localDb.incrementSyncAttempts(item['id']);
        print('⚠️ Erreur synchronisation item ${item['id']}: $e');
      }
    }
  }

  Future<void> _syncFirestoreToLocal(String userId) async {
    // Synchroniser les transactions
    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .where('commercantId', isEqualTo: userId)
        .get();
    
    for (var doc in transactionsSnapshot.docs) {
      final data = doc.data();
      data['id'] = doc.id;
      await _localDb.insertTransaction(data);
    }
    
    // Synchroniser les données utilisateur
    final userDoc = await _firestore.collection('utilisateurs').doc(userId).get();
    if (userDoc.exists) {
      final data = userDoc.data()!;
      data['id'] = userId;
      await _localDb.insertUtilisateur(data);
    }
  }

  Future<void> updatePendingCount() async {
    final pending = await _localDb.getPendingSyncItems();
    _pendingSyncCount = pending.length;
    notifyListeners();
  }

  Future<void> addToSyncQueue({
    required String operation,
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    await _localDb.addToSyncQueue(
      operation: operation,
      collection: collection,
      data: data,
    );
    await updatePendingCount();
    
    // Si connecté, synchroniser immédiatement
    if (_networkService.isConnected) {
      await syncData();
    }
  }

  Future<void> manualSync() async {
    if (!_networkService.isConnected) {
      throw Exception('Pas de connexion Internet');
    }
    await syncData();
  }

  @override
  void dispose() {
    _networkService.removeListener(_onNetworkChanged);
    super.dispose();
  }
}