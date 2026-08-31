import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class _SaisieRapideScreenState extends State<SaisieRapideScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final TransactionService _transactionService = TransactionService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isVente = true;
  bool _isLoading = false;
  bool _isLoadingProduits = false;

  // Produits
  List<Map<String, dynamic>> _produits = [];

  // Panier — liste d'articles sélectionnés avec quantité
  // { produit: {...}, quantite: 1, prixUnit: 0.0 }
  List<Map<String, dynamic>> _panier = [];

  // Mode : 'produits' ou 'montant_libre'
  String _mode = 'produits';

  // Montant libre
  String _montantStr = '0';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    if (widget.isVenteInitial != null) _isVente = widget.isVenteInitial!;

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
    _loadProduits();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadProduits() async {
    setState(() => _isLoadingProduits = true);
    try {
      final user = _authService.currentUser;
      if (user == null) return;
      final snap = await _db
          .collection('produits')
          .where('commercantId', isEqualTo: user.uid)
          .where('estActif', isEqualTo: true)
          .get();
      setState(() {
        _produits = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _mode = _produits.isNotEmpty ? 'produits' : 'montant_libre';
      });
    } catch (e) {
      debugPrint('Erreur produits: $e');
      setState(() => _mode = 'montant_libre');
    } finally {
      if (mounted) setState(() => _isLoadingProduits = false);
    }
  }

  // ─── Panier ──────────────────────────────────────────────────────────────
  double get _totalPanier {
    return _panier.fold(0.0, (sum, item) {
      return sum + (item['prixUnit'] as double) * (item['quantite'] as int);
    });
  }

  void _ajouterAuPanier(Map<String, dynamic> produit) {
    HapticFeedback.mediumImpact();
    final idx = _panier.indexWhere((i) => i['produit']['id'] == produit['id']);
    setState(() {
      if (idx >= 0) {
        // ✅ Si déjà dans le panier → augmente la quantité
        _panier[idx]['quantite']++;
      } else {
        // Pas encore dans le panier → ajoute
        _panier.add({
          'produit': produit,
          'quantite': 1,
          'prixUnit': (produit['prix'] as num?)?.toDouble() ?? 0.0,
        });
      }
    });
  }

  void _toggleProduit(Map<String, dynamic> produit) {
    HapticFeedback.mediumImpact();
    final idx = _panier.indexWhere((i) => i['produit']['id'] == produit['id']);
    setState(() {
      if (idx >= 0) {
        // ✅ Déjà dans le panier → TAP sur la carte = désélectionne complètement
        _panier.removeAt(idx);
      } else {
        // Pas encore → ajoute avec quantité 1
        _panier.add({
          'produit': produit,
          'quantite': 1,
          'prixUnit': (produit['prix'] as num?)?.toDouble() ?? 0.0,
        });
      }
    });
  }

  void _retirerDuPanier(Map<String, dynamic> produit) {
    HapticFeedback.lightImpact();
    final idx = _panier.indexWhere((i) => i['produit']['id'] == produit['id']);
    if (idx < 0) return;
    setState(() {
      if (_panier[idx]['quantite'] > 1) {
        _panier[idx]['quantite']--;
      } else {
        _panier.removeAt(idx);
      }
    });
  }

  int _quantiteDans(String produitId) {
    final idx = _panier.indexWhere((i) => i['produit']['id'] == produitId);
    return idx >= 0 ? _panier[idx]['quantite'] as int : 0;
  }

  void _modifierPrixPanier(int idx, double nouveauPrix) {
    setState(() => _panier[idx]['prixUnit'] = nouveauPrix);
  }

  // ─── Numpad ───────────────────────────────────────────────────────────────
  void _appuyerTouche(String t) {
    HapticFeedback.lightImpact();
    setState(() {
      if (t == '⌫') {
        _montantStr = _montantStr.length > 1
            ? _montantStr.substring(0, _montantStr.length - 1)
            : '0';
      } else if (t == 'C') {
        _montantStr = '0';
      } else {
        if (_montantStr == '0') {
          _montantStr = t;
        } else if (_montantStr.length < 8) {
          _montantStr += t;
        }
      }
    });
  }

  void _ajouterRapide(int v) {
    HapticFeedback.mediumImpact();
    setState(() {
      final actuel = int.tryParse(_montantStr) ?? 0;
      _montantStr = (actuel + v).toString();
    });
  }

  // ─── Valider ──────────────────────────────────────────────────────────────
  Future<void> _valider() async {
    final user = _authService.currentUser;
    if (user == null) return;

    if (_mode == 'produits' && _panier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sélectionne au moins un produit'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ));
      return;
    }

    if (_mode == 'montant_libre') {
      final montant = double.tryParse(_montantStr) ?? 0;
      if (montant <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Entrez un montant valide'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ));
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_mode == 'produits') {
        // ✅ Une transaction par article du panier
        for (final item in _panier) {
          final produit = item['produit'] as Map<String, dynamic>;
          final quantite = item['quantite'] as int;
          final prixUnit = item['prixUnit'] as double;
          final total = prixUnit * quantite;

          final description = quantite > 1
              ? '${produit['nom']} × $quantite'
              : produit['nom'] as String;

          final tx = TransactionModel(
            id: '',
            commercantId: user.uid,
            categorieId: _isVente ? 'ventes' : 'achats',
            montant: total > 0 ? total : prixUnit,
            type: _isVente
                ? TypeTransaction.recette
                : TypeTransaction.depense,
            description: description,
            date: DateTime.now(),
            dateCreation: DateTime.now(),
            modePaiement: ModePaiement.especes,
            categorie: _isVente ? 'Ventes' : 'Achats',
            produitId: produit['id'],
            produitNom: produit['nom'],
          );
          await _transactionService.addTransaction(tx);
        }
      } else {
        // Mode montant libre
        final montant = double.parse(_montantStr);
        final tx = TransactionModel(
          id: '',
          commercantId: user.uid,
          categorieId: _isVente ? 'ventes' : 'achats',
          montant: montant,
          type: _isVente
              ? TypeTransaction.recette
              : TypeTransaction.depense,
          description: _isVente ? 'Vente' : 'Dépense',
          date: DateTime.now(),
          dateCreation: DateTime.now(),
          modePaiement: ModePaiement.especes,
          categorie: _isVente ? 'Ventes' : 'Achats',
        );
        await _transactionService.addTransaction(tx);
      }

      HapticFeedback.heavyImpact();
      if (mounted) {
        Navigator.pop(context, true);
        final total = _mode == 'produits'
            ? _totalPanier
            : double.parse(_montantStr);
        final tts = TtsService();
        if (_isVente) tts.confirmerVente(total);
        else tts.confirmerDepense(total);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Erreur : $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');

  String _fmtStr(String s) {
    final n = int.tryParse(s) ?? 0;
    return _fmt(n.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final couleur = _isVente ? AppColors.primaryGreen : AppColors.expenseRed;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.95,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                const Text('Saisie simple',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E))),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                        color: Colors.grey[100], shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 18, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),

          // Toggle Vente / Dépense
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Expanded(child: _buildToggle('J\'ai VENDU', true, couleur)),
                const SizedBox(width: 12),
                Expanded(child: _buildToggle('J\'ai DÉPENSÉ', false, couleur)),
              ],
            ),
          ),

          // Tabs Produits / Montant libre
          if (_produits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _fadeController.reset();
                        setState(() => _mode = 'produits');
                        _fadeController.forward();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _mode == 'produits'
                              ? couleur.withOpacity(0.1)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _mode == 'produits'
                                ? couleur
                                : Colors.grey[300]!,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '🛒 Mes produits',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _mode == 'produits'
                                  ? couleur
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _fadeController.reset();
                        setState(() => _mode = 'montant_libre');
                        _fadeController.forward();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _mode == 'montant_libre'
                              ? couleur.withOpacity(0.1)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _mode == 'montant_libre'
                                ? couleur
                                : Colors.grey[300]!,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '✏️ Montant libre',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _mode == 'montant_libre'
                                  ? couleur
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Contenu
          Expanded(
            child: _isLoadingProduits
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryGreen))
                : FadeTransition(
                    opacity: _fadeAnim,
                    child: _mode == 'produits'
                        ? _buildModeProduits(couleur)
                        : _buildModeMontantLibre(couleur),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── MODE PRODUITS (caisse) ───────────────────────────────────────────────
  Widget _buildModeProduits(Color couleur) {
    return Column(
      children: [
        // Total panier
        if (_panier.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: couleur.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: couleur.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('🧾 Total',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: couleur)),
                    const Spacer(),
                    Text(
                      '${_fmt(_totalPanier)} FCFA',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: couleur),
                    ),
                  ],
                ),
                // Détail panier
                if (_panier.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._panier.map((item) {
                    final idx = _panier.indexOf(item);
                    final p = item['produit'] as Map<String, dynamic>;
                    final q = item['quantite'] as int;
                    final prix = item['prixUnit'] as double;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Text(p['emoji'] ?? '📦',
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${p['nom']} × $q',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[700]),
                            ),
                          ),
                          // Champ prix unitaire modifiable
                          SizedBox(
                            width: 80,
                            child: TextField(
                              keyboardType: TextInputType.number,
                              controller: TextEditingController(
                                  text: prix > 0
                                      ? prix.toInt().toString()
                                      : ''),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                hintText: 'Prix',
                                hintStyle: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 11),
                                suffixText: 'F',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 6),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: couleur, width: 1.5),
                                ),
                              ),
                              onChanged: (val) {
                                final p = double.tryParse(val) ?? 0;
                                _modifierPrixPanier(idx, p);
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '= ${_fmt(prix * q)} F',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: couleur),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),

        // Grille produits
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.8,
            ),
            itemCount: _produits.length,
            itemBuilder: (ctx, i) {
              final p = _produits[i];
              final qte = _quantiteDans(p['id'] as String);
              final hasQte = qte > 0;

              return GestureDetector(
                // ✅ Tap sur la carte = toggle (ajouter ou désélectionner)
                onTap: () => _toggleProduit(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: hasQte
                        ? couleur.withOpacity(0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasQte
                          ? couleur
                          : const Color(0xFFE5E7EB),
                      width: hasQte ? 2 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Text(p['emoji'] ?? '📦',
                          style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              p['nom'] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: hasQte
                                    ? couleur
                                    : const Color(0xFF1A1A2E),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (p['prix'] != null)
                              Text(
                                '${_fmt((p['prix'] as num).toDouble())} F',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: couleur.withOpacity(0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Contrôles quantité
                      if (hasQte)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => _ajouterAuPanier(p),
                              child: Container(
                                width: 26, height: 26,
                                decoration: BoxDecoration(
                                  color: couleur,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 2),
                              child: Text(
                                '$qte',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: couleur,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _retirerDuPanier(p),
                              child: Container(
                                width: 26, height: 26,
                                decoration: BoxDecoration(
                                  color: couleur.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.remove,
                                    color: couleur, size: 16),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Bouton valider
        _buildBoutonValider(couleur,
            label: _panier.isEmpty
                ? '✅  VALIDER'
                : '✅  VALIDER — ${_fmt(_totalPanier)} FCFA'),
      ],
    );
  }

  // ─── MODE MONTANT LIBRE ───────────────────────────────────────────────────
  Widget _buildModeMontantLibre(Color couleur) {
    return Column(
      children: [
        // Affichage montant
        Container(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    _fmtStr(_montantStr),
                    style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: couleur,
                        letterSpacing: 1),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('FCFA',
                  style: TextStyle(
                      fontSize: 16,
                      color: couleur.withOpacity(0.7),
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),

        // Touches rapides
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [500, 1000, 2000, 5000, 10000].map((v) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => _ajouterRapide(v),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: couleur.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: couleur.withOpacity(0.25)),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            v >= 1000 ? '${v ~/ 1000}k' : '$v',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: couleur),
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

        const SizedBox(height: 8),

        // Numpad
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildNumRow(['7', '8', '9'], couleur),
                const SizedBox(height: 6),
                _buildNumRow(['4', '5', '6'], couleur),
                const SizedBox(height: 6),
                _buildNumRow(['1', '2', '3'], couleur),
                const SizedBox(height: 6),
                _buildNumRow(['C', '0', '⌫'], couleur),
              ],
            ),
          ),
        ),

        _buildBoutonValider(couleur, label: '✅  VALIDER'),
      ],
    );
  }

  // ─── Helpers widgets ──────────────────────────────────────────────────────
  Widget _buildToggle(String label, bool isVente, Color couleur) {
    final active = _isVente == isVente;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _fadeController.reset();
        setState(() {
          _isVente = isVente;
          _panier.clear();
          _montantStr = '0';
        });
        _fadeController.forward();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active
              ? (isVente ? AppColors.primaryGreen : AppColors.expenseRed)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
                isVente ? Icons.trending_up : Icons.trending_down,
                color: active ? Colors.white : Colors.grey[500],
                size: 22),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color:
                        active ? Colors.white : Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildNumRow(List<String> touches, Color couleur) {
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
                        : Text(t,
                            style: TextStyle(
                                fontSize: isClear ? 15 : 22,
                                fontWeight: FontWeight.w600,
                                color: isClear
                                    ? Colors.red[400]
                                    : Colors.black87)),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBoutonValider(Color couleur, {required String label}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _valider,
          style: ElevatedButton.styleFrom(
            backgroundColor: couleur,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Text(label,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}