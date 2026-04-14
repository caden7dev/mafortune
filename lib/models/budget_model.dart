import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetModel {
  final String id;
  final String commercantId;
  final DateTime mois;
  final double montant;
  final DateTime dateCreation;
  final DateTime? dateModification;

  BudgetModel({
    required this.id,
    required this.commercantId,
    required this.mois,
    required this.montant,
    required this.dateCreation,
    this.dateModification,
  });

  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BudgetModel(
      id: doc.id,
      commercantId: data['commercantId'] ?? '',
      mois: (data['mois'] as Timestamp).toDate(),
      montant: (data['montant'] as num).toDouble(),
      dateCreation: (data['dateCreation'] as Timestamp).toDate(),
      dateModification: data['dateModification'] != null
          ? (data['dateModification'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'commercantId': commercantId,
      'mois': Timestamp.fromDate(mois),
      'montant': montant,
      'dateCreation': Timestamp.fromDate(dateCreation),
      'dateModification': dateModification != null
          ? Timestamp.fromDate(dateModification!)
          : null,
    };
  }

  BudgetModel copyWith({
    String? id,
    String? commercantId,
    DateTime? mois,
    double? montant,
    DateTime? dateCreation,
    DateTime? dateModification,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      commercantId: commercantId ?? this.commercantId,
      mois: mois ?? this.mois,
      montant: montant ?? this.montant,
      dateCreation: dateCreation ?? this.dateCreation,
      dateModification: dateModification ?? this.dateModification,
    );
  }
}