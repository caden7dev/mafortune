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

  String _fmt(double v) =>
      NumberFormat('#,###', 'fr_FR').format(v).replaceAll(',', ' ');

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Budget enregistré'),
          backgroundColor: AppColors.primaryGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red));
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
        title: const Text('Supprimer le budget'),
        content: const Text('Voulez-vous vraiment supprimer votre budget mensuel ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _firestore.collection('budgets').doc(_currentBudget!.id).delete();
      _currentBudget = null;
      _montantController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Budget supprimé'),
          backgroundColor: AppColors.primaryGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red));
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
        user: await _authService.getCurrentUserData()
            .then((u) => u!),
        budgetMensuel: _currentBudget!.montant,
        depensesActuelles: _depensesActuelles,
        mois: DateTime.now(),
        depensesParCategorie: _depensesParCategorie,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Erreur export: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Color _getProgressColor(double pct) {
    if (pct >= 1.0) return Colors.red;
    if (pct >= 0.75) return Colors.orange;
    if (pct >= 0.5) return Colors.blue;
    return AppColors.primaryGreen;
  }

  @override
  Widget build(BuildContext context) {
    final budget = _currentBudget?.montant ?? 0;
    final pct = budget > 0 ? (_depensesActuelles / budget).clamp(0.0, 1.0) : 0.0;
    final pctExact = budget > 0 ? _depensesActuelles / budget : 0.0;
    final reste = (budget - _depensesActuelles).clamp(0, double.infinity).toDouble();
    final progressColor = _getProgressColor(pctExact);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Budget mensuel'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_currentBudget != null && !_isEditing) ...[
            IconButton(
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf),
              onPressed: _isExporting ? null : _exportPDF,
              tooltip: 'Exporter PDF',
            ),
            IconButton(
              icon: const Icon(Icons.edit),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Carte principale
                    _buildMainCard(budget, pct, pctExact, reste, progressColor),

                    const SizedBox(height: 16),

                    // Graphique dépenses par catégorie
                    if (_currentBudget != null &&
                        _depensesParCategorie.isNotEmpty)
                      _buildCategoryChart(),

                    const SizedBox(height: 16),

                    // Alertes
                    if (_currentBudget != null) _buildAlertCard(pctExact),

                    const SizedBox(height: 16),

                    // Conseils
                    _buildTipsCard(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMainCard(double budget, double pct, double pctExact, double reste,
      Color progressColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)
        ],
      ),
      child: Column(
        children: [
          // En-tête carte
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Budget du mois',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMMM yyyy', 'fr_FR').format(DateTime.now()),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (_currentBudget != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${(pctExact * 100).toStringAsFixed(0)}% utilisé',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: _currentBudget == null || _isEditing
                ? _buildForm()
                : _buildBudgetDetails(budget, pct, pctExact, reste, progressColor),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          const SizedBox(height: 8),
          TextFormField(
            controller: _montantController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Montant du budget (FCFA)',
              prefixIcon:
                  const Icon(Icons.attach_money, color: AppColors.primaryGreen),
              suffixText: 'FCFA',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.primaryGreen, width: 2),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Montant requis';
              final m = double.tryParse(v);
              if (m == null || m <= 0) return 'Montant invalide';
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveBudget,
                  icon: const Icon(Icons.save),
                  label: const Text('Enregistrer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (_currentBudget != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _isEditing = false),
                    icon: const Icon(Icons.close),
                    label: const Text('Annuler'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetDetails(double budget, double pct, double pctExact,
      double reste, Color progressColor) {
    return Column(
      children: [
        // Montant budget
        Text(
          '${_fmt(budget)} FCFA',
          style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen),
        ),
        const SizedBox(height: 24),

        // Jauge fl_chart
        SizedBox(
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: _depensesActuelles.clamp(0, budget),
                      color: progressColor,
                      radius: 22,
                      title: '',
                    ),
                    PieChartSectionData(
                      value: reste > 0 ? reste : 0,
                      color: Colors.grey[200]!,
                      radius: 18,
                      title: '',
                    ),
                  ],
                  centerSpaceRadius: 50,
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(pctExact * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: progressColor),
                  ),
                  const Text('utilisé',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Stats ligne
        Row(
          children: [
            Expanded(
              child: _buildStatTile(
                  '💸 Dépensé',
                  '${_fmt(_depensesActuelles)} F',
                  Colors.red),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatTile(
                  reste > 0 ? '✅ Reste' : '⚠️ Dépassement',
                  '${_fmt(reste)} F',
                  reste > 0 ? Colors.green : Colors.red),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Barre linéaire
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),

        const SizedBox(height: 16),

        TextButton.icon(
          onPressed: _deleteBudget,
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
          label: const Text('Supprimer ce budget',
              style: TextStyle(color: Colors.red, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildStatTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildCategoryChart() {
    final entries = _depensesParCategorie.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total =
        _depensesParCategorie.values.fold(0.0, (s, v) => s + v);

    final colors = [
      const Color(0xFFEF5350),
      const Color(0xFFAB47BC),
      const Color(0xFF42A5F5),
      const Color(0xFF26A69A),
      const Color(0xFFFFA726),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dépenses par catégorie',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...List.generate(entries.take(5).length, (i) {
            final e = entries[i];
            final pct = total > 0 ? e.value / total : 0.0;
            final color = colors[i % colors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(e.key,
                            style: const TextStyle(fontSize: 13)),
                      ]),
                      Text(
                        '${_fmt(e.value)} F  (${(pct * 100).toStringAsFixed(1)}%)',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 7,
                      backgroundColor: color.withOpacity(0.15),
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

  Widget _buildAlertCard(double pctExact) {
    if (pctExact < 0.5) return const SizedBox.shrink();

    final isOver = pctExact >= 1.0;
    final color = isOver ? Colors.red : Colors.orange;
    final icon = isOver ? Icons.warning_amber_rounded : Icons.info_outline;
    final message = isOver
        ? '⚠️ Vous avez dépassé votre budget de ce mois !'
        : pctExact >= 0.75
            ? '⚡ Attention — ${(pctExact * 100).toStringAsFixed(0)}% du budget utilisé'
            : '📊 Vous avez utilisé ${(pctExact * 100).toStringAsFixed(0)}% de votre budget';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.lightbulb, color: Colors.amber[700], size: 20),
            const SizedBox(width: 8),
            Text('Conseils',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[800])),
          ]),
          const SizedBox(height: 10),
          ...[
            'Définissez un budget basé sur vos dépenses habituelles',
            'Suivez votre progression tout au long du mois',
            'Exportez votre bilan en PDF pour le partager',
            'Ajustez votre budget chaque mois selon vos besoins',
          ].map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style: TextStyle(
                            color: Colors.amber[700],
                            fontWeight: FontWeight.bold)),
                    Expanded(
                        child: Text(tip,
                            style: TextStyle(
                                fontSize: 13, color: Colors.amber[900]))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}