import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../services/pdf_export_service.dart';
import '../../models/budget_model.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final AuthService _authService = AuthService();
  final TransactionService _transactionService = TransactionService();
  final PdfExportService _pdfService = PdfExportService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  BudgetModel? _currentBudget;
  double _depensesActuelles = 0;
  Map<String, double> _depensesParCategorie = {};
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isExporting = false;

  final TextEditingController _montantController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final List<Color> _catColors = [
    const Color(0xFFEF5350),
    const Color(0xFFAB47BC),
    const Color(0xFF42A5F5),
    const Color(0xFF26A69A),
    const Color(0xFFFFA726),
  ];

  final Map<String, String> _catEmojis = {
    'alimentation': '🍽️',
    'transport': '🚗',
    'stock': '📦',
    'loyer': '🏠',
    'santé': '💊',
    'eau': '💡',
    'électricité': '💡',
    'téléphone': '📱',
  };

  String _fmt(double v) =>
      NumberFormat('#,###', 'fr_FR').format(v).replaceAll(',', ' ');

  String _getCatEmoji(String cat) {
    for (final key in _catEmojis.keys) {
      if (cat.toLowerCase().contains(key)) return _catEmojis[key]!;
    }
    return '📌';
  }

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
      if (user == null) return;

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      final snap = await _firestore
          .collection('budgets')
          .where('commercantId', isEqualTo: user.uid)
          .where('mois', isEqualTo: Timestamp.fromDate(startOfMonth))
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        _currentBudget = BudgetModel.fromFirestore(snap.docs.first);
        _montantController.text = _currentBudget!.montant.toStringAsFixed(0);
      }

      final transactions =
          await _transactionService.getTransactionsByCommercant(user.uid);

      final periodTx = transactions.where((t) =>
          !t.estRecette &&
          t.date.isAfter(startOfMonth) &&
          t.date.isBefore(endOfMonth.add(const Duration(days: 1))));

      _depensesActuelles = periodTx.fold(0.0, (s, t) => s + t.montant);

      _depensesParCategorie = {};
      for (var t in periodTx) {
        _depensesParCategorie[t.categorie] =
            (_depensesParCategorie[t.categorie] ?? 0) + t.montant;
      }
    } catch (e) {
      debugPrint('Erreur budget: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;
    final user = _authService.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final montant = double.parse(_montantController.text);
      final startOfMonth =
          DateTime(DateTime.now().year, DateTime.now().month, 1);

      if (_currentBudget == null) {
        final newBudget = BudgetModel(
          id: '${user.uid}_${startOfMonth.toIso8601String()}',
          commercantId: user.uid,
          mois: startOfMonth,
          montant: montant,
          dateCreation: DateTime.now(),
        );
        await _firestore
            .collection('budgets')
            .doc(newBudget.id)
            .set(newBudget.toFirestore());
      } else {
        await _firestore
            .collection('budgets')
            .doc(_currentBudget!.id)
            .update({
          'montant': montant,
          'dateModification': Timestamp.fromDate(DateTime.now()),
        });
      }

      await _loadData();
      if (mounted) setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Budget enregistré', style: TextStyle(fontSize: 16)),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e', style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBudget() async {
    if (_currentBudget == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🗑️', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            const Text(
              'Supprimer le budget ?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Votre budget mensuel sera supprimé définitivement.',
              style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Oui, supprimer',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Annuler', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _firestore.collection('budgets').doc(_currentBudget!.id).delete();
      _currentBudget = null;
      _montantController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Budget supprimé', style: TextStyle(fontSize: 16)),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e', style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportPDF() async {
    if (_currentBudget == null) return;
    setState(() => _isExporting = true);
    try {
      await _pdfService.exportBilanBudget(
        user: await _authService.getCurrentUserData().then((u) => u!),
        budgetMensuel: _currentBudget!.montant,
        depensesActuelles: _depensesActuelles,
        mois: DateTime.now(),
        depensesParCategorie: _depensesParCategorie,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur export: $e', style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Color _getProgressColor(double pct) {
    if (pct >= 1.0) return Colors.red;
    if (pct >= 0.75) return Colors.orange;
    if (pct >= 0.5) return const Color(0xFF1976D2);
    return AppColors.primaryGreen;
  }

  // ─── BUILD PRINCIPAL ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final budget = _currentBudget?.montant ?? 0;
    final pctExact = budget > 0 ? _depensesActuelles / budget : 0.0;
    final pct = pctExact.clamp(0.0, 1.0);
    final reste = (budget - _depensesActuelles).clamp(0, double.infinity).toDouble();
    final progressColor = _getProgressColor(pctExact);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '🎯 Budget mensuel',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_currentBudget != null && !_isEditing) ...[
            // Export PDF
            IconButton(
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('📄', style: TextStyle(fontSize: 22)),
              onPressed: _isExporting ? null : _exportPDF,
              tooltip: 'Exporter PDF',
            ),
            // Modifier
            IconButton(
              icon: const Text('✏️', style: TextStyle(fontSize: 22)),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Modifier',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primaryGreen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                child: Column(
                  children: [
                    // Pas de budget — invitation à créer
                    if (_currentBudget == null && !_isEditing)
                      _buildNoBudgetState(),

                    // Formulaire création/édition
                    if (_currentBudget == null || _isEditing)
                      _buildFormCard(),

                    // Vue budget existant
                    if (_currentBudget != null && !_isEditing) ...[
                      _buildBudgetSummaryCard(
                          budget, pct, pctExact, reste, progressColor),
                      const SizedBox(height: 16),
                      if (pctExact >= 0.5) _buildAlertCard(pctExact),
                      if (pctExact >= 0.5) const SizedBox(height: 16),
                      if (_depensesParCategorie.isNotEmpty)
                        _buildCategoryCard(),
                      const SizedBox(height: 16),
                    ],

                    // Conseils
                    _buildTipsCard(),
                  ],
                ),
              ),
            ),
    );
  }

  // ─── PAS DE BUDGET ───────────────────────────────────────────────────────────
  Widget _buildNoBudgetState() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          const Text(
            'Pas encore de budget',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Définissez un montant maximum à dépenser ce mois.\nMaFortune vous alertera quand vous approchez de la limite.',
            style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: () => setState(() => _isEditing = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('➕', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 10),
                  Text('Créer mon budget',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── FORMULAIRE ──────────────────────────────────────────────────────────────
  Widget _buildFormCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('💰', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Text(
                  _isEditing && _currentBudget != null
                      ? 'Modifier le budget'
                      : 'Définir mon budget',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMMM yyyy', 'fr_FR').format(DateTime.now()),
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // Champ montant — grand
            TextFormField(
              controller: _montantController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              decoration: InputDecoration(
                labelText: 'Montant maximum (FCFA)',
                labelStyle: const TextStyle(fontSize: 15),
                suffixText: 'FCFA',
                suffixStyle: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: AppColors.primaryGreen, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Entrez un montant';
                final m = double.tryParse(v);
                if (m == null || m <= 0) return 'Montant invalide';
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Bouton enregistrer — grand
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _saveBudget,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('💾', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 10),
                    Text('Enregistrer',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

            // Annuler si en mode édition
            if (_isEditing && _currentBudget != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => setState(() => _isEditing = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Annuler',
                      style: TextStyle(fontSize: 17)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── CARTE BUDGET PRINCIPAL ──────────────────────────────────────────────────
  Widget _buildBudgetSummaryCard(double budget, double pct, double pctExact,
      double reste, Color progressColor) {
    final moisStr =
        DateFormat('MMMM yyyy', 'fr_FR').format(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12),
        ],
      ),
      child: Column(
        children: [
          // Header gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🗓️ $moisStr',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mon budget du mois',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_fmt(budget)} FCFA',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Jauge circulaire
                SizedBox(
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              value: _depensesActuelles.clamp(0, budget),
                              color: progressColor,
                              radius: 24,
                              title: '',
                            ),
                            PieChartSectionData(
                              value: reste > 0 ? reste : 0,
                              color: Colors.grey[200]!,
                              radius: 20,
                              title: '',
                            ),
                          ],
                          centerSpaceRadius: 52,
                          sectionsSpace: 2,
                          startDegreeOffset: -90,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(pctExact * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: progressColor),
                          ),
                          Text(
                            'utilisé',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Barre linéaire — épaisse
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 14,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),

                const SizedBox(height: 20),

                // 2 stats côte à côte
                Row(
                  children: [
                    Expanded(
                      child: _buildStatBox(
                        emoji: '📉',
                        label: 'Dépensé',
                        value: '${_fmt(_depensesActuelles)} F',
                        color: const Color(0xFFC62828),
                        bgColor: const Color(0xFFFFEBEE),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatBox(
                        emoji: reste > 0 ? '✅' : '⚠️',
                        label: reste > 0 ? 'Reste' : 'Dépassement',
                        value: '${_fmt(reste)} F',
                        color: reste > 0
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                        bgColor: reste > 0
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFEBEE),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Bouton supprimer — discret
                TextButton(
                  onPressed: _deleteBudget,
                  child: Text(
                    '🗑️ Supprimer ce budget',
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                        decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required String emoji,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 13, color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  // ─── ALERTE ──────────────────────────────────────────────────────────────────
  Widget _buildAlertCard(double pctExact) {
    final isOver = pctExact >= 1.0;
    final isWarning = pctExact >= 0.75;
    final color = isOver ? Colors.red : Colors.orange;

    final emoji = isOver ? '🚨' : '⚡';
    final title = isOver
        ? 'Budget dépassé !'
        : 'Attention — ${(pctExact * 100).toStringAsFixed(0)}% utilisé';
    final message = isOver
        ? 'Vous avez dépassé votre budget ce mois. Essayez de limiter vos prochaines dépenses.'
        : isWarning
            ? 'Il ne vous reste plus beaucoup. Soyez prudente avec vos prochaines dépenses.'
            : 'Vous avez utilisé la moitié de votre budget. Continuez à surveiller.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                      fontSize: 14, color: color.withValues(alpha: 0.9), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── CATÉGORIES ──────────────────────────────────────────────────────────────
  Widget _buildCategoryCard() {
    final entries = _depensesParCategorie.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = _depensesParCategorie.values.fold(0.0, (s, v) => s + v);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🏷️', style: TextStyle(fontSize: 24)),
              SizedBox(width: 10),
              Text(
                'Où va votre argent ?',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(entries.take(5).length, (i) {
            final e = entries[i];
            final pct = total > 0 ? e.value / total : 0.0;
            final color = _catColors[i % _catColors.length];
            final emoji = _getCatEmoji(e.key);

            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.key,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_fmt(e.value)} F',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: color),
                          ),
                          Text(
                            '${(pct * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 10,
                      backgroundColor: color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── CONSEILS ────────────────────────────────────────────────────────────────
  Widget _buildTipsCard() {
    final tips = [
      ('💡', 'Définissez un budget basé sur vos dépenses habituelles'),
      ('👀', 'Vérifiez votre progression chaque semaine'),
      ('📄', 'Exportez votre bilan en PDF pour le garder'),
      ('🔄', 'Ajustez votre budget chaque mois si nécessaire'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text(
                'Conseils',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[800]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...tips.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.$1, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t.$2,
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.amber[900],
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}