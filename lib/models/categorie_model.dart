import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Importé pour utiliser la classe Color dans les getters utiles

// ✅ Enums en lowerCamelCase
enum TypeCategorie { recette, depense }

class CategorieModel {
  final String id;
  final String nom;
  final TypeCategorie type;
  final String icone;
  final String couleur; // Stocké en format Hexadécimal (ex: "#4CAF50" ou "4CAF50")
  final String? description;
  final bool estParDefaut;
  final bool estActive;
  final DateTime dateCreation;

  CategorieModel({
    required this.id,
    required this.nom,
    required this.type,
    required this.icone,
    required this.couleur,
    this.description,
    this.estParDefaut = false,
    this.estActive = true,
    required this.dateCreation,
  });

  // Convertir depuis Firestore
  factory CategorieModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Convertir le type avec gestion de la rétrocompatibilité
    TypeCategorie getType(String? typeValue) {
      if (typeValue == null) return TypeCategorie.recette;
      final lowerType = typeValue.toLowerCase().trim();
      return lowerType == 'depense' ? TypeCategorie.depense : TypeCategorie.recette;
    }
    
    return CategorieModel(
      id: doc.id,
      nom: data['nom'] ?? '',
      type: getType(data['type']),
      icone: data['icone'] ?? '📊',
      couleur: data['couleur'] ?? '#4CAF50',
      description: data['description'],
      estParDefaut: data['estParDefaut'] ?? false,
      estActive: data['estActive'] ?? true,
      dateCreation: data['dateCreation'] != null 
          ? (data['dateCreation'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  // Convertir vers Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'nom': nom,
      'type': type.name, // retourne "recette" ou "depense"
      'icone': icone,
      'couleur': couleur,
      'description': description,
      'estParDefaut': estParDefaut,
      'estActive': estActive,
      'dateCreation': Timestamp.fromDate(dateCreation),
    };
  }

  // CopyWith pour modification
  CategorieModel copyWith({
    String? id,
    String? nom,
    TypeCategorie? type,
    String? icone,
    String? couleur,
    String? description,
    bool? estParDefaut,
    bool? estActive,
    DateTime? dateCreation,
  }) {
    return CategorieModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      type: type ?? this.type,
      icone: icone ?? this.icone,
      couleur: couleur ?? this.couleur,
      description: description ?? this.description,
      estParDefaut: estParDefaut ?? this.estParDefaut,
      estActive: estActive ?? this.estActive,
      dateCreation: dateCreation ?? this.dateCreation,
    );
  }

  // Getters utiles
  bool get estRecette => type == TypeCategorie.recette;
  bool get estDepense => type == TypeCategorie.depense;

  /// Convertit la chaîne Hexadécimale du modèle en objet [Color] utilisable directement dans Flutter.
  /// Gère les formats avec ou sans le symbole '#' (ex: '#4CAF50' ou 'FF4CAF50' ou '4CAF50').
  Color get colorValue {
    String hexColor = couleur.replaceAll('#', '').trim();
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor'; // Ajoute l'opacité par défaut (FF = 100%)
    }
    final intColor = int.tryParse(hexColor, radix: 16);
    return intColor != null ? Color(intColor) : const Color(0xFF4CAF50); // Fallback vert par défaut
  }

  // Catégories par défaut pour les recettes
  static List<CategorieModel> categoriesRecettesDefaut() {
    final now = DateTime.now();
    return [
      CategorieModel(
        id: 'rec_vente_produits',
        nom: 'Vente de produits',
        type: TypeCategorie.recette,
        icone: '🛒',
        couleur: '#4CAF50',
        description: 'Ventes de marchandises',
        estParDefaut: true,
        dateCreation: now,
      ),
      CategorieModel(
        id: 'rec_services',
        nom: 'Prestations de services',
        type: TypeCategorie.recette,
        icone: '🔧',
        couleur: '#2196F3',
        description: 'Services rendus',
        estParDefaut: true,
        dateCreation: now,
      ),
      CategorieModel(
        id: 'rec_autres',
        nom: 'Autres recettes',
        type: TypeCategorie.recette,
        icone: '💼',
        couleur: '#9C27B0',
        description: 'Autres sources de revenus',
        estParDefaut: true,
        dateCreation: now,
      ),
    ];
  }

  // Catégories par défaut pour les dépenses
  static List<CategorieModel> categoriesDepensesDefaut() {
    final now = DateTime.now();
    return [
      CategorieModel(
        id: 'dep_achats',
        nom: 'Achat de marchandises',
        type: TypeCategorie.depense,
        icone: '📦',
        couleur: '#F44336',
        description: 'Achats de stock',
        estParDefaut: true,
        dateCreation: now,
      ),
      CategorieModel(
        id: 'dep_transport',
        nom: 'Transport',
        type: TypeCategorie.depense,
        icone: '🚗',
        couleur: '#FF9800',
        description: 'Frais de déplacement',
        estParDefaut: true,
        dateCreation: now,
      ),
      CategorieModel(
        id: 'dep_loyer',
        nom: 'Loyer',
        type: TypeCategorie.depense,
        icone: '🏠',
        couleur: '#795548',
        description: 'Loyer du local',
        estParDefaut: true,
        dateCreation: now,
      ),
      CategorieModel(
        id: 'dep_electricite',
        nom: 'Électricité/Eau',
        type: TypeCategorie.depense,
        icone: '⚡',
        couleur: '#FFC107',
        description: 'Factures d\'électricité et eau',
        estParDefaut: true,
        dateCreation: now,
      ),
      CategorieModel(
        id: 'dep_salaires',
        nom: 'Salaires',
        type: TypeCategorie.depense,
        icone: '👥',
        couleur: '#3F51B5',
        description: 'Rémunération des employés',
        estParDefaut: true,
        dateCreation: now,
      ),
      CategorieModel(
        id: 'dep_autres',
        nom: 'Autres dépenses',
        type: TypeCategorie.depense,
        icone: '📝',
        couleur: '#607D8B',
        description: 'Autres frais',
        estParDefaut: true,
        dateCreation: now,
      ),
    ];
  }

  // Obtenir toutes les catégories par défaut
  static List<CategorieModel> toutesLesCategoriesDefaut() {
    return [
      ...categoriesRecettesDefaut(),
      ...categoriesDepensesDefaut(),
    ];
  }
}