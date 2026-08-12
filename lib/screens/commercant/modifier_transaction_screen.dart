import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';

class ModifierTransactionSheet extends StatefulWidget {
  final TransactionModel transaction;

  const ModifierTransactionSheet({
    super.key,
    required this.transaction,
  });

  @override
  State<ModifierTransactionSheet> createState() =>
      _ModifierTransactionSheetState();
}

class _ModifierTransactionSheetState extends State<ModifierTransactionSheet>
    with TickerProviderStateMixin {
  final TransactionService _transactionService = TransactionService();

  late bool _isVente;
  late String _montantStr;
  late TextEditingController _descriptionController;
  bool _isLoading = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    // ✅ Pré-remplir avec les données existantes
    _isVente = widget.transaction.estRecette;
    _montantStr = widget.transaction.montant.toStringAsFixed(0);
    _descriptionController = TextEditingController(
      text: widget.transaction.description ?? '',
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  double get _montant => double.tryParse(_montantStr) ?? 0;

  void _appuyerTouche(String touche) {
    HapticFeedback.lightImpact();
    setState(() {
      if (touche == '⌫') {
        if (_montantStr.length > 1) {
          _montantStr = _montantStr.substring(0, _montantStr.length - 1);
        } else {
          _montantStr = '0';
        }
      } else if (touche == 'C') {
        _montantStr = '0';
      } else {
        if (_montantStr == '0') {
          _montantStr = touche;
        } else if (_montantStr.length < 8) {
          _montantStr += touche;
        }
      }
    });
  }

  void _ajouterMontantRapide(int montant) {
    HapticFeedback.mediumImpact();
    setState(() {
      final actuel = int.tryParse(_montantStr) ?? 0;
      _montantStr = (actuel + montant).toString();
    });
  }

  Future<void> _valider() async {
    if (_montant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrez un montant valide'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ Garde la date originale — ne la modifie PAS
      final transactionModifiee = widget.transaction.copyWith(
        montant: _montant,
        type: _isVente ? TypeTransaction.recette : TypeTransaction.depense,
        categorie: _isVente ? 'Ventes' : 'Achats',
        description: _descriptionController.text.trim().isEmpty
            ? (_isVente ? 'Vente' : 'Dépense')
            : _descriptionController.text.trim(),
        date: widget.transaction.date,
        dateCreation: widget.transaction.dateCreation,
        dateModification: DateTime.now(),
      );

      await _transactionService.updateTransaction(transactionModifiee);

      HapticFeedback.heavyImpact();

      if (mounted) {
        // ✅ RENVOIE L'OBJET MODIFIÉ POUR MISE À JOUR INSTANTANÉE DE L'UI
        Navigator.pop(context, transactionModifiee);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Text('✅', style: TextStyle(fontSize: 16)),
                SizedBox(width: 10),
                Text('Transaction modifiée',
                    style: TextStyle(fontSize: 15)),
              ],
            ),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur : $e',
                style: const TextStyle(fontSize: 15)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  String _formatAffichage(String valeur) {
    final n = int.tryParse(valeur) ?? 0;
    final s = n.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  String _formatDate(DateTime date) {
    const mois = [
      'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
      'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'
    ];
    return '${date.day} ${mois[date.month - 1]} ${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final couleur = _isVente ? AppColors.primaryGreen : AppColors.expenseRed;
    final screenHeight = MediaQuery.of(context).size.height;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        height: screenHeight * 0.93,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    '✏️ Modifier la transaction',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 18, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),

            // ✅ Date originale conservée
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Text('📅', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Date originale conservée',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _formatDate(widget.transaction.date),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1A1A2E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.lock_outline,
                      size: 14, color: Colors.blue),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Sélecteur Vente / Dépense
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _isVente = true);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _isVente
                              ? AppColors.primaryGreen
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.trending_up,
                                color: _isVente
                                    ? Colors.white
                                    : Colors.grey[500],
                                size: 26),
                            const SizedBox(height: 4),
                            Text(
                              "J'ai VENDU",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _isVente
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _isVente = false);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: !_isVente
                              ? AppColors.expenseRed
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.trending_down,
                                color: !_isVente
                                    ? Colors.white
                                    : Colors.grey[500],
                                size: 26),
                            const SizedBox(height: 4),
                            Text(
                              "J'ai DÉPENSÉ",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: !_isVente
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Affichage montant
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: couleur.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _formatAffichage(_montantStr),
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: couleur,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'FCFA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: couleur.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Touches rapides
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [500, 1000, 2000, 5000, 10000].map((v) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: GestureDetector(
                        onTap: () => _ajouterMontantRapide(v),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: couleur.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: couleur.withValues(alpha: 0.25)),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                v >= 1000 ? '${v ~/ 1000}k' : '$v',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: couleur,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 10),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _descriptionController,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: '📝 Ajouter une description (optionnel)',
                  hintStyle:
                      TextStyle(color: Colors.grey[400], fontSize: 14),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: couleur, width: 2),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Numpad
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildRangee(['7', '8', '9'], couleur),
                    const SizedBox(height: 6),
                    _buildRangee(['4', '5', '6'], couleur),
                    const SizedBox(height: 6),
                    _buildRangee(['1', '2', '3'], couleur),
                    const SizedBox(height: 6),
                    _buildRangee(['C', '0', '⌫'], couleur),
                  ],
                ),
              ),
            ),

            // Bouton valider
            Padding(
              padding: EdgeInsets.fromLTRB(
                20, 8, 20,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _valider,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: couleur,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text(
                          '✅  Enregistrer les modifications',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangee(List<String> touches, Color couleur) {
    return Expanded(
      child: Row(
        children: touches.map((t) {
          final isBack = t == '⌫';
          final isClear = t == 'C';
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: GestureDetector(
                onTap: () => _appuyerTouche(t),
                child: Container(
                  decoration: BoxDecoration(
                    color: isBack || isClear
                        ? Colors.grey[100]
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Center(
                    child: isBack
                        ? Icon(Icons.backspace_outlined,
                            size: 20, color: Colors.grey[700])
                        : Text(
                            t,
                            style: TextStyle(
                              fontSize: isClear ? 15 : 22,
                              fontWeight: FontWeight.w600,
                              color: isClear
                                  ? Colors.red[400]
                                  : Colors.black87,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}