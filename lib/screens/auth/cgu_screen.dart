import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const Color emeraldDark = Color(0xFF0B4F36);
const Color textDark = Color(0xFF222222);

class CguScreen extends StatelessWidget {
  const CguScreen({super.key});

  // Fonction pour ouvrir les liens (email ou site web)
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Impossible d\'ouvrir : $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Conditions d'Utilisation, MaFortune", 
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 18)
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. INTRODUCTION
            _buildSection(
              "1. Introduction", 
              "Bienvenue sur MaFortune.\n\n"
              "Les présentes Conditions d'utilisation (ci-après les « Conditions ») constituent un contrat juridiquement contraignant entre vous (ci-après l'« Utilisateur ») et MaFortune.\n\n"
              "MaFortune est une application de gestion financière conçue pour aider les commerçants du secteur informel au Togo à suivre leurs recettes et dépenses, générer des rapports et mieux gérer leur activité.\n\n"
              "L'utilisation de l'application MaFortune implique l'acceptation pleine et entière des présentes Conditions d'utilisation et de la Politique de confidentialité. Si vous n'acceptez pas l'une de ces conditions, vous devez cesser d'utiliser nos services."
            ),

            // 2. CONDITIONS D'ACCÈS
            _buildSection(
              "2. Conditions d'accès à l'application", 
              "2.1 Âge et capacité juridique\n"
              "Pour utiliser l'application MaFortune, vous devez être âgé(e) du minimum légal requis dans votre pays de résidence pour conclure un contrat et utiliser des services numériques, et posséder la capacité juridique d'agir pour vous-même.\n\n"
              "2.2 Exactitude des informations\n"
              "Lors de votre inscription, vous vous engagez à fournir des informations exactes, complètes et à jour, notamment concernant votre activité commerciale. Vous êtes seul responsable du maintien de la confidentialité de vos identifiants de connexion (code PIN, email)."
            ),

            // 3. DESCRIPTION DES SERVICES
            _buildSection(
              "3. Description des services", 
              "L'application MaFortune propose notamment les fonctionnalités suivantes :\n"
              "• Suivi de vos recettes et dépenses\n"
              "• Tableau de bord avec statistiques\n"
              "• Génération de rapports et bilans\n"
              "• Gestion de catégories personnalisées\n"
              "• Budget mensuel\n"
              "• Sauvegarde et synchronisation des données\n\n"
              "L'application est accessible gratuitement. Tous les services sont offerts « tels quels », sans garantie de résultat quant à la performance financière de votre activité."
            ),

            // 4. OBLIGATIONS DES UTILISATEURS
            _buildSection(
              "4. Obligations des utilisateurs", 
              "Chaque utilisateur s'engage à :\n"
              "• Ne pas usurper l'identité d'un tiers\n"
              "• Ne pas diffuser de contenu haineux, diffamatoire, illégal ou discriminatoire\n"
              "• Utiliser l'application dans le respect des lois applicables\n"
              "• Saisir des données financières de bonne foi\n"
              "• Respecter les autres utilisateurs ainsi que l'équipe de support\n\n"
              "MaFortune se réserve le droit de suspendre tout compte en cas de comportement jugé abusif ou contraire aux présentes conditions."
            ),

            // 5. PROPRIÉTÉ INTELLECTUELLE
            _buildSection(
              "5. Propriété intellectuelle", 
              "Tous les éléments visuels, textuels, graphiques ou technologiques présents dans l'application MaFortune sont la propriété exclusive de MaFortune. Toute reproduction, diffusion, adaptation ou exploitation commerciale est interdite sans consentement écrit.\n\n"
              "Les données financières saisies par les utilisateurs demeurent leur propriété, mais MaFortune se réserve le droit de les traiter de manière anonymisée à des fins d'amélioration du service."
            ),

            // 6. SUSPENSION OU SUPPRESSION DE COMPTE
            _buildSection(
              "6. Suspension ou suppression de compte", 
              "MaFortune peut suspendre ou supprimer un compte sans préavis en cas de violation des Conditions d'utilisation, de comportement frauduleux ou dangereux, de signalements multiples ou d'activité contraire aux lois applicables.\n\n"
              "La suppression d'un compte n'entraîne aucun droit à remboursement. L'utilisateur peut également demander la suppression de son compte et de ses données à tout moment depuis les paramètres de l'application."
            ),

            // 7. RESPONSABILITÉ
            _buildSection(
              "7. Responsabilité", 
              "MaFortune n'est pas responsable :\n"
              "• Du contenu généré par les utilisateurs\n"
              "• Des erreurs de calcul ou des pertes financières résultant d'une mauvaise utilisation de l'application\n"
              "• Des décisions commerciales prises sur la base des données affichées\n\n"
              "MaFortune agit uniquement en tant que fournisseur d'outil technologique de gestion. L'application ne constitue en aucun cas un conseil financier, comptable ou juridique professionnel."
            ),

            // 8. POLITIQUE DE TOLÉRANCE ZÉRO
            _buildSection(
              "8. Politique de tolérance zéro", 
              "En utilisant l'application MaFortune, les utilisateurs sont tenus d'accepter les présentes Conditions d'utilisation. MaFortune applique une politique de tolérance zéro à l'égard de tout contenu inapproprié, abusif, haineux, discriminatoire ou illégal.\n\n"
              "Tout utilisateur enfreignant ces règles s'expose à la suppression immédiate du contenu concerné ainsi qu'à la suspension ou à la suppression définitive de son compte, sans préavis."
            ),
            

            // 10. ACCEPTATION DES CONDITIONS
            _buildSection(
              "9. Acceptation des conditions", 
              "L'accès et l'utilisation de l'application MaFortune sont strictement conditionnés à l'acceptation préalable des présentes Conditions d'utilisation. En créant un compte ou en continuant à utiliser l'application, vous acceptez expressément de vous conformer à ces Conditions, notamment l'interdiction de tout contenu inapproprié ou comportement abusif.\n\n"
              "Si vous n'acceptez pas ces Conditions, vous devez cesser immédiatement toute utilisation de l'application."
            ),

            // 11. DROIT APPLICABLE
            _buildSection(
              "10. Droit applicable et règlement des différends", 
              "Les présentes Conditions sont régies par les lois de la République Togolaise. En cas de litige, les parties s'engagent à tenter une résolution à l'amiable. À défaut, le différend sera soumis à la compétence exclusive des tribunaux compétents du Togo."
            ),

            const SizedBox(height: 32),

            _buildSection(
              "11. Contact", 
              "Pour toute question concernant ces Conditions, vous pouvez nous contacter :"
            ),
            const SizedBox(height: 12),
            
            _buildContactItem(
              icon: Icons.email_outlined,
              text: "ahadzicaden7@gmail.com",
              url: "mailto:ahadzicaden7@gmail.com?subject=Support%20MaFortune",
            ),
            const SizedBox(height: 12),
            _buildContactItem(
              icon: Icons.language_outlined,
              text: "www.mafortune.tg",
              url: "https://www.mafortune.tg",
            ),

            const SizedBox(height: 24),
            const Divider(thickness: 1, color: Colors.grey),
            const SizedBox(height: 24),

            // MESSAGE DE REMERCIEMENT (SANS CADRE)
            const Text(
              "Merci d'utiliser MaFortune et de contribuer à faire de cette application un espace professionnel, humain et fiable.",
              style: TextStyle(
                fontSize: 15,
                color: textDark,
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),
            Center(
              child: Text(
                "Dernière mise à jour : Octobre 2026", 
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 16),
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
          Text(
            title, 
            style: const TextStyle(
              fontSize: 17, 
              fontWeight: FontWeight.bold, 
              color: emeraldDark,
              height: 1.3
            )
          ),
          const SizedBox(height: 10),
          Text(
            content, 
            style: const TextStyle(
              fontSize: 15, 
              color: Colors.black87, 
              height: 1.6
            ),
          ),
        ],
      ),
    );
  }

  // Widget pour les éléments de contact
  Widget _buildContactItem({required IconData icon, required String text, required String url}) {
    return GestureDetector(
      onTap: () => _launchUrl(url),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: emeraldDark, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15, 
                  fontWeight: FontWeight.w500, 
                  color: textDark,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.grey,
                ),
              ),
            ),
            const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}