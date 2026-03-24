import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ CORRECTION : Enums en lowerCamelCase
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
    
    return TransactionModel(
      id: doc.id,
      commercantId: data['commercantId'] ?? '',
      type: data['type'] == 'recette' 
          ? TypeTransaction.recette 
          : TypeTransaction.depense,
      montant: (data['montant'] ?? 0.0).toDouble(),
      categorie: data['categorie'] ?? '',
      categorieId: data['categorieId'] ?? '',
      description: data['description'],
      date: (data['date'] as Timestamp).toDate(),
      photoRecu: data['photoRecu'],
      estSynchronise: data['estSynchronise'] ?? true,
      dateCreation: (data['dateCreation'] as Timestamp).toDate(),
      dateModification: data['dateModification'] != null
          ? (data['dateModification'] as Timestamp).toDate()
          : null,
      modePaiement: data['modePaiement'] != null
          ? _modePaiementFromString(data['modePaiement'])
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
      'type': type.name, // name retourne "recette" ou "depense"
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
          : null,
      'modePaiement': modePaiement?.name,
      'client': client,
      'fournisseur': fournisseur,
      'numeroFacture': numeroFacture,
    };
  }

  // Helper pour convertir string en enum ModePaiement
  static ModePaiement _modePaiementFromString(String mode) {
    // Convertir en minuscules pour gérer l'ancien format
    final lowerMode = mode.toLowerCase();
    switch (lowerMode) {
      case 'mobilemoney':
      case 'mobile_money':
        return ModePaiement.mobileMoney;
      case 'carte':
        return ModePaiement.carte;
      case 'cheque':
        return ModePaiement.cheque;
      default:
        return ModePaiement.especes;
    }
  }

  // CopyWith pour modification
  TransactionModel copyWith({
    String? id,
    String? commercantId,
    TypeTransaction? type,
    double? montant,
    String? categorie,
    String? categorieId,
    String? description,
    DateTime? date,
    String? photoRecu,
    bool? estSynchronise,
    DateTime? dateCreation,
    DateTime? dateModification,
    ModePaiement? modePaiement,
    String? client,
    String? fournisseur,
    String? numeroFacture,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      commercantId: commercantId ?? this.commercantId,
      type: type ?? this.type,
      montant: montant ?? this.montant,
      categorie: categorie ?? this.categorie,
      categorieId: categorieId ?? this.categorieId,
      description: description ?? this.description,
      date: date ?? this.date,
      photoRecu: photoRecu ?? this.photoRecu,
      estSynchronise: estSynchronise ?? this.estSynchronise,
      dateCreation: dateCreation ?? this.dateCreation,
      dateModification: dateModification ?? this.dateModification,
      modePaiement: modePaiement ?? this.modePaiement,
      client: client ?? this.client,
      fournisseur: fournisseur ?? this.fournisseur,
      numeroFacture: numeroFacture ?? this.numeroFacture,
    );
  }

  // Getters utiles
  bool get estRecette => type == TypeTransaction.recette;
  bool get estDepense => type == TypeTransaction.depense;
  
  // Impact sur le solde (positif pour recette, négatif pour dépense)
  double get impactSolde => estRecette ? montant : -montant;

  // Formater le montant avec le signe
  String get montantFormate {
    final signe = estRecette ? '+' : '-';
    return '$signe${montant.toStringAsFixed(0)} FCFA';
  }

  // Nom du mode de paiement en français
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