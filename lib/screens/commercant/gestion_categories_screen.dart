import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class GestionCategoriesScreen extends StatefulWidget {
  const GestionCategoriesScreen({super.key});

  @override
  State<GestionCategoriesScreen> createState() => _GestionCategoriesScreenState();
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

  @override
  Widget build(BuildContext context) {
    final categories = _selectedTab == 0 ? _categoriesRecettes : _categoriesDepenses;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Gérer les catégories'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Tabs
          Row(
            children: [
              Expanded(
                child: _buildTab('Recettes', 0, AppColors.primaryGreen),
              ),
              Expanded(
                child: _buildTab('Dépenses', 1, AppColors.expenseRed),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Liste des catégories
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return _buildCategoryCard(category);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('➕ Ajout de catégorie à venir...')),
          );
        },
        backgroundColor: _selectedTab == 0 ? AppColors.primaryGreen : AppColors.expenseRed,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTab(String label, int index, Color color) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? color : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? color : Colors.grey,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              category['icon'] as String,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        title: Text(
          category['nom'] as String,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          category['editable'] ? 'Personnalisée' : 'Par défaut',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: category['editable'] == true
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () {},
                  ),
                ],
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Défaut', style: TextStyle(fontSize: 11)),
              ),
      ),
    );
  }
}