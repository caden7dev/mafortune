import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ CORRECTION : Enums en lowerCamelCase
enum PeriodeBilan { quotidien, hebdomadaire, mensuel, annuel, personnalise }

class BilanModel {
  final String id;
  final String commercantId;
  final PeriodeBilan periode;
  final DateTime dateDebut;
  final DateTime dateFin;
  final double totalRecettes;
  final double totalDepenses;
  final double beneficeNet;
  final int nombreRecettes;
  final int nombreDepenses;
  final DateTime dateCalcul;

  // Détails par catégorie
  final Map<String, double> recettesParCategorie;
  final Map<String, double> depensesParCategorie;

  // Comparaison avec période précédente
  final double? evolutionRecettes; // en pourcentage
  final double? evolutionDepenses; // en pourcentage
  final double? evolutionBenefice; // en pourcentage

  BilanModel({
    required this.id,
    required this.commercantId,
    required this.periode,
    required this.dateDebut,
    required this.dateFin,
    required this.totalRecettes,
    required this.totalDepenses,
    required this.beneficeNet,
    required this.nombreRecettes,
    required this.nombreDepenses,
    required this.dateCalcul,
    this.recettesParCategorie = const {},
    this.depensesParCategorie = const {},
    this.evolutionRecettes,
    this.evolutionDepenses,
    this.evolutionBenefice,
  });

  // Convertir depuis Firestore
  factory BilanModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return BilanModel(
      id: doc.id,
      commercantId: data['commercantId'] ?? '',
      periode: _periodeBilanFromString(data['periode']),
      dateDebut: (data['dateDebut'] as Timestamp).toDate(),
      dateFin: (data['dateFin'] as Timestamp).toDate(),
      totalRecettes: (data['totalRecettes'] ?? 0.0).toDouble(),
      totalDepenses: (data['totalDepenses'] ?? 0.0).toDouble(),
      beneficeNet: (data['beneficeNet'] ?? 0.0).toDouble(),
      nombreRecettes: data['nombreRecettes'] ?? 0,
      nombreDepenses: data['nombreDepenses'] ?? 0,
      dateCalcul: (data['dateCalcul'] as Timestamp).toDate(),
      recettesParCategorie: data['recettesParCategorie'] != null
          ? Map<String, double>.from(data['recettesParCategorie'])
          : {},
      depensesParCategorie: data['depensesParCategorie'] != null
          ? Map<String, double>.from(data['depensesParCategorie'])
          : {},
      evolutionRecettes: data['evolutionRecettes']?.toDouble(),
      evolutionDepenses: data['evolutionDepenses']?.toDouble(),
      evolutionBenefice: data['evolutionBenefice']?.toDouble(),
    );
  }

  // Convertir vers Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'commercantId': commercantId,
      'periode': periode.name, // name retourne "quotidien", "hebdomadaire", etc.
      'dateDebut': Timestamp.fromDate(dateDebut),
      'dateFin': Timestamp.fromDate(dateFin),
      'totalRecettes': totalRecettes,
      'totalDepenses': totalDepenses,
      'beneficeNet': beneficeNet,
      'nombreRecettes': nombreRecettes,
      'nombreDepenses': nombreDepenses,
      'dateCalcul': Timestamp.fromDate(dateCalcul),
      'recettesParCategorie': recettesParCategorie,
      'depensesParCategorie': depensesParCategorie,
      'evolutionRecettes': evolutionRecettes,
      'evolutionDepenses': evolutionDepenses,
      'evolutionBenefice': evolutionBenefice,
    };
  }

  // Helper pour convertir string en enum
  static PeriodeBilan _periodeBilanFromString(String? periode) {
    switch (periode) {
      case 'hebdomadaire':
        return PeriodeBilan.hebdomadaire;
      case 'mensuel':
        return PeriodeBilan.mensuel;
      case 'annuel':
        return PeriodeBilan.annuel;
      case 'personnalise':
        return PeriodeBilan.personnalise;
      default:
        return PeriodeBilan.quotidien;
    }
  }

  // CopyWith pour modification
  BilanModel copyWith({
    String? id,
    String? commercantId,
    PeriodeBilan? periode,
    DateTime? dateDebut,
    DateTime? dateFin,
    double? totalRecettes,
    double? totalDepenses,
    double? beneficeNet,
    int? nombreRecettes,
    int? nombreDepenses,
    DateTime? dateCalcul,
    Map<String, double>? recettesParCategorie,
    Map<String, double>? depensesParCategorie,
    double? evolutionRecettes,
    double? evolutionDepenses,
    double? evolutionBenefice,
  }) {
    return BilanModel(
      id: id ?? this.id,
      commercantId: commercantId ?? this.commercantId,
      periode: periode ?? this.periode,
      dateDebut: dateDebut ?? this.dateDebut,
      dateFin: dateFin ?? this.dateFin,
      totalRecettes: totalRecettes ?? this.totalRecettes,
      totalDepenses: totalDepenses ?? this.totalDepenses,
      beneficeNet: beneficeNet ?? this.beneficeNet,
      nombreRecettes: nombreRecettes ?? this.nombreRecettes,
      nombreDepenses: nombreDepenses ?? this.nombreDepenses,
      dateCalcul: dateCalcul ?? this.dateCalcul,
      recettesParCategorie: recettesParCategorie ?? this.recettesParCategorie,
      depensesParCategorie: depensesParCategorie ?? this.depensesParCategorie,
      evolutionRecettes: evolutionRecettes ?? this.evolutionRecettes,
      evolutionDepenses: evolutionDepenses ?? this.evolutionDepenses,
      evolutionBenefice: evolutionBenefice ?? this.evolutionBenefice,
    );
  }

  // Getters utiles
  bool get estBeneficiaire => beneficeNet >= 0;
  bool get estDeficitaire => beneficeNet < 0;

  // Taux de marge bénéficiaire (%)
  double get tauxMarge {
    if (totalRecettes == 0) return 0;
    return (beneficeNet / totalRecettes) * 100;
  }

  // Ratio recettes/dépenses
  double get ratioRecettesDepenses {
    if (totalDepenses == 0) return totalRecettes > 0 ? double.infinity : 0;
    return totalRecettes / totalDepenses;
  }

  // Moyenne par transaction
  double get moyenneParRecette {
    if (nombreRecettes == 0) return 0;
    return totalRecettes / nombreRecettes;
  }

  double get moyenneParDepense {
    if (nombreDepenses == 0) return 0;
    return totalDepenses / nombreDepenses;
  }

  // Formater le bénéfice avec signe
  String get beneficeFormate {
    final signe = estBeneficiaire ? '+' : '';
    return '$signe${beneficeNet.toStringAsFixed(0)} FCFA';
  }

  // Nom de la période en français
  String get periodeFr {
    switch (periode) {
      case PeriodeBilan.quotidien:
        return 'Quotidien';
      case PeriodeBilan.hebdomadaire:
        return 'Hebdomadaire';
      case PeriodeBilan.mensuel:
        return 'Mensuel';
      case PeriodeBilan.annuel:
        return 'Annuel';
      case PeriodeBilan.personnalise:
        return 'Personnalisé';
    }
  }

  // Formater l'évolution
  String? formatEvolution(double? evolution) {
    if (evolution == null) return null;
    final signe = evolution >= 0 ? '+' : '';
    return '$signe${evolution.toStringAsFixed(1)}%';
  }
}