import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../services/permission_service.dart';
import '../../models/utilisateur_model.dart';
import '../../widgets/screenshot_wrapper.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PermissionService _permissionService = PermissionService();
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoading = true;
  bool _isAdmin = false;
  String _selectedFilter = 'Tous';
  List<UtilisateurModel> _allUsers = [];
  List<UtilisateurModel> _filteredUsers = [];
  
  int _totalUsers = 0;
  int _activeUsers = 0;
  int _inactiveUsers = 0;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAccess() async {
    final isAdmin = await _permissionService.isAdmin();
    
    if (!isAdmin && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Accès refusé : Administrateur uniquement'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
      return;
    }
    
    setState(() => _isAdmin = true);
    await _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    
    try {
      final snapshot = await _firestore
          .collection('utilisateurs')
          .orderBy('dateCreation', descending: true)
          .get();
      
      _allUsers = snapshot.docs
          .map((doc) => UtilisateurModel.fromFirestore(doc))
          .toList();
      
      _totalUsers = _allUsers.length;
      _activeUsers = _allUsers.where((u) => u.estActif).length;
      _inactiveUsers = _totalUsers - _activeUsers;
      
      _applyFilter();
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      if (_selectedFilter == 'Tous') {
        _filteredUsers = List.from(_allUsers);
      } else if (_selectedFilter == 'Commerçants') {
        _filteredUsers = _allUsers
            .where((u) => u.typeUtilisateur == TypeUtilisateur.commercant)
            .toList();
      } else if (_selectedFilter == 'Actifs') {
        _filteredUsers = _allUsers.where((u) => u.estActif).toList();
      } else if (_selectedFilter == 'Inactifs') {
        _filteredUsers = _allUsers.where((u) => !u.estActif).toList();
      }
      
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        _filteredUsers = _filteredUsers.where((u) {
          return u.nom.toLowerCase().contains(query) ||
                 u.prenom.toLowerCase().contains(query) ||
                 u.email.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _toggleUserStatus(UtilisateurModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.estActif ? 'Désactiver l\'utilisateur' : 'Activer l\'utilisateur'),
        content: Text(
          user.estActif
              ? 'Voulez-vous désactiver ${user.nomComplet} ? Il ne pourra plus se connecter.'
              : 'Voulez-vous activer ${user.nomComplet} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: user.estActif ? Colors.red : AppColors.primaryGreen,
            ),
            child: Text(user.estActif ? 'Désactiver' : 'Activer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore
            .collection('utilisateurs')
            .doc(user.id)
            .update({'estActif': !user.estActif});
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                user.estActif ? '✅ Utilisateur désactivé' : '✅ Utilisateur activé',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          _loadUsers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showUserDetails(UtilisateurModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        user.nom[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.nomComplet,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: user.estActif ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: user.estActif ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          user.estActif ? 'Actif' : 'Inactif',
                          style: TextStyle(
                            color: user.estActif ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              _buildInfoSection('Informations générales', [
                _buildInfoRow('Type', _getUserTypeLabel(user.typeUtilisateur)),
                _buildInfoRow('Téléphone', user.telephone),
                if (user.typeActivite != null) _buildInfoRow('Activité', user.typeActivite!),
                if (user.adresse != null) _buildInfoRow('Adresse', user.adresse!),
                _buildInfoRow('Membre depuis', _formatDate(user.dateCreation)),
              ]),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _toggleUserStatus(user);
                      },
                      icon: Icon(
                        user.estActif ? Icons.block : Icons.check_circle,
                        color: user.estActif ? Colors.red : AppColors.primaryGreen,
                      ),
                      label: Text(
                        user.estActif ? 'Désactiver' : 'Activer',
                        style: TextStyle(
                          color: user.estActif ? Colors.red : AppColors.primaryGreen,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(
                          color: user.estActif ? Colors.red : AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isAdmin) {
      return const Scaffold(body: Center(child: Text('Accès refusé')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1976D2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Gestion Utilisateurs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadUsers,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _applyFilter(),
              decoration: InputDecoration(
                hintText: 'Rechercher un utilisateur...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildFilterChip('Tous'),
                const SizedBox(width: 10),
                _buildFilterChip('Commerçants'),
                const SizedBox(width: 10),
                _buildFilterChip('Actifs'),
                const SizedBox(width: 10),
                _buildFilterChip('Inactifs'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _buildStatBadge('$_totalUsers', 'Total')),
                const SizedBox(width: 10),
                Expanded(child: _buildStatBadge('$_activeUsers', 'Actifs')),
                const SizedBox(width: 10),
                Expanded(child: _buildStatBadge('$_inactiveUsers', 'Inactifs')),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              ),
              child: _filteredUsers.isEmpty
                  ? const Center(child: Text('Aucun utilisateur trouvé', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _filteredUsers.length,
                      separatorBuilder: (context, index) => const Divider(height: 30),
                      itemBuilder: (context, index) => _buildUserCard(_filteredUsers[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () {
        setState(() => _selectedFilter = label);
        _applyFilter();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF1976D2) : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildUserCard(UtilisateurModel user) {
    return InkWell(
      onTap: () => _showUserDetails(user),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user.nom[0].toUpperCase(),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.nomComplet, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(user.email, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(_getUserTypeLabel(user.typeUtilisateur), style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: user.estActif ? Colors.green : Colors.red, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  String _getUserTypeLabel(TypeUtilisateur type) {
    switch (type) {
      case TypeUtilisateur.administrateur:
        return 'Administrateur';
      case TypeUtilisateur.commercant:
        return 'Commerçant';
      case TypeUtilisateur.partenaire:
        return 'Partenaire';
    }
  }

  String _formatDate(DateTime date) {
    const months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}