import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';
import '../../services/tts_service.dart';

class SaisieRapideScreen extends StatefulWidget {
  final bool? isVenteInitial;
  const SaisieRapideScreen({super.key, this.isVenteInitial});

  @override
  State<SaisieRapideScreen> createState() => _SaisieRapideScreenState();
}

class _SaisieRapideScreenState extends State<SaisieRapideScreen> {
  final AuthService _authService = AuthService();
  final TransactionService _transactionService = TransactionService();

  bool _isVente = true;
  String _montantStr = '0';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVenteInitial != null) {
      _isVente = widget.isVenteInitial!;
    }
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
        } else {
          if (_montantStr.length < 8) {
            _montantStr += touche;
          }
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
          content: Text('Entrez un montant'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final firebaseUser = _authService.currentUser;
    if (firebaseUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    final transaction = TransactionModel(
      id: '',
      commercantId: firebaseUser.uid,
      categorieId: _isVente ? 'ventes' : 'achats',
      montant: _montant,
      type: _isVente ? TypeTransaction.recette : TypeTransaction.depense,
      description: _isVente ? 'Vente' : 'Dépense',
      date: DateTime.now(),
      dateCreation: DateTime.now(),
      modePaiement: ModePaiement.especes,
      categorie: _isVente ? 'Ventes' : 'Achats',
    );

    try {
      // ✅ CORRECTION — await obligatoire pour attendre l'enregistrement Firestore
      await _transactionService.addTransaction(transaction);

      // ✅ Le cache est invalidé dans addTransaction — le dashboard verra les nouvelles données

      HapticFeedback.heavyImpact();

      if (mounted) {
        // ✅ On retourne true APRÈS que la transaction est bien enregistrée
        Navigator.pop(context, true);

        // Confirmation vocale
        final tts = TtsService();
        if (_isVente) {
          tts.confirmerVente(_montant);
        } else {
          tts.confirmerDepense(_montant);
        }
      }
    } catch (e) {
      debugPrint('Erreur enregistrement transaction: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur : $e',
              style: const TextStyle(fontSize: 15),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
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

  @override
  Widget build(BuildContext context) {
    final couleur = _isVente ? AppColors.primaryGreen : AppColors.expenseRed;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Poignée
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Titre
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              'Saisie',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Sélecteur Vendu / Dépensé
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _isVente
                            ? AppColors.primaryGreen
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: _isVente ? Colors.white : Colors.grey[500],
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "J'ai VENDU",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _isVente ? Colors.white : Colors.grey[600],
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: !_isVente
                            ? AppColors.expenseRed
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.trending_down,
                            color: !_isVente ? Colors.white : Colors.grey[500],
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "J'ai DÉPENSÉ",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: !_isVente ? Colors.white : Colors.grey[600],
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

          const SizedBox(height: 16),

          // Affichage du montant
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: couleur.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: couleur.withOpacity(0.3)),
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
                        fontSize: 42,
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
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: couleur.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

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
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: couleur.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: couleur.withOpacity(0.25)),
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

          const SizedBox(height: 14),

          // Numpad
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildRangee(['7', '8', '9'], couleur),
                  const SizedBox(height: 8),
                  _buildRangee(['4', '5', '6'], couleur),
                  const SizedBox(height: 8),
                  _buildRangee(['1', '2', '3'], couleur),
                  const SizedBox(height: 8),
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
              height: 60,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _valider,
                style: ElevatedButton.styleFrom(
                  backgroundColor: couleur,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '✅  VALIDER',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
          ),
        ],
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
                            size: 22, color: Colors.grey[700])
                        : Text(
                            t,
                            style: TextStyle(
                              fontSize: isClear ? 16 : 24,
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