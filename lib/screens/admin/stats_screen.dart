import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/permission_service.dart';
import '../../widgets/screenshot_wrapper.dart';

class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PermissionService _permissionService = PermissionService();
  
  bool _isLoading = true;
  bool _isAdmin = false;
  
  int _totalUsers = 0;
  int _totalCommercants = 0;
  int _totalAdmins = 0;
  int _totalTransactions = 0;
  double _totalRecettes = 0.0;
  double _totalDepenses = 0.0;
  double _beneficeNet = 0.0;
  
  Map<String, double> _recettesParMois = {};
  Map<String, double> _depensesParMois = {};

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    final isAdmin = await _permissionService.isAdmin();
    if (!isAdmin && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Accès refusé : Administrateur uniquement'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
      return;
    }
    setState(() => _isAdmin = true);
    await _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    
    try {
      final usersSnapshot = await _firestore.collection('utilisateurs').get();
      _totalUsers = usersSnapshot.docs.length;
      _totalCommercants = usersSnapshot.docs
          .where((doc) => doc.data()['typeUtilisateur']?.toString().trim() == 'commercant')
          .length;
      _totalAdmins = usersSnapshot.docs
          .where((doc) => doc.data()['typeUtilisateur']?.toString().trim() == 'administrateur')
          .length;
      
      final transactionsSnapshot = await _firestore.collection('transactions').get();
      _totalTransactions = transactionsSnapshot.docs.length;
      
      _recettesParMois.clear();
      _depensesParMois.clear();
      
      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data();
        final type = data['type'] as String?;
        final montant = (data['montant'] as num?)?.toDouble() ?? 0.0;
        final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        final moisKey = DateFormat('MMM yyyy', 'fr_FR').format(date);
        
        if (type == 'recette') {
          _totalRecettes += montant;
          _recettesParMois[moisKey] = (_recettesParMois[moisKey] ?? 0) + montant;
        } else if (type == 'depense') {
          _totalDepenses += montant;
          _depensesParMois[moisKey] = (_depensesParMois[moisKey] ?? 0) + montant;
        }
      }
      
      _beneficeNet = _totalRecettes - _totalDepenses;
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Erreur chargement stats: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,###', 'fr_FR').format(amount).replaceAll(',', ' ');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Accès refusé')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Statistiques détaillées'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cartes de synthèse
            Text(
              'Synthèse générale',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildSummaryCard(
                  title: 'Utilisateurs',
                  value: '$_totalUsers',
                  icon: Icons.people,
                  color: Colors.blue,
                  subtitle: '$_totalCommercants commerçants',
                ),
                _buildSummaryCard(
                  title: 'Transactions',
                  value: '$_totalTransactions',
                  icon: Icons.swap_horiz,
                  color: Colors.green,
                  subtitle: 'Total des opérations',
                ),
                _buildSummaryCard(
                  title: 'Recettes',
                  value: '${_formatAmount(_totalRecettes)} FCFA',
                  icon: Icons.trending_up,
                  color: Colors.green,
                  subtitle: 'Entrées d\'argent',
                ),
                _buildSummaryCard(
                  title: 'Dépenses',
                  value: '${_formatAmount(_totalDepenses)} FCFA',
                  icon: Icons.trending_down,
                  color: Colors.red,
                  subtitle: 'Sorties d\'argent',
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Bénéfice net
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _beneficeNet >= 0 ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _beneficeNet >= 0 ? Icons.account_balance : Icons.warning,
                      color: _beneficeNet >= 0 ? Colors.green : Colors.red,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bénéfice net',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${_formatAmount(_beneficeNet)} FCFA',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _beneficeNet >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Évolution mensuelle
            if (_recettesParMois.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Évolution mensuelle',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: _recettesParMois.keys.map((mois) {
                        final recettes = _recettesParMois[mois] ?? 0;
                        final depenses = _depensesParMois[mois] ?? 0;
                        final maxValue = [_totalRecettes, _totalDepenses].reduce((a, b) => a > b ? a : b);
                        final recettePercent = maxValue > 0 ? (recettes / maxValue) * 100 : 0;
                        final depensePercent = maxValue > 0 ? (depenses / maxValue) * 100 : 0;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mois,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      'Recettes',
                                      style: TextStyle(color: Colors.green[600], fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: recettePercent / 100,
                                      backgroundColor: Colors.green[100],
                                      color: Colors.green,
                                      minHeight: 8,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_formatAmount(recettes)} FCFA',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      'Dépenses',
                                      style: TextStyle(color: Colors.red[600], fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: depensePercent / 100,
                                      backgroundColor: Colors.red[100],
                                      color: Colors.red,
                                      minHeight: 8,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_formatAmount(depenses)} FCFA',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}