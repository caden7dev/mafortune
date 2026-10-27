import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetModel {
  final String id;
  final String commercantId;
  final DateTime mois; // Normalisé au 1er jour du mois (ex: 2026-07-01 00:00:00)
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

  // Convertir depuis Firestore
  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Normalisation de la date du budget pour éviter les décalages de jours/heures
    DateTime normaliserMois(dynamic dateVal) {
      if (dateVal == null) return DateTime(DateTime.now().year, DateTime.now().month, 1);
      final dt = (dateVal as Timestamp).toDate();
      return DateTime(dt.year, dt.month, 1);
    }

    // Conversion sécurisée du montant en double
    double convertMontant(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    return BudgetModel(
      id: doc.id,
      commercantId: data['commercantId'] ?? '',
      mois: normaliserMois(data['mois']),
      montant: convertMontant(data['montant']),
      dateCreation: data['dateCreation'] != null 
          ? (data['dateCreation'] as Timestamp).toDate() 
          : DateTime.now(),
      dateModification: data['dateModification'] != null
          ? (data['dateModification'] as Timestamp).toDate()
          : null,
    );
  }

  // Convertir vers Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'commercantId': commercantId,
      // On s'assure d'enregistrer le mois normalisé au 1er du mois à minuit
      'mois': Timestamp.fromDate(DateTime(mois.year, mois.month, 1)),
      'montant': montant,
      'dateCreation': Timestamp.fromDate(dateCreation),
      'dateModification': dateModification != null
          ? Timestamp.fromDate(dateModification!)
          : null,
    };
  }

  // CopyWith pour modification
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

  // ==========================================
  // GETTERS UTILES POUR L'INTERFACE ET L'UX
  // ==========================================

  /// Retourne un ID unique pour le budget du mois (ex: "2026_07")
  /// Très pratique pour l'utiliser comme ID de document Firestore 
  /// (un commerçant ne peut avoir qu'un seul budget par mois : ID = "commercantId_2026_07")
  String get idMoisKey {
    final moisStr = mois.month.toString().padLeft(2, '0');
    return '${mois.year}_$moisStr';
  }

  /// Retourne le nom du mois en français
  String get nomMoisFr {
    const moisFr = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    if (mois.month >= 1 && mois.month <= 12) {
      return '${moisFr[mois.month - 1]} ${mois.year}';
    }
    return '';
  }

  /// Formate le montant du budget pour l'affichage (ex: "150 000 FCFA")
  String get montantFormate {
    return '${montant.toStringAsFixed(0)} FCFA';
  }
}