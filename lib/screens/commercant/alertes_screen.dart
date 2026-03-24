import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../models/utilisateur_model.dart';

class AlertesScreen extends StatefulWidget {
  const AlertesScreen({super.key});

  @override
  State<AlertesScreen> createState() => _AlertesScreenState();
}

class _AlertesScreenState extends State<AlertesScreen> {
  final AuthService _authService = AuthService();
  final TransactionService _transactionService = TransactionService();
  
  List<Map<String, dynamic>> _alertes = [];
  bool _isLoading = true;
  UtilisateurModel? _currentUser;
  
  // Paramètres des alertes
  final Map<String, bool> _alerteSettings = {
    'depenses_elevées': true,
    'rappels_paiement': true,
    'objectifs_atteints': true,
    'mises_a_jour': false,
  };
  
  // Seuil pour dépenses élevées (en pourcentage)
  final double _seuilDepensesElevees = 30;

  @override
  void initState() {
    super.initState();
    _loadAlertes();
    _chargerParametres();
  }

  Future<void> _chargerParametres() async {
    try {
      // Charger les paramètres depuis SharedPreferences ou Firestore
      // Pour l'instant, on garde les valeurs par défaut
    } catch (e) {
      // Supprimer print en production
      debugPrint('Erreur chargement paramètres: $e');
    }
  }

