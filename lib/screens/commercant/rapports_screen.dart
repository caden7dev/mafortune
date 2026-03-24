import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';

class RapportsScreen extends StatefulWidget {
  const RapportsScreen({super.key});

  @override
  State<RapportsScreen> createState() => _RapportsScreenState();
}

class _RapportsScreenState extends State<RapportsScreen> {
  final AuthService _authService = AuthService();
  final TransactionService _transactionService = TransactionService();

  Map<String, dynamic> _rapportData = {};
  bool _isGenerating = false;

  final List<Map<String, dynamic>> _rapportsDisponibles = [
    {
      'id': 'mensuel',
      'titre': 'Rapport Mensuel',
      'description': 'Vue d\'ensemble de toutes vos transactions du mois',
      'icon': '📊',
      'color': AppColors.primaryGreen,
    },
    {
      'id': 'trimestriel',
      'titre': 'Rapport Trimestriel',
      'description': 'Analyse détaillée des 3 derniers mois',
      'icon': '📈',
      'color': Colors.blue,
    },
    {
      'id': 'annuel',
      'titre': 'Rapport Annuel',
      'description': 'Bilan complet de l\'année en cours',
      'icon': '📋',
      'color': Colors.orange,
    },
    {
      'id': 'personnalise',
      'titre': 'Rapport Personnalisé',
      'description': 'Choisissez votre période et vos critères',
      'icon': '⚙️',
      'color': Colors.purple,
    },
  ];

  Future<Map<String, dynamic>> _getRapportData(String typeRapport, {DateTime? dateDebut, DateTime? dateFin}) async {
    final user = await _authService.getCurrentUserData();
    if (user == null) return {};

    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    switch (typeRapport) {
      case 'mensuel':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'trimestriel':
        startDate = DateTime(now.year, now.month - 2, 1);
        break;
      case 'annuel':
        startDate = DateTime(now.year, 1, 1);
        break;
      case 'personnalise':
        if (dateDebut == null || dateFin == null) return {};
        startDate = dateDebut;
        endDate = dateFin;
        break;
      default:
        startDate = DateTime(now.year, now.month, 1);
    }

    final transactions = await _transactionService.getTransactionsByPeriode(
      user.id,
      startDate,
      endDate,
    );

    double totalRecettes = 0;
    double totalDepenses = 0;
    int nombreRecettes = 0;
    int nombreDepenses = 0;
    Map<String, double> recettesParCategorie = {};
    Map<String, double> depensesParCategorie = {};

    for (var t in transactions) {
      if (t.estRecette) {
        totalRecettes += t.montant;
        nombreRecettes++;
        recettesParCategorie[t.categorie] = (recettesParCategorie[t.categorie] ?? 0) + t.montant;
      } else {
        totalDepenses += t.montant;
        nombreDepenses++;
        depensesParCategorie[t.categorie] = (depensesParCategorie[t.categorie] ?? 0) + t.montant;
      }
    }

    return {
      'totalRecettes': totalRecettes,
      'totalDepenses': totalDepenses,
      'beneficeNet': totalRecettes - totalDepenses,
      'nombreRecettes': nombreRecettes,
      'nombreDepenses': nombreDepenses,
      'nombreTransactions': transactions.length,
      'recettesParCategorie': recettesParCategorie,
      'depensesParCategorie': depensesParCategorie,
      'periode': {
        'debut': startDate,
        'fin': endDate,
      },
    };
  }

