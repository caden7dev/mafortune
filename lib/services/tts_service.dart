import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _initialise = false;

  Future<void> _init() async {
    if (_initialise) return;
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.45); // lent et clair
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialise = true;
  }

  Future<void> parler(String texte) async {
    await _init();
    await _tts.stop();
    await _tts.speak(texte);
  }

  // Confirmation après vente
  Future<void> confirmerVente(double montant) async {
    final montantStr = _formaterMontant(montant);
    await parler('Vente de $montantStr francs enregistrée');
  }

  // Confirmation après dépense
  Future<void> confirmerDepense(double montant) async {
    final montantStr = _formaterMontant(montant);
    await parler('Dépense de $montantStr francs enregistrée');
  }

  // Bilan du jour
  Future<void> bilanDuJour(double recettes, double depenses) async {
    final r = _formaterMontant(recettes);
    final d = _formaterMontant(depenses);
    final solde = recettes - depenses;
    final s = _formaterMontant(solde.abs());
    final bilan = solde >= 0
        ? 'Tu as gagné $s francs aujourd\'hui'
        : 'Tu as perdu $s francs aujourd\'hui';
    await parler(
        'Aujourd\'hui, tu as vendu pour $r francs et dépensé $d francs. $bilan');
  }

  String _formaterMontant(double montant) {
    // Ex: 5000 → "5 000", 12500 → "12 500"
    final entier = montant.toInt();
    if (entier >= 1000) {
      final milliers = entier ~/ 1000;
      final reste = entier % 1000;
      if (reste == 0) return '$milliers mille';
      return '$milliers mille $reste';
    }
    return '$entier';
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}