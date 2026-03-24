import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ CORRECTION : Enums en lowerCamelCase
enum TypeUtilisateur { commercant, administrateur, partenaire }

class UtilisateurModel {
  final String id;
  final String nom;
  final String prenom;
  final String email;
  final String telephone;
  final String? photo;
  final TypeUtilisateur typeUtilisateur;
  final bool estActif;
  final DateTime dateCreation;
  final DateTime? derniereSynchronisation;

  // Champs spécifiques aux commerçants
  final String? typeActivite;
  final String? adresse;
  final double? soldeActuel;

  // Champs spécifiques aux administrateurs
  final String? niveau;
  final List<String>? permissions;

  // Champs spécifiques aux partenaires
  final String? organisation;
  final String? secteurActivite;
  final DateTime? dateExpiration;

  UtilisateurModel({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.telephone,
    this.photo,
    required this.typeUtilisateur,
    this.estActif = true,
    required this.dateCreation,
    this.derniereSynchronisation,
    this.typeActivite,
    this.adresse,
    this.soldeActuel = 0.0,
    this.niveau,
    this.permissions,
    this.organisation,
    this.secteurActivite,
    this.dateExpiration,
  });

  // Convertir depuis Firestore
  factory UtilisateurModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return UtilisateurModel(
      id: doc.id,
      nom: data['nom'] ?? '',
      prenom: data['prenom'] ?? '',
      email: data['email'] ?? '',
      telephone: data['telephone'] ?? '',
      photo: data['photo'],
      typeUtilisateur: _typeUtilisateurFromString(data['typeUtilisateur']),
      estActif: data['estActif'] ?? true,
      dateCreation: (data['dateCreation'] as Timestamp).toDate(),
      derniereSynchronisation: data['derniereSynchronisation'] != null
          ? (data['derniereSynchronisation'] as Timestamp).toDate()
          : null,
      typeActivite: data['typeActivite'],
      adresse: data['adresse'],
      soldeActuel: (data['soldeActuel'] ?? 0.0).toDouble(),
      niveau: data['niveau'],
      permissions: data['permissions'] != null
          ? List<String>.from(data['permissions'])
          : null,
      organisation: data['organisation'],
      secteurActivite: data['secteurActivite'],
      dateExpiration: data['dateExpiration'] != null
          ? (data['dateExpiration'] as Timestamp).toDate()
          : null,
    );
  }

  // Convertir vers Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'telephone': telephone,
      'photo': photo,
      'typeUtilisateur': typeUtilisateur.name, // name retourne "commercant", "administrateur", etc.
      'estActif': estActif,
      'dateCreation': Timestamp.fromDate(dateCreation),
      'derniereSynchronisation': derniereSynchronisation != null
          ? Timestamp.fromDate(derniereSynchronisation!)
          : null,
      'typeActivite': typeActivite,
      'adresse': adresse,
      'soldeActuel': soldeActuel,
      'niveau': niveau,
      'permissions': permissions,
      'organisation': organisation,
      'secteurActivite': secteurActivite,
      'dateExpiration': dateExpiration != null
          ? Timestamp.fromDate(dateExpiration!)
          : null,
    };
  }

  // Helper pour convertir string en enum (rétrocompatible)
  static TypeUtilisateur _typeUtilisateurFromString(String? type) {
    if (type == null) return TypeUtilisateur.commercant;
    
    // Convertir en minuscules pour gérer l'ancien format
    final lowerType = type.toLowerCase();
    
    switch (lowerType) {
      case 'administrateur':
        return TypeUtilisateur.administrateur;
      case 'partenaire':
        return TypeUtilisateur.partenaire;
      default:
        return TypeUtilisateur.commercant;
    }
  }

  // CopyWith pour modification
  UtilisateurModel copyWith({
    String? id,
    String? nom,
    String? prenom,
    String? email,
    String? telephone,
    String? photo,
    TypeUtilisateur? typeUtilisateur,
    bool? estActif,
    DateTime? dateCreation,
    DateTime? derniereSynchronisation,
    String? typeActivite,
    String? adresse,
    double? soldeActuel,
    String? niveau,
    List<String>? permissions,
    String? organisation,
    String? secteurActivite,
    DateTime? dateExpiration,
  }) {
    return UtilisateurModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      photo: photo ?? this.photo,
      typeUtilisateur: typeUtilisateur ?? this.typeUtilisateur,
      estActif: estActif ?? this.estActif,
      dateCreation: dateCreation ?? this.dateCreation,
      derniereSynchronisation: derniereSynchronisation ?? this.derniereSynchronisation,
      typeActivite: typeActivite ?? this.typeActivite,
      adresse: adresse ?? this.adresse,
      soldeActuel: soldeActuel ?? this.soldeActuel,
      niveau: niveau ?? this.niveau,
      permissions: permissions ?? this.permissions,
      organisation: organisation ?? this.organisation,
      secteurActivite: secteurActivite ?? this.secteurActivite,
      dateExpiration: dateExpiration ?? this.dateExpiration,
    );
  }

  // Getter pour le nom complet
  String get nomComplet => '$prenom $nom';

  // Vérifier si c'est un commerçant
  bool get estCommercant => typeUtilisateur == TypeUtilisateur.commercant;

  // Vérifier si c'est un admin
  bool get estAdministrateur => typeUtilisateur == TypeUtilisateur.administrateur;

  // Vérifier si c'est un partenaire
  bool get estPartenaire => typeUtilisateur == TypeUtilisateur.partenaire;
}