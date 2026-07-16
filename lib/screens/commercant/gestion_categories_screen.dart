import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class GestionCategoriesScreen extends StatefulWidget {
  const GestionCategoriesScreen({super.key});

  @override
  State<GestionCategoriesScreen> createState() =>
      _GestionCategoriesScreenState();
}

class _GestionCategoriesScreenState extends State<GestionCategoriesScreen> {
  int _selectedTab = 0; // 0 = Recettes, 1 = Dépenses

  final List<Map<String, dynamic>> _categoriesRecettes = [
    {'id': 'ventes', 'nom': 'Ventes', 'icon': '💰', 'editable': false},
    {'id': 'services', 'nom': 'Services', 'icon': '🔧', 'editable': false},
    {'id': 'autres_recettes', 'nom': 'Autres recettes', 'icon': '💼', 'editable': false},
  ];

  final List<Map<String, dynamic>> _categoriesDepenses = [
    {'id': 'achats', 'nom': 'Achats', 'icon': '🛒', 'editable': false},
    {'id': 'transport', 'nom': 'Transport', 'icon': '🚗', 'editable': false},
    {'id': 'loyer', 'nom': 'Loyer', 'icon': '🏠', 'editable': false},
    {'id': 'salaires', 'nom': 'Salaires', 'icon': '👨‍💼', 'editable': false},
    {'id': 'electricite', 'nom': 'Électricité', 'icon': '💡', 'editable': false},
    {'id': 'autres_depenses', 'nom': 'Autres dépenses', 'icon': '📊', 'editable': false},
  ];

  // ─── Ajout catégorie ─────────────────────────────────────────────────────────
  void _showAddCategorySheet() {
    final controller = TextEditingController();
    String selectedEmoji = '📌';

    final emojis = [
      '📌', '🛍️', '🍽️', '🚌', '💊', '📚', '🎁', '🏪',
      '⚡', '💧', '📞', '🧹', '🔨', '🌾', '🐟', '👗',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                _selectedTab == 0
                    ? '➕ Nouvelle catégorie de recette'
                    : '➕ Nouvelle catégorie de dépense',
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Nom
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  labelText: '✍️  Nom de la catégorie',
                  labelStyle:
                      TextStyle(fontSize: 15, color: Colors.grey[600]),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: AppColors.primaryGreen, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                ),
              ),

              const SizedBox(height: 18),

              // Choisir emoji
              const Text(
                'Choisir une icône :',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: emojis.map((e) {
                  final isSelected = selectedEmoji == e;
                  return GestureDetector(
                    onTap: () => setModal(() => selectedEmoji = e),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryGreen.withOpacity(0.15)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryGreen
                              : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(e,
                            style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Bouton enregistrer
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: () {
                    final nom = controller.text.trim();
                    if (nom.isEmpty) return;
                    final newCat = {
                      'id': nom.toLowerCase().replaceAll(' ', '_'),
                      'nom': nom,
                      'icon': selectedEmoji,
                      'editable': true,
                    };
                    setState(() {
                      if (_selectedTab == 0) {
                        _categoriesRecettes.add(newCat);
                      } else {
                        _categoriesDepenses.add(newCat);
                      }
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '$selectedEmoji "$nom" ajoutée',
                          style: const TextStyle(fontSize: 16),
                        ),
                        backgroundColor: AppColors.primaryGreen,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Supprimer catégorie ──────────────────────────────────────────────────────
  Future<void> _deleteCategory(Map<String, dynamic> cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cat['icon'] as String,
                style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text(
              'Supprimer "${cat['nom']}" ?',
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Cette catégorie sera supprimée définitivement.',
              style:
                  TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Supprimer',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Annuler',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      setState(() {
        if (_selectedTab == 0) {
          _categoriesRecettes.remove(cat);
        } else {
          _categoriesDepenses.remove(cat);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ "${cat['nom']}" supprimée',
                style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // ─── Renommer catégorie ───────────────────────────────────────────────────────
  void _renameCategory(Map<String, dynamic> cat) {
    final controller = TextEditingController(text: cat['nom'] as String);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(cat['icon'] as String,
                    style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                const Text(
                  'Renommer la catégorie',
                  style: TextStyle(
                      fontSize: 19, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Nouveau nom',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: AppColors.primaryGreen, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  final nom = controller.text.trim();
                  if (nom.isEmpty) return;
                  setState(() => cat['nom'] = nom);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Renommée en "$nom"',
                          style: const TextStyle(fontSize: 16)),
                      backgroundColor: AppColors.primaryGreen,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Enregistrer',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─── BUILD PRINCIPAL ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isRecettes = _selectedTab == 0;
    final categories =
        isRecettes ? _categoriesRecettes : _categoriesDepenses;
    final tabColor =
        isRecettes ? AppColors.primaryGreen : const Color(0xFFC62828);

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
          '🏷️ Mes catégories',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // ── Tabs grands ────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(child: _buildTab('📈 Recettes', 0, AppColors.primaryGreen)),
                Expanded(child: _buildTab('📉 Dépenses', 1, const Color(0xFFC62828))),
              ],
            ),
          ),

          // ── Compteur ───────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${categories.length} catégorie${categories.length > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ),
          ),

          // ── Liste ──────────────────────────────────────────────────────────
          Expanded(
            child: categories.isEmpty
                ? _buildEmptyState(tabColor)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: categories.length,
                    itemBuilder: (context, index) =>
                        _buildCategoryCard(categories[index], tabColor),
                  ),
          ),
        ],
      ),

      // ── FAB — Ajouter ─────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCategorySheet,
        backgroundColor: tabColor,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Text('➕', style: TextStyle(fontSize: 20)),
        label: const Text(
          'Ajouter',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ─── TAB ────────────────────────────────────────────────────────────────────
  Widget _buildTab(String label, int index, Color color) {
    final selected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? color : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? color : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  // ─── CARTE CATÉGORIE ─────────────────────────────────────────────────────────
  Widget _buildCategoryCard(Map<String, dynamic> cat, Color tabColor) {
    final isEditable = cat['editable'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Emoji dans cercle coloré
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: tabColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  cat['icon'] as String,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Nom + badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat['nom'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isEditable
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isEditable ? '✏️ Personnalisée' : '🔒 Par défaut',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isEditable
                            ? Colors.blue[700]
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Actions — seulement si editable
            if (isEditable)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Renommer
                  GestureDetector(
                    onTap: () => _renameCategory(cat),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text('✏️', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Supprimer
                  GestureDetector(
                    onTap: () => _deleteCategory(cat),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text('🗑️', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ),
                ],
              )
            else
              // Cadenas — non modifiable
              const Text('🔒', style: TextStyle(fontSize: 20, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // ─── ÉTAT VIDE ───────────────────────────────────────────────────────────────
  Widget _buildEmptyState(Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏷️', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          const Text(
            'Aucune catégorie',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'Appuyez sur "Ajouter" pour créer\nvotre première catégorie.',
            style: TextStyle(
                fontSize: 15, color: Colors.grey[600], height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}