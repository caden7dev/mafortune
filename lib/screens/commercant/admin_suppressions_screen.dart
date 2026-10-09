import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/delete_account_service.dart';
import '../../models/utilisateur_model.dart';

// 🎨 CHARTE GRAPHIQUE MA FORTUNE
const Color emeraldDark = Color(0xFF0B4F36);
const Color terracotta = Color(0xFFD96B43);
const Color brickRed = Color(0xFFB91C1C);
const Color textDark = Color(0xFF222222);

class AdminSuppressionsScreen extends StatefulWidget {
  const AdminSuppressionsScreen({super.key});

  @override
  State<AdminSuppressionsScreen> createState() => _AdminSuppressionsScreenState();
}

class _AdminSuppressionsScreenState extends State<AdminSuppressionsScreen> {
  final DeleteAccountService _deleteService = DeleteAccountService();
  bool _isProcessing = false;

  Future<void> _restaurerCompte(String userId, String nom) async {
    setState(() => _isProcessing = true);
    try {
      await _deleteService.restaurerCompte(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Compte de $nom restauré avec succès'), backgroundColor: emeraldDark),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: brickRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _supprimerDefinitivement(String userId, String nom) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('⚠️ Suppression DÉFINITIVE', style: TextStyle(color: brickRed, fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous vraiment supprimer définitivement le compte de $nom et toutes ses données ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: brickRed, foregroundColor: Colors.white),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      try {
        await _deleteService.supprimerDefinitivementCompte(userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('🗑️ Compte de $nom supprimé définitivement'), backgroundColor: emeraldDark),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: brickRed),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Comptes en suppression', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: emeraldDark,
        foregroundColor: Colors.white,
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: emeraldDark))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('utilisateurs')
                  .where('suppressionDemandee', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: emeraldDark));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 64, color: emeraldDark),
                        SizedBox(height: 16),
                        Text('Aucun compte en attente de suppression', style: TextStyle(fontSize: 16, color: textDark)),
                      ],
                    ),
                  );
                }

                final users = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final data = users[index].data() as Map<String, dynamic>;
                    final userId = users[index].id;
                    final nom = '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'.trim();
                    final email = data['email'] ?? 'Non renseigné';
                    
                    DateTime? dateDemande;
                    if (data['dateSuppressionDemandee'] is Timestamp) {
                      dateDemande = (data['dateSuppressionDemandee'] as Timestamp).toDate();
                    }

                    final joursRestants = dateDemande != null 
                        ? (30 - DateTime.now().difference(dateDemande).inDays).clamp(0, 30) 
                        : 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: terracotta.withOpacity(0.1),
                                  child: Text(nom.isNotEmpty ? nom[0].toUpperCase() : '?', style: const TextStyle(color: terracotta, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(nom, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
                                      Text(email, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Expire dans $joursRestants jours',
                                  style: TextStyle(fontSize: 13, color: joursRestants < 5 ? brickRed : Colors.grey[600], fontWeight: FontWeight.w600),
                                ),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _restaurerCompte(userId, nom),
                                      icon: const Icon(Icons.undo_rounded, size: 18, color: emeraldDark),
                                      label: const Text('Restaurer', style: TextStyle(color: emeraldDark, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () => _supprimerDefinitivement(userId, nom),
                                      icon: const Icon(Icons.delete_forever_rounded, size: 18, color: brickRed),
                                      label: const Text('Supprimer', style: TextStyle(color: brickRed, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}