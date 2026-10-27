import 'package:cloud_firestore/cloud_firestore.dart';

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
  final double soldeActuel;

  // Champs spécifiques aux administrateurs
  final String? niveau;
  final List<String>? permissions;

  // Champs spécifiques aux partenaires
  final String? organisation;
  final String? secteurActivite;
  final DateTime? dateExpiration;

  // 🔐 Champs de sécurité et récupération
  final String? emailSecours;
  final bool? googleLie;
  final String? googleEmail;
  final String? googleDisplayName;
  final String? googlePhotoUrl;

  // ✅ NOUVEAUX CHAMPS : Suppression douce
  final bool suppressionDemandee;
  final DateTime? dateSuppressionDemandee;

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
    this.emailSecours,
    this.googleLie = false,
    this.googleEmail,
    this.googleDisplayName,
    this.googlePhotoUrl,
    // ✅ Initialisation des nouveaux champs
    this.suppressionDemandee = false,
    this.dateSuppressionDemandee,
  });

  factory UtilisateurModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    List<String>? parseStringList(dynamic value) {
      if (value is List) {
        return value.map((item) => item.toString()).toList();
      }
      return null;
    }

    return UtilisateurModel(
      id: doc.id,
      nom: data['nom'] ?? '',
      prenom: data['prenom'] ?? '',
      email: data['email'] ?? '',
      telephone: data['telephone'] ?? '',
      photo: data['photo'] as String?,
      typeUtilisateur: _typeUtilisateurFromString(data['typeUtilisateur']),
      estActif: data['estActif'] ?? true,
      dateCreation: parseDateTime(data['dateCreation']) ?? DateTime.now(),
      derniereSynchronisation: parseDateTime(data['derniereSynchronisation']),
      typeActivite: data['typeActivite'] as String?,
      adresse: data['adresse'] as String?,
      soldeActuel: parseDouble(data['soldeActuel']),
      niveau: data['niveau'] as String?,
      permissions: parseStringList(data['permissions']),
      organisation: data['organisation'] as String?,
      secteurActivite: data['secteurActivite'] as String?,
      dateExpiration: parseDateTime(data['dateExpiration']),
      emailSecours: data['emailSecours'] as String?,
      googleLie: data['googleLie'] as bool? ?? false,
      googleEmail: data['googleEmail'] as String?,
      googleDisplayName: data['googleDisplayName'] as String?,
      googlePhotoUrl: data['googlePhotoUrl'] as String?,
      // ✅ Récupération des nouveaux champs
      suppressionDemandee: data['suppressionDemandee'] as bool? ?? false,
      dateSuppressionDemandee: parseDateTime(data['dateSuppressionDemandee']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'telephone': telephone,
      'photo': photo,
      'typeUtilisateur': typeUtilisateur.name,
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
      'emailSecours': emailSecours,
      'googleLie': googleLie,
      'googleEmail': googleEmail,
      'googleDisplayName': googleDisplayName,
      'googlePhotoUrl': googlePhotoUrl,
      // ✅ Ajout des nouveaux champs à l'export Firestore
      'suppressionDemandee': suppressionDemandee,
      'dateSuppressionDemandee': dateSuppressionDemandee != null
          ? Timestamp.fromDate(dateSuppressionDemandee!)
          : null,
    };
  }

  static TypeUtilisateur _typeUtilisateurFromString(String? type) {
    if (type == null) return TypeUtilisateur.commercant;
    final lowerType = type.toLowerCase();
    return TypeUtilisateur.values.firstWhere(
      (e) => e.name.toLowerCase() == lowerType,
      orElse: () => TypeUtilisateur.commercant,
    );
  }

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
    String? emailSecours,
    bool? googleLie,
    String? googleEmail,
    String? googleDisplayName,
    String? googlePhotoUrl,
    // ✅ Paramètres copyWith pour les nouveaux champs
    bool? suppressionDemandee,
    DateTime? dateSuppressionDemandee,
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
      emailSecours: emailSecours ?? this.emailSecours,
      googleLie: googleLie ?? this.googleLie,
      googleEmail: googleEmail ?? this.googleEmail,
      googleDisplayName: googleDisplayName ?? this.googleDisplayName,
      googlePhotoUrl: googlePhotoUrl ?? this.googlePhotoUrl,
      // ✅ Assignation copyWith
      suppressionDemandee: suppressionDemandee ?? this.suppressionDemandee,
      dateSuppressionDemandee: dateSuppressionDemandee ?? this.dateSuppressionDemandee,
    );
  }

  // ─── GETTERS UTILES ──────────────────────────────────────────────────────
  String get nomComplet => '$prenom $nom';
  bool get estCommercant => typeUtilisateur == TypeUtilisateur.commercant;
  bool get estAdministrateur => typeUtilisateur == TypeUtilisateur.administrateur;
  bool get estPartenaire => typeUtilisateur == TypeUtilisateur.partenaire;
  bool get aEmailSecours => emailSecours != null && emailSecours!.isNotEmpty;
  bool get aGoogleLie => googleLie == true;
  bool get estSecurise => aEmailSecours || aGoogleLie;

  // ✅ NOUVEAUX GETTERS POUR LA SUPPRESSION DOUCE
  DateTime? get dateSuppressionDefinitive =>
      dateSuppressionDemandee?.add(const Duration(days: 30));

  int get joursRestantsAvantSuppression {
    final date = dateSuppressionDefinitive;
    if (date == null) return 0;
    return date.difference(DateTime.now()).inDays.clamp(0, 30);
  }
}