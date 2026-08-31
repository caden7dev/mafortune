import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../core/data/produits_par_activite.dart';

class MesProduitsScreen extends StatefulWidget {
  final bool isOnboarding;
  const MesProduitsScreen({super.key, this.isOnboarding = false});

  @override
  State<MesProduitsScreen> createState() => _MesProduitsScreenState();
}

class _MesProduitsScreenState extends State<MesProduitsScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _produits = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String _typeActivite = '';

  // Produits suggérés à confirmer (onboarding)
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      // Charger le type d'activité
      final userDoc = await _db
          .collection('utilisateurs')
          .doc(user.uid)
          .get();
      _typeActivite = userDoc.data()?['typeActivite'] ?? '';

      // Charger les produits existants
      final snap = await _db
          .collection('produits')
          .where('commercantId', isEqualTo: user.uid)
          .where('estActif', isEqualTo: true)
          .get();

      final existants = snap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

      setState(() {
        _produits = existants;
        // En onboarding + pas encore de produits → affiche suggestions
        if (widget.isOnboarding && existants.isEmpty) {
          _suggestions = ProduitsParActivite.getPourActivite(_typeActivite);
          _showSuggestions = true;
        }
      });
    } catch (e) {
      debugPrint('Erreur chargement: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Confirmer les suggestions avec prix ────────────────────────────────
  Future<void> _confirmerSuggestions(
      List<Map<String, dynamic>> selected) async {
    setState(() => _isSaving = true);
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final batch = _db.batch();
      for (final p in selected) {
        final ref = _db.collection('produits').doc();
        batch.set(ref, {
          'commercantId': user.uid,
          'nom': p['nom'],
          'emoji': p['emoji'] ?? '📦',
          'prix': p['prix'],
          'estActif': true,
          'dateCreation': Timestamp.now(),
        });
      }
      await batch.commit();
      await _loadData();
      setState(() => _showSuggestions = false);
    } catch (e) {
      debugPrint('Erreur confirmation suggestions: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Ajouter / Modifier produit ─────────────────────────────────────────
  void _showAddSheet({Map<String, dynamic>? existing}) {
    final nomController =
        TextEditingController(text: existing?['nom'] ?? '');
    final prixController = TextEditingController(
      text: existing?['prix'] != null
          ? (existing!['prix'] as num).toInt().toString()
          : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                existing != null
                    ? '✏️ Modifier le produit'
                    : '➕ Nouveau produit / service',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E)),
              ),
              const SizedBox(height: 20),
              _buildField(
                controller: nomController,
                label: '📦  Nom du produit ou service *',
                hint: 'Ex: Pagne wax, Coupe homme...',
                autofocus: true,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: prixController,
                label: '💰  Prix habituel (optionnel)',
                hint: 'Ex: 15000',
                keyboardType: TextInputType.number,
                suffixText: 'FCFA',
              ),
              const SizedBox(height: 8),
              Text(
                '💡 Le prix sera pré-rempli automatiquement lors de la saisie',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    final nom = nomController.text.trim();
                    if (nom.isEmpty) return;
                    final prix = double.tryParse(
                        prixController.text.trim());
                    Navigator.pop(ctx);
                    await _sauvegarderProduit(
                      nom: nom,
                      prix: prix,
                      existingId: existing?['id'],
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('💾  Enregistrer',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sauvegarderProduit({
    required String nom,
    double? prix,
    String? existingId,
  }) async {
    setState(() => _isSaving = true);
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      if (existingId != null) {
        await _db.collection('produits').doc(existingId).update({
          'nom': nom,
          'prix': prix,
        });
      } else {
        await _db.collection('produits').add({
          'commercantId': user.uid,
          'nom': nom,
          'emoji': '📦',
          'prix': prix,
          'estActif': true,
          'dateCreation': Timestamp.now(),
        });
      }
      await _loadData();
      if (mounted) {
        _showSnack(existingId != null
            ? '✅ "$nom" modifié'
            : '✅ "$nom" ajouté');
      }
    } catch (e) {
      debugPrint('Erreur sauvegarde: $e');
      if (mounted) _showSnack('❌ Erreur lors de l\'enregistrement', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _supprimerProduit(Map<String, dynamic> p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🗑️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('Supprimer "${p['nom']}" ?',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Supprimer',
                      style:
                          TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await _db
          .collection('produits')
          .doc(p['id'])
          .update({'estActif': false});
      await _loadData();
      if (mounted) _showSnack('🗑️ "${p['nom']}" supprimé');
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 15)),
      backgroundColor:
          isError ? Colors.red : AppColors.primaryGreen,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _formatPrix(double? prix) {
    if (prix == null) return 'Prix libre';
    return '${prix.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} FCFA';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: widget.isOnboarding
            ? null
            : GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 18),
                ),
              ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📦 Mes produits & services',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            if (_typeActivite.isNotEmpty)
              Text(_typeActivite,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8))),
          ],
        ),
        actions: [
          if (widget.isOnboarding)
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(
                  context, '/dashboard'),
              child: const Text('Passer →',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primaryGreen))
          : _showSuggestions
              ? _buildSuggestionsView()
              : _buildProduitsView(),
      floatingActionButton: _showSuggestions
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddSheet,
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Text('➕', style: TextStyle(fontSize: 20)),
              label: const Text('Ajouter',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
    );
  }

  // Controllers persistants pour les prix — évite la perte de données au rebuild
  final Map<int, TextEditingController> _prixControllers = {};
  final Map<int, bool> _selected = {};
  bool _suggestionsInitialisees = false;

  void _initSuggestions() {
    if (_suggestionsInitialisees) return;
    for (int i = 0; i < _suggestions.length; i++) {
      _prixControllers[i] = TextEditingController(
        text: _suggestions[i]['prix'] != null
            ? (_suggestions[i]['prix'] as num).toInt().toString()
            : '',
      );
      _selected[i] = true;
    }
    _suggestionsInitialisees = true;
  }

  // ─── VUE SUGGESTIONS (onboarding) ────────────────────────────────────────
  Widget _buildSuggestionsView() {
    _initSuggestions();

    return StatefulBuilder(
      builder: (context, setLocal) {
        return Column(
          children: [
            // Bandeau
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.primaryGreen.withOpacity(0.08),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('🎯', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 10),
                      Text(
                        'Produits suggérés pour toi',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Coche les produits que tu vends et ajoute les prix. Tu pourras modifier plus tard.',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.4),
                  ),
                ],
              ),
            ),

            // Liste suggestions
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                itemCount: _suggestions.length,
                itemBuilder: (ctx, i) {
                  final p = _suggestions[i];
                  final isSelected = _selected[i] ?? true;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryGreen
                                .withOpacity(0.4)
                            : Colors.grey[200]!,
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          // Checkbox
                          GestureDetector(
                            onTap: () =>
                                setLocal(() => _selected[i] = !isSelected),
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 150),
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryGreen
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryGreen
                                      : Colors.grey[400]!,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      color: Colors.white,
                                      size: 16)
                                  : null,
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Emoji + nom
                          Text(p['emoji'] ?? '📦',
                              style:
                                  const TextStyle(fontSize: 24)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              p['nom'] ?? '',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? const Color(0xFF1A1A2E)
                                    : Colors.grey[400],
                              ),
                            ),
                          ),

                          // Champ prix
                          if (isSelected)
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _prixControllers[i],
                                keyboardType:
                                    TextInputType.number,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: 'Prix',
                                  hintStyle: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 13),
                                  suffixText: 'F',
                                  suffixStyle: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12),
                                  filled: true,
                                  fillColor:
                                      const Color(0xFFF8F9FA),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE5E7EB)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE5E7EB)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color:
                                            AppColors.primaryGreen,
                                        width: 2),
                                  ),
                                ),
                                onChanged: (val) {
                                  _suggestions[i]['prix'] =
                                      double.tryParse(val);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Boutons bas
            Container(
              padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              // Met à jour les prix depuis les controllers
                              for (int i = 0;
                                  i < _suggestions.length;
                                  i++) {
                                final val = _prixControllers[i]
                                    ?.text
                                    .trim();
                                _suggestions[i]['prix'] =
                                    val != null && val.isNotEmpty
                                        ? double.tryParse(val)
                                        : null;
                              }

                              final selectionnes = [
                                for (int i = 0;
                                    i < _suggestions.length;
                                    i++)
                                  if (_selected[i] == true)
                                    _suggestions[i]
                              ];

                              if (selectionnes.isEmpty) {
                                setState(() =>
                                    _showSuggestions = false);
                              } else {
                                _confirmerSuggestions(
                                    selectionnes);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Text(
                              '✅  Confirmer ma liste de produits',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () =>
                        setState(() => _showSuggestions = false),
                    child: Text(
                      'Ajouter manuellement plutôt',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── VUE PRODUITS (liste) ─────────────────────────────────────────────────
  Widget _buildProduitsView() {
    return Column(
      children: [
        if (widget.isOnboarding)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: AppColors.primaryGreen.withOpacity(0.08),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tu peux ajouter d\'autres produits. Appuie sur ➕ pour en ajouter.',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: _produits.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📦',
                          style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      const Text('Aucun produit',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E))),
                      const SizedBox(height: 8),
                      Text(
                        'Appuie sur ➕ pour ajouter\nce que tu vends.',
                        style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[600],
                            height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  itemCount: _produits.length,
                  itemBuilder: (ctx, i) {
                    final p = _produits[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen
                                    .withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  p['emoji'] ?? '📦',
                                  style: const TextStyle(
                                      fontSize: 22),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p['nom'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _formatPrix((p['prix'] as num?)
                                        ?.toDouble()),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: p['prix'] != null
                                          ? AppColors.primaryGreen
                                          : Colors.grey[500],
                                      fontWeight: p['prix'] != null
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => _showAddSheet(
                                      existing: p),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.blue
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(
                                              10),
                                    ),
                                    child: const Center(
                                      child: Text('✏️',
                                          style: TextStyle(
                                              fontSize: 16)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () =>
                                      _supprimerProduit(p),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.red
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(
                                              10),
                                    ),
                                    child: const Center(
                                      child: Text('🗑️',
                                          style: TextStyle(
                                              fontSize: 16)),
                                    ),
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

        if (widget.isOnboarding && _produits.isNotEmpty)
          Container(
            padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.of(context).padding.bottom + 16),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(
                    context, '/dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  '🚀  Commencer à utiliser MaFortune',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? suffixText,
    bool autofocus = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          autofocus: autofocus,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: Colors.grey[400], fontSize: 14),
            suffixText: suffixText,
            suffixStyle: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: Color(0xFFE5E7EB), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: Color(0xFFE5E7EB), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: AppColors.primaryGreen, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}