  Future<void> _genererRapport(String typeRapport, {DateTime? dateDebut, DateTime? dateFin}) async {
    if (!mounted) return;
    setState(() => _isGenerating = true);

    try {
      final user = await _authService.getCurrentUserData();
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      final data = await _getRapportData(typeRapport, dateDebut: dateDebut, dateFin: dateFin);
      
      if (mounted) {
        setState(() => _rapportData = data);
        _afficherRapport(typeRapport);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _genererRapportPersonnalise() async {
    DateTime? dateDebut;
    DateTime? dateFin;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Rapport Personnalisé'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  dateDebut == null 
                      ? 'Date de début' 
                      : DateFormat('dd/MM/yyyy').format(dateDebut!),
                ),
                leading: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    locale: const Locale('fr', 'FR'),
                  );
                  if (picked != null) {
                    setStateDialog(() => dateDebut = picked);
                  }
                },
              ),
              ListTile(
                title: Text(
                  dateFin == null 
                      ? 'Date de fin' 
                      : DateFormat('dd/MM/yyyy').format(dateFin!),
                ),
                leading: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    locale: const Locale('fr', 'FR'),
                  );
                  if (picked != null) {
                    setStateDialog(() => dateFin = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (dateDebut != null && dateFin != null) {
                  Navigator.pop(context);
                  _genererRapport('personnalise', dateDebut: dateDebut, dateFin: dateFin);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Générer'),
            ),
          ],
        ),
      ),
    );
  }

  void _afficherRapport(String typeRapport) {
    final periode = _rapportData['periode'];
    if (periode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Données du rapport invalides'), backgroundColor: Colors.red),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Rapport ${typeRapport == 'personnalise' ? 'Personnalisé' : typeRapport}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  _buildRapportSection(
                    'Période', 
                    '${DateFormat('dd/MM/yyyy').format(periode['debut'])} - ${DateFormat('dd/MM/yyyy').format(periode['fin'])}'
                  ),
                  _buildRapportSection('Type', typeRapport),
                  const Divider(height: 30),
                  const Text(
                    'Résumé Financier',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  _buildRapportMetric(
                    'Total Recettes', 
                    '${_formatAmount(_rapportData['totalRecettes'] ?? 0)} FCFA', 
                    Colors.green,
                    _rapportData['nombreRecettes'] ?? 0,
                  ),
                  _buildRapportMetric(
                    'Total Dépenses', 
                    '${_formatAmount(_rapportData['totalDepenses'] ?? 0)} FCFA', 
                    Colors.red,
                    _rapportData['nombreDepenses'] ?? 0,
                  ),
                  _buildRapportMetric(
                    'Bénéfice Net', 
                    '${_formatAmount(_rapportData['beneficeNet'] ?? 0)} FCFA', 
                    AppColors.primaryGreen,
                    null,
                  ),
                  const SizedBox(height: 20),
                  
                  if (_rapportData['recettesParCategorie'] != null && 
                      (_rapportData['recettesParCategorie'] as Map).isNotEmpty)
                    _buildCategorieSection('Recettes par catégorie', _rapportData['recettesParCategorie'], Colors.green),
                  
                  if (_rapportData['depensesParCategorie'] != null && 
                      (_rapportData['depensesParCategorie'] as Map).isNotEmpty)
                    _buildCategorieSection('Dépenses par catégorie', _rapportData['depensesParCategorie'], Colors.red),
                  
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('📥 Export PDF à venir...')),
                      );
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Télécharger en PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorieSection(String titre, Map<String, double> data, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 15),
        Text(titre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...data.entries.map((entry) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(entry.key, style: const TextStyle(fontSize: 14)),
              Text(
                '${_formatAmount(entry.value)} FCFA',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        )),
      ],
    );
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,###', 'fr_FR').format(amount).replaceAll(',', ' ');
  }

  Widget _buildRapportSection(String titre, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(titre, style: TextStyle(color: Colors.grey[600])),
          Text(valeur, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRapportMetric(String label, String value, Color color, int? count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 15)),
              if (count != null)
                Text('$count transaction${count > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rapports',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Générez et consultez vos rapports financiers',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isGenerating
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppColors.primaryGreen),
                          SizedBox(height: 20),
                          Text('Génération du rapport en cours...'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _rapportsDisponibles.length,
                      itemBuilder: (context, index) {
                        final rapport = _rapportsDisponibles[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: rapport['id'] == 'personnalise'
                                  ? _genererRapportPersonnalise
                                  : () => _genererRapport(rapport['id']),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: (rapport['color'] as Color).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          rapport['icon'] as String,
                                          style: const TextStyle(fontSize: 30),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            rapport['titre'] as String,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            rapport['description'] as String,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}