  Future<void> _sauvegarderParametres() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Paramètres sauvegardés'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur sauvegarde paramètres: $e');
    }
  }

  Future<void> _loadAlertes() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      _currentUser = await _authService.getCurrentUserData();
      if (_currentUser == null) return;
      
      final List<Map<String, dynamic>> alertesGenerees = [];
      
      // Charger toutes les transactions
      final allTransactions = await _transactionService.getTransactionsByCommercant(_currentUser!.id);
      
      if (allTransactions.isNotEmpty) {
        // 1. Analyser les dépenses du mois
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        
        final transactionsMois = allTransactions.where((t) => 
          t.date.isAfter(startOfMonth) && !t.estRecette
        ).toList();
        
        if (_alerteSettings['depenses_elevées'] == true) {
          // Calculer la moyenne des dépenses du mois précédent
          final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
          final endOfLastMonth = DateTime(now.year, now.month, 0, 23, 59, 59);
          
          final lastMonthTransactions = allTransactions.where((t) =>
            t.date.isAfter(startOfLastMonth) && 
            t.date.isBefore(endOfLastMonth) &&
            !t.estRecette
          ).toList();
          
          final totalDepensesMois = transactionsMois.fold(0.0, (sum, t) => sum + t.montant);
          final totalDepensesMoisPrec = lastMonthTransactions.fold(0.0, (sum, t) => sum + t.montant);
          
          if (totalDepensesMoisPrec > 0) {
            final pourcentageAugmentation = ((totalDepensesMois - totalDepensesMoisPrec) / totalDepensesMoisPrec) * 100;
            
            if (pourcentageAugmentation > _seuilDepensesElevees) {
              alertesGenerees.add({
                'id': 'depenses_${DateTime.now().millisecondsSinceEpoch}',
                'type': 'warning',
                'titre': '⚠️ Dépenses élevées',
                'message': 'Vos dépenses ont augmenté de ${pourcentageAugmentation.toInt()}% ce mois-ci (${_formatAmount(totalDepensesMois)} FCFA)',
                'date': DateTime.now(),
                'lue': false,
                'icon': '⚠️',
                'color': Colors.orange,
              });
            }
          }
        }
        
        // 2. Vérifier les objectifs
        if (_alerteSettings['objectifs_atteints'] == true) {
          final totalRecettesMois = transactionsMois.fold(0.0, (sum, t) => sum + t.montant);
          
          // Objectif par défaut: 500,000 FCFA
          const objectifMensuel = 500000.0;
          if (totalRecettesMois >= objectifMensuel) {
            alertesGenerees.add({
              'id': 'objectif_${DateTime.now().millisecondsSinceEpoch}',
              'type': 'success',
              'titre': '🎉 Objectif atteint !',
              'message': 'Vous avez dépassé votre objectif mensuel de ${_formatAmount(totalRecettesMois - objectifMensuel)} FCFA',
              'date': DateTime.now(),
              'lue': false,
              'icon': '🎉',
              'color': AppColors.primaryGreen,
            });
          }
        }
        
        // 3. Vérifier les rappels de paiement (si configuré)
        if (_alerteSettings['rappels_paiement'] == true) {
          final now = DateTime.now();
          // Simuler des rappels pour les échéances à venir
          // Dans une vraie application, vous auriez une collection "echeances"
          final List<Map<String, dynamic>> rapports = [
            {'titre': 'Loyer', 'date': DateTime(now.year, now.month, 5)},
            {'titre': 'Eau', 'date': DateTime(now.year, now.month, 10)},
            {'titre': 'Électricité', 'date': DateTime(now.year, now.month, 15)},
          ];
          
          for (var rappel in rapports) {
            final dateRappel = rappel['date'] as DateTime;
            final joursRestants = dateRappel.difference(now).inDays;
            if (joursRestants >= 1 && joursRestants <= 3) {
              alertesGenerees.add({
                'id': 'rappel_${rappel['titre']}_${DateTime.now().millisecondsSinceEpoch}',
                'type': 'info',
                'titre': '🔔 Rappel : ${rappel['titre']}',
                'message': 'Le paiement du ${rappel['titre']} est prévu dans $joursRestants jours',
                'date': DateTime.now(),
                'lue': false,
                'icon': '🔔',
                'color': Colors.blue,
              });
            }
          }
        }
      }
      
      // 4. Ajouter une alerte pour les mises à jour
      if (_alerteSettings['mises_a_jour'] == true) {
        alertesGenerees.add({
          'id': 'update_${DateTime.now().millisecondsSinceEpoch}',
          'type': 'info',
          'titre': '✨ Nouvelle fonctionnalité',
          'message': 'Vous pouvez maintenant exporter vos rapports en PDF et générer des rapports personnalisés !',
          'date': DateTime.now(),
          'lue': false,
          'icon': '✨',
          'color': Colors.purple,
        });
      }
      
      // Trier par date (plus récentes en premier)
      alertesGenerees.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      
      if (mounted) {
        setState(() {
          _alertes = alertesGenerees;
          _isLoading = false;
        });
      }
      
    } catch (e) {
      debugPrint('❌ Erreur chargement alertes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,###', 'fr_FR').format(amount).replaceAll(',', ' ');
  }

  int get _alertesNonLues => _alertes.where((a) => !a['lue']).length;

  void _marquerCommeLue(String alerteId) {
    setState(() {
      final index = _alertes.indexWhere((a) => a['id'] == alerteId);
      if (index != -1) {
        _alertes[index]['lue'] = true;
      }
    });
  }

  void _marquerToutCommeLu() {
    setState(() {
      for (var alerte in _alertes) {
        alerte['lue'] = true;
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Toutes les alertes marquées comme lues'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _supprimerAlerte(String alerteId) {
    setState(() {
      _alertes.removeWhere((a) => a['id'] == alerteId);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ Alerte supprimée'),
          backgroundColor: Colors.grey,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return 'Il y a ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Il y a ${diff.inHours}h';
    } else if (diff.inDays == 1) {
      return 'Hier';
    } else if (diff.inDays < 7) {
      return 'Il y a ${diff.inDays} jours';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  void _configurerAlertes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configurer les alertes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildAlerteSetting(
                'Alertes de dépenses élevées', 
                _alerteSettings['depenses_elevées'] ?? true,
                (val) => setStateDialog(() => _alerteSettings['depenses_elevées'] = val),
              ),
              _buildAlerteSetting(
                'Rappels de paiement', 
                _alerteSettings['rappels_paiement'] ?? true,
                (val) => setStateDialog(() => _alerteSettings['rappels_paiement'] = val),
              ),
              _buildAlerteSetting(
                'Objectifs atteints', 
                _alerteSettings['objectifs_atteints'] ?? true,
                (val) => setStateDialog(() => _alerteSettings['objectifs_atteints'] = val),
              ),
              _buildAlerteSetting(
                'Mises à jour produit', 
                _alerteSettings['mises_a_jour'] ?? false,
                (val) => setStateDialog(() => _alerteSettings['mises_a_jour'] = val),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _sauvegarderParametres();
                    _loadAlertes(); // Recharger avec les nouveaux paramètres
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Sauvegarder',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlerteSetting(String titre, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(titre, style: const TextStyle(fontSize: 15))),
          Switch(
            value: value,
            activeColor: AppColors.primaryGreen,
            onChanged: onChanged,
          ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Alertes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white),
                        onPressed: _configurerAlertes,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_alertesNonLues alertes non lues',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            if (_alertesNonLues > 0)
              Padding(
                padding: const EdgeInsets.all(20),
                child: OutlinedButton.icon(
                  onPressed: _marquerToutCommeLu,
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Tout marquer comme lu'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                  : _alertes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🔔', style: TextStyle(fontSize: 64)),
                              const SizedBox(height: 15),
                              Text(
                                'Aucune alerte',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Vous êtes à jour !',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _loadAlertes,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Actualiser'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadAlertes,
                          color: AppColors.primaryGreen,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _alertes.length,
                            itemBuilder: (context, index) {
                              final alerte = _alertes[index];
                              return Dismissible(
                                key: Key(alerte['id'] as String),
                                direction: DismissDirection.endToStart,
                                onDismissed: (direction) {
                                  _supprimerAlerte(alerte['id'] as String);
                                },
                                background: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: !(alerte['lue'] as bool)
                                          ? AppColors.primaryGreen.withValues(alpha: 0.3)
                                          : Colors.transparent,
                                      width: 2,
                                    ),
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
                                      onTap: () {
                                        if (!(alerte['lue'] as bool)) {
                                          _marquerCommeLue(alerte['id'] as String);
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: (alerte['color'] as Color).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  alerte['icon'] as String,
                                                  style: const TextStyle(fontSize: 24),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          alerte['titre'] as String,
                                                          style: const TextStyle(
                                                            fontSize: 15,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                      if (!(alerte['lue'] as bool))
                                                        Container(
                                                          width: 8,
                                                          height: 8,
                                                          decoration: const BoxDecoration(
                                                            color: AppColors.primaryGreen,
                                                            shape: BoxShape.circle,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    alerte['message'] as String,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    _formatDate(alerte['date'] as DateTime),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[400],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}