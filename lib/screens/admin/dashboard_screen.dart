import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../widgets/screenshot_wrapper.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AuthService _authService = AuthService();
  final PermissionService _permissionService = PermissionService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = true;
  bool _isAdmin = false;
  
  int _totalUsers = 0;
  int _activeUsers = 0;
  int _totalTransactions = 0;
  double _totalVolume = 0.0;
  double _growthRate = 0.0;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    setState(() => _isLoading = true);
    
    final isAdmin = await _permissionService.isAdmin();
    
    if (!isAdmin && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Accès refusé : Vous n\'êtes pas administrateur'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pushReplacementNamed(context, '/dashboard');
      return;
    }
    
    setState(() => _isAdmin = true);
    await _loadGlobalStats();
  }

  Future<void> _loadGlobalStats() async {
    try {
      final usersSnapshot = await _firestore.collection('utilisateurs').get();
      _totalUsers = usersSnapshot.docs.length;
      _activeUsers = usersSnapshot.docs.where((doc) => doc.data()['estActif'] == true).length;
      
      final transactionsSnapshot = await _firestore.collection('transactions').get();
      _totalTransactions = transactionsSnapshot.docs.length;
      
      double totalRecettes = 0.0;
      double totalDepenses = 0.0;
      
      for (var doc in transactionsSnapshot.docs) {
        final type = doc.data()['type'] as String?;
        final montant = (doc.data()['montant'] as num?)?.toDouble() ?? 0.0;
        
        if (type == 'recette') {
          totalRecettes += montant;
        } else if (type == 'depense') {
          totalDepenses += montant;
        }
      }
      
      _totalVolume = totalRecettes + totalDepenses;
      _growthRate = 18.5;
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Erreur chargement stats: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    }
  }

  String _getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays > 0) {
      return 'Il y a ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}';
    } else if (diff.inHours > 0) {
      return 'Il y a ${diff.inHours} heure${diff.inHours > 1 ? 's' : ''}';
    } else if (diff.inMinutes > 0) {
      return 'Il y a ${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Accès refusé')),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Text('👨‍💼', style: TextStyle(fontSize: 24)),
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tableau de bord Admin',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Gestion de la plateforme',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, color: Colors.white),
                        tooltip: 'Déconnexion',
                      ),
                    ],
                  ),
                ),
                
                // Stats Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,
                    childAspectRatio: 1.4,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStatCard(
                        icon: '👥',
                        label: 'Utilisateurs actifs',
                        value: _activeUsers.toString(),
                        color: Colors.white.withOpacity(0.95),
                      ),
                      _buildStatCard(
                        icon: '🏪',
                        label: 'Volume total',
                        value: '${(_totalVolume / 1000000).toStringAsFixed(0)}M',
                        color: Colors.white.withOpacity(0.95),
                      ),
                      _buildStatCard(
                        icon: '📊',
                        label: 'Transactions/jour',
                        value: (_totalTransactions / 30).toStringAsFixed(0),
                        color: Colors.white.withOpacity(0.95),
                      ),
                      _buildStatCard(
                        icon: '📈',
                        label: 'Croissance',
                        value: '+${_growthRate.toStringAsFixed(0)}%',
                        color: Colors.white.withOpacity(0.95),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Actions rapides
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Actions rapides',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        crossAxisCount: 2,
                        mainAxisSpacing: 15,
                        crossAxisSpacing: 15,
                        childAspectRatio: 1.2,
                        children: [
                          _buildActionCard(
                            icon: Icons.people,
                            iconColor: const Color(0xFF6A1B9A),
                            title: 'Utilisateurs',
                            subtitle: 'Gérer les comptes',
                            onTap: () => Navigator.pushNamed(context, '/admin/users'),
                          ),
                          _buildActionCard(
                            icon: Icons.bar_chart,
                            iconColor: const Color(0xFF0277BD),
                            title: 'Statistiques',
                            subtitle: 'Voir détails',
                            onTap: () => Navigator.pushNamed(context, '/admin/stats'),
                          ),
                          _buildActionCard(
                            icon: Icons.settings,
                            iconColor: const Color(0xFF6A1B9A),
                            title: 'Paramètres',
                            subtitle: 'Configuration',
                            onTap: () => Navigator.pushNamed(context, '/admin/settings'),
                          ),
                          _buildActionCard(
                            icon: Icons.notifications,
                            iconColor: const Color(0xFFD84315),
                            title: 'Notifications',
                            subtitle: 'Envoyer alertes',
                            onTap: () => Navigator.pushNamed(context, '/admin/notifications'),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Nouveaux utilisateurs
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Nouveaux utilisateurs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 10),
                      
                      // Liste dynamique
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: FutureBuilder<QuerySnapshot>(
                          future: _firestore
                              .collection('utilisateurs')
                              .orderBy('dateCreation', descending: true)
                              .limit(5)
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Text('Aucun utilisateur récent'),
                                ),
                              );
                            }
                            
                            final users = snapshot.data!.docs;
                            
                            return Column(
                              children: users.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final date = (data['dateCreation'] as Timestamp?)?.toDate();
                                final nom = data['nom'] ?? '';
                                final prenom = data['prenom'] ?? '';
                                final email = data['email'] ?? '';
                                final typeUtilisateur = data['typeUtilisateur']?.toString().trim() ?? 'commercant';
                                
                                String roleLabel = 'Commerçant';
                                Color roleColor = Colors.green;
                                if (typeUtilisateur == 'administrateur') {
                                  roleLabel = 'Admin';
                                  roleColor = Colors.purple;
                                }
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 45,
                                        height: 45,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryGreen.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            (prenom.isNotEmpty ? prenom[0] : 'U').toUpperCase(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryGreen,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$prenom $nom',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              email,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: roleColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              roleLabel,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: roleColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            date != null ? _getRelativeTime(date) : 'Récemment',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const Spacer(),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1976D2),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}