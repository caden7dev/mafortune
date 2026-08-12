import 'package:cloud_firestore/cloud_firestore.dart';

enum TypeTransaction { recette, depense }

enum ModePaiement { especes, mobileMoney, carte, cheque }

class TransactionModel {
  final String id;
  final String commercantId;
  final TypeTransaction type;
  final double montant;
  final String categorie;
  final String categorieId;
  final String? description;
  final DateTime date;
  final String? photoRecu;
  final bool estSynchronise;
  final DateTime dateCreation;
  final DateTime? dateModification;

  // Champs spécifiques aux recettes
  final ModePaiement? modePaiement;
  final String? client;

  // Champs spécifiques aux dépenses
  final String? fournisseur;
  final String? numeroFacture;

  TransactionModel({
    required this.id,
    required this.commercantId,
    required this.type,
    required this.montant,
    required this.categorie,
    required this.categorieId,
    this.description,
    required this.date,
    this.photoRecu,
    this.estSynchronise = true,
    required this.dateCreation,
    this.dateModification,
    this.modePaiement,
    this.client,
    this.fournisseur,
    this.numeroFacture,
  });

  // Convertir depuis Firestore
  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    double convertMontant(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    TypeTransaction convertType(dynamic value) {
      if (value == null) return TypeTransaction.recette;
      final typeStr = value.toString().toLowerCase().trim();
      return typeStr == 'recette'
          ? TypeTransaction.recette
          : TypeTransaction.depense;
    }

    return TransactionModel(
      id: doc.id,
      commercantId: data['commercantId'] ?? '',
      type: convertType(data['type']),
      montant: convertMontant(data['montant']),
      categorie: data['categorie'] ?? '',
      categorieId: data['categorieId'] ?? '',
      description: data['description'],
      date: data['date'] != null
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
      photoRecu: data['photoRecu'],
      estSynchronise: data['estSynchronise'] ?? true,
      dateCreation: data['dateCreation'] != null
          ? (data['dateCreation'] as Timestamp).toDate()
          : DateTime.now(),
      dateModification: data['dateModification'] != null
          ? (data['dateModification'] as Timestamp).toDate()
          : null,
      modePaiement: data['modePaiement'] != null
          ? _modePaiementFromString(data['modePaiement'].toString())
          : null,
      client: data['client'],
      fournisseur: data['fournisseur'],
      numeroFacture: data['numeroFacture'],
    );
  }

  // Convertir vers Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'commercantId': commercantId,
      'type': type.name,
      'montant': montant,
      'categorie': categorie,
      'categorieId': categorieId,
      'description': description,
      'date': Timestamp.fromDate(date),
      'photoRecu': photoRecu,
      'estSynchronise': estSynchronise,
      'dateCreation': Timestamp.fromDate(dateCreation),
      'dateModification': dateModification != null
          ? Timestamp.fromDate(dateModification!)
          : FieldValue.serverTimestamp(),
      'modePaiement': modePaiement?.name,
      'client': client,
      'fournisseur': fournisseur,
      'numeroFacture': numeroFacture,
    };
  }

  static ModePaiement _modePaiementFromString(String mode) {
    final lowerMode = mode.toLowerCase().trim();
    switch (lowerMode) {
      case 'mobilemoney':
      case 'mobile_money':
        return ModePaiement.mobileMoney;
      case 'carte':
      case 'cartebancaire':
      case 'carte_bancaire':
        return ModePaiement.carte;
      case 'cheque':
        return ModePaiement.cheque;
      case 'especes':
      case 'espèces':
      default:
        return ModePaiement.especes;
    }
  }

  // CopyWith robuste supportant les valeurs nulles explicites
  TransactionModel copyWith({
    String? id,
    String? commercantId,
    TypeTransaction? type,
    double? montant,
    String? categorie,
    String? categorieId,
    Object? description = _absent,
    DateTime? date,
    Object? photoRecu = _absent,
    bool? estSynchronise,
    DateTime? dateCreation,
    Object? dateModification = _absent,
    Object? modePaiement = _absent,
    Object? client = _absent,
    Object? fournisseur = _absent,
    Object? numeroFacture = _absent,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      commercantId: commercantId ?? this.commercantId,
      type: type ?? this.type,
      montant: montant ?? this.montant,
      categorie: categorie ?? this.categorie,
      categorieId: categorieId ?? this.categorieId,
      description: description == _absent
          ? this.description
          : description as String?,
      date: date ?? this.date,
      photoRecu:
          photoRecu == _absent ? this.photoRecu : photoRecu as String?,
      estSynchronise: estSynchronise ?? this.estSynchronise,
      dateCreation: dateCreation ?? this.dateCreation,
      dateModification: dateModification == _absent
          ? this.dateModification
          : dateModification as DateTime?,
      modePaiement: modePaiement == _absent
          ? this.modePaiement
          : modePaiement as ModePaiement?,
      client: client == _absent ? this.client : client as String?,
      fournisseur:
          fournisseur == _absent ? this.fournisseur : fournisseur as String?,
      numeroFacture: numeroFacture == _absent
          ? this.numeroFacture
          : numeroFacture as String?,
    );
  }

  bool get estRecette => type == TypeTransaction.recette;
  bool get estDepense => type == TypeTransaction.depense;

  double get impactSolde => estRecette ? montant : -montant;

  String get montantFormate {
    final signe = estRecette ? '+' : '-';
    return '$signe${montant.toStringAsFixed(0)} FCFA';
  }

  String? get modePaiementFr {
    if (modePaiement == null) return null;
    switch (modePaiement!) {
      case ModePaiement.especes:
        return 'Espèces';
      case ModePaiement.mobileMoney:
        return 'Mobile Money';
      case ModePaiement.carte:
        return 'Carte bancaire';
      case ModePaiement.cheque:
        return 'Chèque';
    }
  }
}

// Sentinelle privée pour distinguer "paramètre non transmis" de "paramètre transmis à null"
const Object _absent = Object();