import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../core/data/produits_par_activite.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE (Mobile)
const Color emeraldDark = Color(0xFF0B4F36);   // Vert Émeraude Sombre
const Color terracotta = Color(0xFFD96B43);    // Terre Cuite
const Color brickRed = Color(0xFFB91C1C);      // Rouge Brique doux
const Color textDark = Color(0xFF222222);      // Gris anthracite très foncé

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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ Utilisateur non connecté lors du chargement');
        return;
      }

      final userDoc = await _db.collection('utilisateurs').doc(user.uid).get();
      _typeActivite = userDoc.data()?['typeActivite'] ?? '';

      final snap = await _db
          .collection('produits')
          .where('commercantId', isEqualTo: user.uid)
          .where('estActif', isEqualTo: true)
          .get();

      final existants = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      setState(() {
        _produits = existants;
        if (widget.isOnboarding && existants.isEmpty) {
          _suggestions = ProduitsParActivite.getPourActivite(_typeActivite);
          
          // ✅ FALLBACK : Si l'activité n'est pas reconnue, on propose "Commerce divers"
          if (_suggestions.isEmpty) {
            _suggestions = ProduitsParActivite.getPourActivite('Commerce divers');
          }
          
          _showSuggestions = _suggestions.isNotEmpty;
        }
      });
    } catch (e) {
      debugPrint('❌ Erreur chargement: $e');
      if (mounted) _showSnack('Erreur de chargement des données', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmerSuggestions(List<Map<String, dynamic>> selected) async {
    debugPrint('🚀 Tentative de sauvegarde de ${selected.length} produits...');
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('❌ Utilisateur non connecté');
      if (mounted) {
        _showSnack('❌ Erreur : Veuillez vous reconnecter', isError: true);
        setState(() => _isSaving = false);
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
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

      debugPrint('💾 Envoi des données à Firestore...');
      await batch.commit();
      debugPrint('✅ Données sauvegardées avec succès !');

      if (mounted) {
        _showSnack('✅ ${selected.length} produit(s) ajouté(s) avec succès !');
        
        // ✅ REDIRECTION EXPLICITE VERS LE DASHBOARD SI ONBOARDING
        if (widget.isOnboarding) {
          Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
        } else {
          await _loadData();
          setState(() => _showSuggestions = false);
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur Firestore: $e');
      if (mounted) {
        _showSnack('❌ Erreur lors de l\'enregistrement : $e', isError: true);
      }
    } finally {
      debugPrint('🔄 Passage dans le finally pour débloquer le bouton');
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showAddSheet({Map<String, dynamic>? existing}) {
    final nomController = TextEditingController(text: existing?['nom'] ?? '');
    final prixController = TextEditingController(
      text: existing?['prix'] != null ? (existing!['prix'] as num).toInt().toString() : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: emeraldDark.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      existing != null ? Icons.edit_outlined : Icons.add_circle_outline,
                      color: emeraldDark,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    existing != null ? 'Modifier le produit' : 'Nouveau produit / service',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildField(
                controller: nomController,
                icon: Icons.inventory_2_outlined,
                label: 'Nom du produit ou service *',
                hint: 'Ex: Pagne wax, Coupe homme...',
                autofocus: true,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: prixController,
                icon: Icons.attach_money_rounded,
                label: 'Prix habituel (optionnel)',
                hint: 'Ex: 15000',
                keyboardType: TextInputType.number,
                suffixText: 'FCFA',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: 16, color: terracotta),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Le prix sera pré-rempli automatiquement lors de la saisie',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    final nom = nomController.text.trim();
                    if (nom.isEmpty) return;
                    final prix = double.tryParse(prixController.text.trim());
                    Navigator.pop(ctx);
                    await _sauvegarderProduit(
                      nom: nom,
                      prix: prix,
                      existingId: existing?['id'],
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: emeraldDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Enregistrer', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ],
                  ),
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
      final user = FirebaseAuth.instance.currentUser;
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
        _showSnack(existingId != null ? '✅ "$nom" modifié' : '✅ "$nom" ajouté');
      }
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde: $e');
      if (mounted) _showSnack('❌ Erreur lors de l\'enregistrement', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _supprimerProduit(Map<String, dynamic> p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: brickRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 48, color: brickRed),
            ),
            const SizedBox(height: 16),
            Text('Supprimer "${p['nom']}" ?',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textDark,
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brickRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await _db.collection('produits').doc(p['id']).update({'estActif': false});
      await _loadData();
      if (mounted) _showSnack('🗑️ "${p['nom']}" supprimé');
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 15)),
      backgroundColor: isError ? brickRed : emeraldDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        backgroundColor: emeraldDark,
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
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                ),
              ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.inventory_2_rounded, size: 20, color: Colors.white),
                SizedBox(width: 8),
                Text('Mes produits & services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            if (_typeActivite.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 4),
                child: Text(_typeActivite, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
              ),
          ],
        ),
        actions: [
          if (widget.isOnboarding)
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
              child: const Text('Passer', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: emeraldDark))
          : _showSuggestions
              ? _buildSuggestionsView()
              : _buildProduitsView(),
      floatingActionButton: _showSuggestions
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddSheet,
              backgroundColor: emeraldDark,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Ajouter', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
    );
  }

  final Map<int, TextEditingController> _prixControllers = {};
  final Map<int, bool> _selected = {};
  bool _suggestionsInitialisees = false;

  void _initSuggestions() {
    if (_suggestionsInitialisees) return;
    for (int i = 0; i < _suggestions.length; i++) {
      _prixControllers[i] = TextEditingController(
        text: _suggestions[i]['prix'] != null ? (_suggestions[i]['prix'] as num).toInt().toString() : '',
      );
      _selected[i] = true;
    }
    _suggestionsInitialisees = true;
  }

  Widget _buildSuggestionsView() {
    _initSuggestions();

    return StatefulBuilder(
      builder: (context, setLocal) {
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: emeraldDark.withOpacity(0.08),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: emeraldDark.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.auto_awesome_rounded, color: emeraldDark, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Produits suggérés pour toi',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Coche les produits que tu vends et ajoute les prix. Tu pourras modifier plus tard.',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

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
                      color: isSelected ? Colors.white : Colors.grey[50],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? emeraldDark.withOpacity(0.4) : Colors.grey[200]!,
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))] : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setLocal(() => _selected[i] = !isSelected),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: isSelected ? emeraldDark : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? emeraldDark : Colors.grey[400]!,
                                  width: 2,
                                ),
                              ),
                              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(p['emoji'] ?? '📦', style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              p['nom'] ?? '',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? textDark : Colors.grey[400],
                              ),
                            ),
                          ),
                          if (isSelected)
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _prixControllers[i],
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: 'Prix',
                                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                                  suffixText: 'F',
                                  suffixStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                                  filled: true,
                                  fillColor: const Color(0xFFF8F9FA),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: emeraldDark, width: 2),
                                  ),
                                ),
                                // ✅ SUPPRIMÉ : On ne modifie plus _suggestions directement ici
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -3))],
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
                              debugPrint('🔘 Bouton "Confirmer" cliqué !');
                              
                              // ✅ CRITIQUE : Créer une NOUVELLE liste modifiable au lieu de modifier _suggestions
                              final List<Map<String, dynamic>> produitsASauvegarder = [];
                              
                              for (int i = 0; i < _suggestions.length; i++) {
                                if (_selected[i] ?? true) {
                                  final val = _prixControllers[i]?.text.trim();
                                  final double? prixParsed = val != null && val.isNotEmpty 
                                      ? double.tryParse(val) 
                                      : null;
                                  
                                  // On crée une copie propre du produit
                                  produitsASauvegarder.add({
                                    'nom': _suggestions[i]['nom'],
                                    'emoji': _suggestions[i]['emoji'] ?? '📦',
                                    'prix': prixParsed,
                                  });
                                }
                              }

                              debugPrint('📦 Nombre de produits à sauvegarder : ${produitsASauvegarder.length}');

                              if (produitsASauvegarder.isEmpty) {
                                if (mounted) {
                                  setState(() => _showSuggestions = false);
                                  _showSnack('ℹ️ Aucun produit sélectionné.');
                                }
                              } else {
                                _confirmerSuggestions(produitsASauvegarder);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: emeraldDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 20),
                                SizedBox(width: 8),
                                Text('Confirmer ma liste', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => setState(() => _showSuggestions = false),
                    child: Text('Ajouter manuellement plutôt', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProduitsView() {
    return Column(
      children: [
        if (widget.isOnboarding)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: emeraldDark.withOpacity(0.08),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: emeraldDark.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.lightbulb_outline, color: emeraldDark, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tu peux ajouter d\'autres produits. Appuie sur le bouton + pour en ajouter.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
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
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                        child: const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      const Text('Aucun produit', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
                      const SizedBox(height: 8),
                      Text(
                        'Appuie sur le bouton + pour ajouter\nce que tu vends.',
                        style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  itemCount: _produits.length,
                  itemBuilder: (ctx, i) {
                    final p = _produits[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: emeraldDark.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(p['emoji'] ?? '📦', style: const TextStyle(fontSize: 22)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p['nom'] ?? '',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textDark),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _formatPrix((p['prix'] as num?)?.toDouble()),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: p['prix'] != null ? emeraldDark : Colors.grey[500],
                                      fontWeight: p['prix'] != null ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => _showAddSheet(existing: p),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: emeraldDark.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(child: Icon(Icons.edit_outlined, color: emeraldDark, size: 18)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _supprimerProduit(p),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: brickRed.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(child: Icon(Icons.delete_outline_rounded, color: brickRed, size: 18)),
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
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: emeraldDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.rocket_launch_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Commencer à utiliser MaFortune', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? suffixText,
    bool autofocus = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          autofocus: autofocus,
          style: const TextStyle(fontSize: 16, color: textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            suffixText: suffixText,
            suffixStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
            prefixIcon: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: emeraldDark.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: emeraldDark, size: 18),
            ),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: emeraldDark, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}