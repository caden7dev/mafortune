import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../models/budget_model.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final AuthService _authService = AuthService();
  final TransactionService _transactionService = TransactionService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  BudgetModel? _currentBudget;
  double _depensesActuelles = 0;
  bool _isLoading = true;
  bool _isEditing = false;
  
  final TextEditingController _montantController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _montantController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final user = _authService.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      
      final budgetSnapshot = await _firestore
          .collection('budgets')
          .where('commercantId', isEqualTo: user.uid)
          .where('mois', isEqualTo: Timestamp.fromDate(startOfMonth))
          .limit(1)
          .get();
      
      if (budgetSnapshot.docs.isNotEmpty) {
        _currentBudget = BudgetModel.fromFirestore(budgetSnapshot.docs.first);
        _montantController.text = _currentBudget!.montant.toStringAsFixed(0);
      }
      
      final transactions = await _transactionService.getTransactionsByCommercant(user.uid);
      _depensesActuelles = transactions
          .where((t) => !t.estRecette && 
              t.date.isAfter(startOfMonth) && 
              t.date.isBefore(endOfMonth.add(const Duration(days: 1))))
          .fold(0.0, (sum, t) => sum + t.montant);
          
    } catch (e) {
      print('Erreur: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;
    
    final user = _authService.currentUser;
    if (user == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final montant = double.parse(_montantController.text);
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      
      if (_currentBudget == null) {
        final newBudget = BudgetModel(
          id: '${user.uid}_${startOfMonth.toIso8601String()}',
          commercantId: user.uid,
          mois: startOfMonth,
          montant: montant,
          dateCreation: DateTime.now(),
        );
        await _firestore.collection('budgets').doc(newBudget.id).set(newBudget.toFirestore());
      } else {
        await _firestore.collection('budgets').doc(_currentBudget!.id).update({
          'montant': montant,
          'dateModification': Timestamp.fromDate(DateTime.now()),
        });
      }
      
      await _loadData();
      setState(() => _isEditing = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Budget enregistré avec succès'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBudget() async {
    if (_currentBudget == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le budget'),
        content: const Text('Voulez-vous vraiment supprimer votre budget mensuel ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _firestore.collection('budgets').doc(_currentBudget!.id).delete();
        _currentBudget = null;
        _montantController.clear();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Budget supprimé'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,###', 'fr_FR').format(amount).replaceAll(',', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final double pourcentage = _currentBudget != null && _currentBudget!.montant > 0
        ? (_depensesActuelles / _currentBudget!.montant) * 100
        : 0;
    
    final double reste = _currentBudget != null 
        ? (_currentBudget!.montant - _depensesActuelles).clamp(0, double.infinity).toDouble()
        : 0.0;
    
    Color getProgressColor() {
      if (pourcentage >= 100) return Colors.red;
      if (pourcentage >= 75) return Colors.orange;
      if (pourcentage >= 50) return Colors.blue;
      return AppColors.primaryGreen;
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Budget mensuel'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_currentBudget != null && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text(
                            'Budget du mois',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('MMMM yyyy', 'fr_FR').format(DateTime.now()),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          if (_isEditing || _currentBudget == null)
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _montantController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Montant du budget (FCFA)',
                                      prefixIcon: const Icon(Icons.attach_money),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Veuillez saisir un montant';
                                      }
                                      final montant = double.tryParse(value);
                                      if (montant == null || montant <= 0) {
                                        return 'Montant invalide';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _saveBudget,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primaryGreen,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                          child: const Text('Enregistrer'),
                                        ),
                                      ),
                                      if (_currentBudget != null)
                                        const SizedBox(width: 12),
                                      if (_currentBudget != null)
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () => setState(() => _isEditing = false),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                            ),
                                            child: const Text('Annuler'),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          else
                            Column(
                              children: [
                                Text(
                                  '${_formatAmount(_currentBudget!.montant)} FCFA',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Dépenses: ${_formatAmount(_depensesActuelles)} FCFA',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        Text(
                                          '${pourcentage.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: getProgressColor(),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: (pourcentage / 100).clamp(0, 1).toDouble(),
                                        backgroundColor: Colors.grey[200],
                                        color: getProgressColor(),
                                        minHeight: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Reste: ${_formatAmount(reste)} FCFA',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: reste > 0 ? Colors.green : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 24),
                                
                                if (pourcentage >= 75)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: (pourcentage >= 100 ? Colors.red : Colors.orange).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: pourcentage >= 100 ? Colors.red : Colors.orange,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          pourcentage >= 100 ? Icons.warning_amber : Icons.info_outline,
                                          color: pourcentage >= 100 ? Colors.red : Colors.orange,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            pourcentage >= 100
                                                ? '⚠️ Vous avez dépassé votre budget mensuel !'
                                                : '⚡ Vous avez utilisé ${pourcentage.toStringAsFixed(0)}% de votre budget',
                                            style: TextStyle(
                                              color: pourcentage >= 100 ? Colors.red : Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                const SizedBox(height: 16),
                                
                                TextButton.icon(
                                  onPressed: _deleteBudget,
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  label: const Text(
                                    'Supprimer ce budget',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb, color: Colors.amber[700]),
                              const SizedBox(width: 8),
                              const Text(
                                'Conseils',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTip('Définissez un budget réaliste basé sur vos dépenses passées'),
                          _buildTip('Suivez votre progression tout au long du mois'),
                          _buildTip('Recevez des alertes quand vous approchez de votre limite'),
                          _buildTip('Ajustez votre budget chaque mois selon vos besoins'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}