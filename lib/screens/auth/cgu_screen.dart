import 'package:flutter/material.dart';

const Color emeraldDark = Color(0xFF0B4F36);
const Color textDark = Color(0xFF222222);

class CguScreen extends StatelessWidget {
  const CguScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.pop(context),
),
        title: const Text('Conditions d\'Utilisation', style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('1. Objet de l\'application', 'MaFortune est un outil numérique destiné à aider les commerçants et particuliers à gérer leurs finances, suivre leurs ventes, leurs dépenses et établir des bilans. L\'application ne constitue en aucun cas un conseil financier, comptable ou juridique professionnel.'),
            _buildSection('2. Exactitude des données', 'L\'utilisateur est seul responsable des informations et des données chiffrées qu\'il saisit dans l\'application. MaFortune ne peut être tenu responsable des erreurs de calcul, des pertes financières ou des décisions commerciales prises sur la base des données affichées.'),
            _buildSection('3. Sécurité du compte', 'L\'utilisateur s\'engage à garder son code PIN et ses identifiants de connexion strictement confidentiels. Toute activité réalisée via son compte est présumée être effectuée par l\'utilisateur lui-même. En cas de perte ou de vol du téléphone, l\'utilisateur doit nous en informer immédiatement.'),
            _buildSection('4. Fonctionnement hors-ligne', 'MaFortune est conçu pour fonctionner partiellement sans connexion Internet. Cependant, la synchronisation des données, les sauvegardes dans le cloud et certaines fonctionnalités avancées nécessitent une connexion Internet stable.'),
            _buildSection('5. Modification des conditions', 'Nous nous réservons le droit de modifier ces conditions d\'utilisation à tout moment. Les utilisateurs seront informés des changements majeurs via une notification dans l\'application. L\'utilisation continue de l\'application après ces modifications vaut acceptation des nouvelles conditions.'),
            _buildSection('6. Résiliation et suppression des données', 'L\'utilisateur peut supprimer son compte et demander l\'effacement de ses données à tout moment depuis les paramètres de l\'application. Après suppression, les données sont définitivement effacées de nos serveurs sous 30 jours.'),
            
            const SizedBox(height: 32),
            Center(
              child: Text('Dernière mise à jour : Octobre 2026', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: emeraldDark)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.6)),
        ],
      ),
    );
  }
}