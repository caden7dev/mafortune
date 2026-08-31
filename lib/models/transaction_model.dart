import 'package:cloud_firestore/cloud_firestore.dart';

enum TypeTransaction { recette, depense }
enum ModePaiement { especes, mobileMoney, cheque, virement, autre }

class TransactionModel {
  final String id;
  final String commercantId;
  final String categorieId;
  final double montant;
  final TypeTransaction type;
  final String? description;
  final DateTime date;
  final DateTime dateCreation;
  final DateTime? dateModification; // ✅ Ajouté
  final ModePaiement modePaiement;
  final String categorie;
  final String? produitId;
  final String? produitNom;

  TransactionModel({
    required this.id,
    required this.commercantId,
    required this.categorieId,
    required this.montant,
    required this.type,
    this.description,
    required this.date,
    required this.dateCreation,
    this.dateModification, // ✅ Ajouté
    required this.modePaiement,
    required this.categorie,
    this.produitId,
    this.produitNom,
  });

  bool get estRecette => type == TypeTransaction.recette;
  bool get estDepense => type == TypeTransaction.depense;

  double get impactSolde => estRecette ? montant : -montant;

  // ─── fromFirestore ────────────────────────────────────────────────────────
  factory TransactionModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TransactionModel(
      id: doc.id,
      commercantId: data['commercantId'] ?? '',
      categorieId: data['categorieId'] ?? '',
      montant: (data['montant'] as num?)?.toDouble() ?? 0.0,
      type: _typeFromString(data['type'] ?? 'recette'),
      description: data['description'],
      date: _toDateTime(data['date']),
      dateCreation: _toDateTime(data['dateCreation']),
      dateModification: data['dateModification'] != null
          ? _toDateTime(data['dateModification'])
          : null, // ✅ Gestion du nullable
      modePaiement: _modeFromString(data['modePaiement'] ?? 'especes'),
      categorie: data['categorie'] ?? '',
      produitId: data['produitId'],
      produitNom: data['produitNom'],
    );
  }

  // ─── toFirestore ──────────────────────────────────────────────────────────
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'commercantId': commercantId,
      'categorieId': categorieId,
      'montant': montant,
      'type': type.name,
      'description': description,
      'date': Timestamp.fromDate(date),
      'dateCreation': Timestamp.fromDate(dateCreation),
      'modePaiement': modePaiement.name,
      'categorie': categorie,
      'estRecette': estRecette,
    };

    // ✅ Ajoute dateModification si défini
    if (dateModification != null) {
      map['dateModification'] = Timestamp.fromDate(dateModification!);
    }

    // ✅ Ajoute produitId et produitNom seulement si définis
    if (produitId != null) map['produitId'] = produitId;
    if (produitNom != null) map['produitNom'] = produitNom;

    return map;
  }

  // ─── copyWith ─────────────────────────────────────────────────────────────
  TransactionModel copyWith({
    String? id,
    String? commercantId,
    String? categorieId,
    double? montant,
    TypeTransaction? type,
    String? description,
    DateTime? date,
    DateTime? dateCreation,
    DateTime? dateModification, // ✅ Ajouté
    ModePaiement? modePaiement,
    String? categorie,
    String? produitId,
    String? produitNom,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      commercantId: commercantId ?? this.commercantId,
      categorieId: categorieId ?? this.categorieId,
      montant: montant ?? this.montant,
      type: type ?? this.type,
      description: description ?? this.description,
      date: date ?? this.date,
      dateCreation: dateCreation ?? this.dateCreation,
      dateModification: dateModification ?? this.dateModification,
      modePaiement: modePaiement ?? this.modePaiement,
      categorie: categorie ?? this.categorie,
      produitId: produitId ?? this.produitId,
      produitNom: produitNom ?? this.produitNom,
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  static TypeTransaction _typeFromString(String value) {
    switch (value.toLowerCase()) {
      case 'recette':
        return TypeTransaction.recette;
      case 'depense':
      case 'dépense':
        return TypeTransaction.depense;
      default:
        return TypeTransaction.recette;
    }
  }

  static ModePaiement _modeFromString(String value) {
    switch (value.toLowerCase()) {
      case 'especes':
      case 'espèces':
        return ModePaiement.especes;
      case 'mobilemoney':
      case 'mobile_money':
        return ModePaiement.mobileMoney;
      case 'cheque':
      case 'chèque':
        return ModePaiement.cheque;
      case 'virement':
        return ModePaiement.virement;
      default:
        return ModePaiement.autre;
    }
  }

  @override
  String toString() {
    return 'TransactionModel(id: $id, montant: $montant, type: ${type.name}, '
        'description: $description, produitNom: $produitNom)';
  }
}