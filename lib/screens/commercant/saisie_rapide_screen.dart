import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile)
const Color terracotta = Color(0xFFD96B43);    // Vente / Action chaleureuse
const Color brickRed = Color(0xFFB91C1C);      // Dépense / Alerte douce
const Color textDark = Color(0xFF222222);      // Gris anthracite très foncé (lisibilité maximale)

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

  List<Map<String, dynamic>> _produits = [];
  List<Map<String, dynamic>> _panier = [];
  String _mode = 'produits';
  String _montantStr = '0';

  // Catégories de dépenses (remplace la liste de produits côté dépense)
  final List<Map<String, String>> _categoriesDepense = [
    {'emoji': '🏠', 'label': 'Loyer'},
    {'emoji': '🚗', 'label': 'Transport'},
    {'emoji': '💡', 'label': 'Électricité'},
    {'emoji': '💧', 'label': 'Eau'},
    {'emoji': '📱', 'label': 'Téléphone'},
    {'emoji': '📦', 'label': 'Marchandises'},
    {'emoji': '👥', 'label': 'Salaires'},
    {'emoji': '🔧', 'label': 'Entretien'},
    {'emoji': '🧾', 'label': 'Taxes'},
    {'emoji': '❓', 'label': 'Autre'},
  ];
  String? _categorieDepense;

  // Description libre et moyen de paiement
  final TextEditingController _descriptionController = TextEditingController();
  final FocusNode _descriptionFocus = FocusNode();
  ModePaiement _modePaiementSelectionne = ModePaiement.especes;

  // ✅ NOUVEAU : quantité optionnelle (vente montant libre + dépense), 1 par défaut
  int _quantite = 1;

  final List<Map<String, dynamic>> _modesPaiement = [
    {'mode': ModePaiement.especes, 'emoji': '💵', 'label': 'Espèces'},
    {'mode': ModePaiement.flooz, 'emoji': '🟠', 'label': 'Flooz'},
    {'mode': ModePaiement.mixxByYas, 'emoji': '🟡', 'label': 'Mixx by Yas'},
    {'mode': ModePaiement.virement, 'emoji': '🏦', 'label': 'Virement'},
  ];

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
    _descriptionController.dispose();
    _descriptionFocus.dispose();
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
        _panier[idx]['quantite']++;
      } else {
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
        _panier.removeAt(idx);
      } else {
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

  void _changerQuantite(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _quantite = (_quantite + delta).clamp(1, 999);
    });
  }

  String _slugify(String label) {
    const accents = {
      'é': 'e', 'è': 'e', 'ê': 'e', 'à': 'a', 'â': 'a', 'î': 'i', 'ô': 'o', 'û': 'u', 'ç': 'c',
    };
    String result = label.toLowerCase();
    accents.forEach((accent, lettre) => result = result.replaceAll(accent, lettre));
    return result.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  /// Construit la description finale en ajoutant "× quantité" si > 1
  String _descriptionAvecQuantite(String base) {
    return _quantite > 1 ? '$base × $_quantite' : base;
  }

  Future<void> _valider() async {
    final user = _authService.currentUser;
    if (user == null) return;

    // ─── CÔTÉ DÉPENSE ───────────────────────────────────────────────────
    if (!_isVente) {
      if (_categorieDepense == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Choisis une catégorie de dépense'),
          backgroundColor: brickRed,
          duration: Duration(seconds: 2),
        ));
        return;
      }
      final montantUnitaire = double.tryParse(_montantStr) ?? 0;
      if (montantUnitaire <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Entrez un montant valide'),
          backgroundColor: brickRed,
          duration: Duration(seconds: 2),
        ));
        return;
      }

      setState(() => _isLoading = true);
      try {
        final descriptionSaisie = _descriptionController.text.trim();
        final descriptionBase = descriptionSaisie.isEmpty ? _categorieDepense! : descriptionSaisie;
        final montantTotal = montantUnitaire * _quantite;

        final tx = TransactionModel(
          id: '',
          commercantId: user.uid,
          categorieId: _slugify(_categorieDepense!),
          montant: montantTotal,
          type: TypeTransaction.depense,
          description: _descriptionAvecQuantite(descriptionBase),
          date: DateTime.now(),
          dateCreation: DateTime.now(),
          modePaiement: _modePaiementSelectionne,
          categorie: _categorieDepense!,
        );

        await _transactionService.addTransaction(tx);

        HapticFeedback.heavyImpact();
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        debugPrint('Erreur validation: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('❌ Erreur : $e'),
            backgroundColor: brickRed,
          ));
        }
      }
      return;
    }

    // ─── CÔTÉ VENTE ─────────────────────────────────────────────────────
    if (_mode == 'produits' && _panier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sélectionne au moins un produit'),
        backgroundColor: terracotta,
        duration: Duration(seconds: 2),
      ));
      return;
    }

    if (_mode == 'montant_libre') {
      final montant = double.tryParse(_montantStr) ?? 0;
      if (montant <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Entrez un montant valide'),
          backgroundColor: terracotta,
          duration: Duration(seconds: 2),
        ));
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_mode == 'produits') {
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
            categorieId: 'ventes',
            montant: total > 0 ? total : prixUnit,
            type: TypeTransaction.recette,
            description: description,
            date: DateTime.now(),
            dateCreation: DateTime.now(),
            modePaiement: _modePaiementSelectionne,
            categorie: 'Ventes',
            produitId: produit['id'],
            produitNom: produit['nom'],
          );

          await _transactionService.addTransaction(tx);
        }
      } else {
        final montantUnitaire = double.parse(_montantStr);
        final montantTotal = montantUnitaire * _quantite;
        final descriptionSaisie = _descriptionController.text.trim();
        final descriptionBase = descriptionSaisie.isEmpty ? 'Vente' : descriptionSaisie;

        final tx = TransactionModel(
          id: '',
          commercantId: user.uid,
          categorieId: 'ventes',
          montant: montantTotal,
          type: TypeTransaction.recette,
          description: _descriptionAvecQuantite(descriptionBase),
          date: DateTime.now(),
          dateCreation: DateTime.now(),
          modePaiement: _modePaiementSelectionne,
          categorie: 'Ventes',
        );

        await _transactionService.addTransaction(tx);
      }

      HapticFeedback.heavyImpact();
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Erreur validation: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Erreur : $e'),
          backgroundColor: brickRed,
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
    final couleur = _isVente ? terracotta : brickRed;
    final screenHeight = MediaQuery.of(context).size.height;

    // ✅ CORRIGÉ : remonte toute la feuille de la hauteur du clavier quand il
    // s'ouvre, pour que le champ actif (ex: description) ne soit plus caché.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: screenHeight * 0.95,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  const Text('Saisie simple',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textDark)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                          color: Colors.grey[100], shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 18, color: textDark),
                    ),
                  ),
                ],
              ),
            ),

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

            // Le toggle produits/montant libre ne s'affiche que côté VENTE
            if (_isVente && _produits.isNotEmpty)
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
                                ? couleur.withOpacity(0.08)
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
                                color: _mode == 'produits' ? couleur : Colors.grey[600],
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
                                ? couleur.withOpacity(0.08)
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
                                color: _mode == 'montant_libre' ? couleur : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: _isLoadingProduits
                  ? const Center(child: CircularProgressIndicator(color: terracotta))
                  : FadeTransition(
                      opacity: _fadeAnim,
                      child: !_isVente
                          ? _buildModeDepense(couleur)
                          : (_mode == 'produits'
                              ? _buildModeProduits(couleur)
                              : _buildModeMontantLibre(couleur)),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NOUVEAU : sélecteur de quantité réutilisable (1 par défaut, optionnel)
  Widget _buildQuantiteSelector(Color couleur) {
    return Row(
      children: [
        const Text('Quantité', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
        const Spacer(),
        GestureDetector(
          onTap: _quantite > 1 ? () => _changerQuantite(-1) : null,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _quantite > 1 ? couleur.withOpacity(0.1) : Colors.grey[100],
              shape: BoxShape.circle,
              border: Border.all(color: _quantite > 1 ? couleur.withOpacity(0.3) : Colors.grey[300]!),
            ),
            child: Icon(Icons.remove, size: 18, color: _quantite > 1 ? couleur : Colors.grey[400]),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            '$_quantite',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
          ),
        ),
        GestureDetector(
          onTap: () => _changerQuantite(1),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: couleur.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: couleur.withOpacity(0.3)),
            ),
            child: Icon(Icons.add, size: 18, color: couleur),
          ),
        ),
      ],
    );
  }

  // Écran de saisie des dépenses (catégories + montant + quantité + description + paiement)
  Widget _buildModeDepense(Color couleur) {
    final montantUnitaire = int.tryParse(_montantStr) ?? 0;
    final total = montantUnitaire * _quantite;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Catégorie', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categoriesDepense.map((cat) {
              final isSelected = _categorieDepense == cat['label'];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _categorieDepense = cat['label']);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? couleur.withOpacity(0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? couleur : const Color(0xFFE5E7EB),
                      width: isSelected ? 2 : 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cat['emoji']!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        cat['label']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? couleur : textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Montant', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
              if (_quantite > 1)
                Text(
                  'Total : ${_fmt(total.toDouble())} FCFA',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: couleur),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: couleur.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: couleur.withOpacity(0.25)),
            ),
            child: TextField(
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              controller: TextEditingController(text: _montantStr == '0' ? '' : _montantStr)
                ..selection = TextSelection.collapsed(offset: _montantStr == '0' ? 0 : _montantStr.length),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textDark),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: Colors.grey[400]),
                suffixText: _quantite > 1 ? 'FCFA / unité' : 'FCFA',
                suffixStyle: TextStyle(fontSize: 13, color: textDark.withOpacity(0.6)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (val) => setState(() => _montantStr = val.isEmpty ? '0' : val),
            ),
          ),

          const SizedBox(height: 8),
          Row(
            children: [500, 1000, 2000, 5000, 10000].map((v) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => _ajouterRapide(v),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: couleur.withOpacity(0.3), width: 1.5),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            v >= 1000 ? '${v ~/ 1000}k' : '$v',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // ✅ NOUVEAU : quantité optionnelle
          _buildQuantiteSelector(couleur),

          const SizedBox(height: 20),

          const Text('Description (optionnel)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            focusNode: _descriptionFocus,
            maxLines: 2,
            style: const TextStyle(fontSize: 14, color: textDark),
            decoration: InputDecoration(
              hintText: 'Ex: Facture CEET de janvier',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: couleur, width: 2)),
            ),
          ),

          const SizedBox(height: 20),

          _buildModePaiementSelector(couleur),

          const SizedBox(height: 20),

          _buildBoutonValider(couleur, label: '✅  VALIDER'),
        ],
      ),
    );
  }

  // Sélecteur de moyen de paiement réutilisable
  Widget _buildModePaiementSelector(Color couleur) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Moyen de paiement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _modesPaiement.map((m) {
            final mode = m['mode'] as ModePaiement;
            final isSelected = _modePaiementSelectionne == mode;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _modePaiementSelectionne = mode);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? couleur.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? couleur : const Color(0xFFE5E7EB),
                    width: isSelected ? 2 : 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(m['emoji'] as String, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      m['label'] as String,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? couleur : textDark,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

         Widget _buildModeProduits(Color couleur) {
    return Column(
      children: [
        // ─── LISTE VERTICALE DES PRODUITS (Prend toute la place) ──────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            itemCount: _produits.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final p = _produits[i];
              final qte = _quantiteDans(p['id'] as String);
              final hasQte = qte > 0;

              return GestureDetector(
                // ✅ CORRECTION : Taper sur un produit déjà sélectionné le retire
                onTap: () => _toggleProduit(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: hasQte ? couleur.withOpacity(0.06) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasQte ? couleur.withOpacity(0.3) : Colors.grey.shade200,
                      width: hasQte ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Emoji dans un cercle
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: hasQte ? couleur.withOpacity(0.15) : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(p['emoji'] ?? '📦', style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                      
                      const SizedBox(width: 14),
                      
                      // Nom + Prix
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['nom'] ?? 'Produit',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: hasQte ? couleur : textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_fmt((p['prix'] as num? ?? 0).toDouble())} FCFA',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // ✅ BOUTONS + ET - PLUS LARGES ET FACILES À CLIQUER
                      if (hasQte)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Bouton MOINS (zone de tap large)
                            GestureDetector(
                              onTap: () => _retirerDuPanier(p),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: couleur.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.remove, color: couleur, size: 20),
                              ),
                            ),
                            
                            // Quantité
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                '$qte',
                                style: TextStyle(
                                  color: couleur,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            
                            // Bouton PLUS (zone de tap large)
                            GestureDetector(
                              onTap: () => _ajouterAuPanier(p),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: couleur,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        )
                      else
                        // Si pas dans le panier : bouton + simple
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: couleur.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.add, color: couleur, size: 22),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // ─── PANIER FIXE EN BAS (Ne cache plus les produits) ─────────────
        if (_panier.isNotEmpty)
          GestureDetector(
            onTap: _afficherDetailPanier,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: couleur,
                boxShadow: [
                  BoxShadow(
                    color: couleur.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_panier.length} article${_panier.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_fmt(_totalPanier)} FCFA',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Voir',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ─── MOYENS DE PAIEMENT ET VALIDATION ────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
          ),
          child: Column(
            children: [
              _buildModePaiementSelector(couleur),
              const SizedBox(height: 12),
              _buildBoutonValider(couleur,
                  label: _panier.isEmpty
                      ? '✅  VALIDER'
                      : '✅  VALIDER — ${_fmt(_totalPanier)} FCFA'),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ NOUVELLE MÉTHODE : Afficher le détail du panier dans un bottom sheet
  void _afficherDetailPanier() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'Panier',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark),
                  ),
                  const Spacer(),
                  Text(
                    '${_fmt(_totalPanier)} FCFA',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _isVente ? terracotta : brickRed),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(20),
                itemCount: _panier.length,
                itemBuilder: (ctx, idx) {
                  final item = _panier[idx];
                  final p = item['produit'] as Map<String, dynamic>;
                  final q = item['quantite'] as int;
                  final prix = item['prixUnit'] as double;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Text(p['emoji'] ?? '📦', style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['nom'] ?? '',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_fmt(prix)} FCFA × $q',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${_fmt(prix * q)} FCFA',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _isVente ? terracotta : brickRed,
                          ),
                        ),
                      ],
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
  Widget _buildModeMontantLibre(Color couleur) {
    final bool isVente = _isVente;

    final Color frameBg = isVente ? const Color(0xFFF8F9FA) : couleur.withOpacity(0.08);
    final Color frameBorder = isVente ? Colors.grey.shade300 : couleur.withOpacity(0.2);
    final Color shortcutBorder = isVente ? Colors.grey.shade300 : couleur.withOpacity(0.3);

    final montantUnitaire = int.tryParse(_montantStr) ?? 0;
    final total = montantUnitaire * _quantite;

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: frameBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: frameBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _fmtStr(_montantStr),
                          style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                              letterSpacing: 1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_quantite > 1 ? 'FCFA / unité' : 'FCFA',
                        style: TextStyle(
                            fontSize: 16,
                            color: textDark.withOpacity(0.6),
                            fontWeight: FontWeight.w500)),
                  ],
                ),
                if (_quantite > 1) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Total : ${_fmt(total.toDouble())} FCFA',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: couleur),
                  ),
                ],
              ],
            ),
          ),

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
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: shortcutBorder, width: 1.5),
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              v >= 1000 ? '${v ~/ 1000}k' : '$v',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: textDark),
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

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildNumRow(['7', '8', '9'], couleur),
                const SizedBox(height: 8),
                _buildNumRow(['4', '5', '6'], couleur),
                const SizedBox(height: 8),
                _buildNumRow(['1', '2', '3'], couleur),
                const SizedBox(height: 8),
                _buildNumRow(['C', '0', '⌫'], couleur),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ NOUVEAU : quantité optionnelle
                _buildQuantiteSelector(couleur),
                const SizedBox(height: 16),
                const Text('Description (optionnel)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  focusNode: _descriptionFocus,
                  style: const TextStyle(fontSize: 14, color: textDark),
                  decoration: InputDecoration(
                    hintText: 'Ex: Vente au client régulier',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: couleur, width: 2)),
                  ),
                ),
                const SizedBox(height: 16),
                _buildModePaiementSelector(couleur),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _buildBoutonValider(couleur, label: '✅  VALIDER'),
        ],
      ),
    );
  }

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
          // Réinitialise les champs spécifiques pour éviter toute fuite d'état entre vente/dépense
          _categorieDepense = null;
          _descriptionController.clear();
          _modePaiementSelectionne = ModePaiement.especes;
          _quantite = 1;
        });
        _fadeController.forward();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? couleur : Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
                isVente ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: active ? Colors.white : Colors.grey[500],
                size: 22),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: active ? Colors.white : Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildNumRow(List<String> touches, Color couleur) {
    return Row(
      children: touches.map((t) {
        final isBack = t == '⌫';
        final isClear = t == 'C';
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: GestureDetector(
              onTap: () => _appuyerTouche(t),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: isBack || isClear ? Colors.grey[100] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Center(
                  child: isBack
                      ? const Icon(Icons.backspace_outlined, size: 22, color: textDark)
                      : Text(t,
                          style: TextStyle(
                              fontSize: isClear ? 16 : 24,
                              fontWeight: FontWeight.w600,
                              color: textDark)),
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(label,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}