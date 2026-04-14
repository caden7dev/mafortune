 import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/utilisateur_model.dart';
import '../models/categorie_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== UTILISATEURS ====================

  // Créer un utilisateur
  Future<void> createUtilisateur(UtilisateurModel utilisateur) async {
    try {
      await _firestore
          .collection('utilisateurs')
          .doc(utilisateur.id)
          .set(utilisateur.toFirestore());
    } catch (e) {
      throw 'Erreur lors de la création de l\'utilisateur';
    }
  }

  // Récupérer un utilisateur
  Future<UtilisateurModel?> getUtilisateur(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('utilisateurs')
          .doc(userId)
          .get();

      if (!doc.exists) return null;
      return UtilisateurModel.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  // Stream d'un utilisateur
  Stream<UtilisateurModel?> streamUtilisateur(String userId) {
    return _firestore
        .collection('utilisateurs')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return UtilisateurModel.fromFirestore(doc);
    });
  }

  // Mettre à jour un utilisateur
  Future<void> updateUtilisateur(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('utilisateurs')
          .doc(userId)
          .update(data);
    } catch (e) {
      throw 'Erreur lors de la mise à jour de l\'utilisateur';
    }
  }

  // Lister tous les utilisateurs (pour admin)
  Future<List<UtilisateurModel>> getAllUtilisateurs() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('utilisateurs')
          .orderBy('dateCreation', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => UtilisateurModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ==================== CATÉGORIES ====================

  // Initialiser les catégories par défaut
  Future<void> initializerCategoriesDefaut() async {
    try {
      final categories = CategorieModel.toutesLesCategoriesDefaut();
      
      for (var categorie in categories) {
        await _firestore
            .collection('categories')
            .doc(categorie.id)
            .set(categorie.toFirestore());
      }
    } catch (e) {
      throw 'Erreur lors de l\'initialisation des catégories';
    }
  }

  // Récupérer toutes les catégories actives
  Future<List<CategorieModel>> getCategories() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('categories')
          .where('estActive', isEqualTo: true)
          .orderBy('nom')
          .get();

      return snapshot.docs
          .map((doc) => CategorieModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Récupérer les catégories par type
  Future<List<CategorieModel>> getCategoriesByType(TypeCategorie type) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('categories')
          .where('type', isEqualTo: type.name)
          .where('estActive', isEqualTo: true)
          .orderBy('nom')
          .get();

      return snapshot.docs
          .map((doc) => CategorieModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Stream des catégories
  Stream<List<CategorieModel>> streamCategories() {
    return _firestore
        .collection('categories')
        .where('estActive', isEqualTo: true)
        .orderBy('nom')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CategorieModel.fromFirestore(doc))
            .toList());
  }

  // ==================== STATISTIQUES ====================

  // Compter le nombre total d'utilisateurs
  Future<int> countUtilisateurs() async {
    try {
      AggregateQuerySnapshot snapshot = await _firestore
          .collection('utilisateurs')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Compter les utilisateurs actifs
  Future<int> countUtilisateursActifs() async {
    try {
      AggregateQuerySnapshot snapshot = await _firestore
          .collection('utilisateurs')
          .where('estActif', isEqualTo: true)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Compter les transactions
  Future<int> countTransactions() async {
    try {
      AggregateQuerySnapshot snapshot = await _firestore
          .collection('transactions')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ==================== REQUÊTES BATCH ====================

  // Supprimer plusieurs documents
  Future<void> batchDelete(String collection, List<String> ids) async {
    try {
      WriteBatch batch = _firestore.batch();
      
      for (String id in ids) {
        batch.delete(_firestore.collection(collection).doc(id));
      }
      
      await batch.commit();
    } catch (e) {
      throw 'Erreur lors de la suppression en batch';
    }
  }

  // Mettre à jour plusieurs documents
  Future<void> batchUpdate(
    String collection,
    Map<String, Map<String, dynamic>> updates,
  ) async {
    try {
      WriteBatch batch = _firestore.batch();
      
      updates.forEach((id, data) {
        batch.update(_firestore.collection(collection).doc(id), data);
      });
      
      await batch.commit();
    } catch (e) {
      throw 'Erreur lors de la mise à jour en batch';
    }
  }
}