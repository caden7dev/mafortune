import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const Color emeraldDark = Color(0xFF0B4F36);
const Color textDark = Color(0xFF222222);

class PolitiqueScreen extends StatelessWidget {
  const PolitiqueScreen({super.key});

  // Fonction pour ouvrir les liens (email ou site web)
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Impossible d'ouvrir : $url");
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
          "Politique de Confidentialité, MaFortune",
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 18)
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // INFORMATIONS LÉGALES
            _buildSection(
              "Informations légales",
              "La présente politique de confidentialité est établie par MaFortune (ci-après « MaFortune », « nous », « notre »), application de gestion financière destinée aux commerçants du Togo.\n\n"
              "MaFortune est responsable du traitement des renseignements personnels collectés dans le cadre de l'exploitation de son application mobile.\n\n"
              "La présente politique a pour objectif d'encadrer de manière claire, transparente et détaillée la collecte, l'utilisation, la conservation, la communication et la protection des renseignements personnels des utilisateurs.\n\n"
              "Elle est conforme aux exigences applicables en matière de protection des données personnelles dans la République Togolaise."
            ),

            // 1. OBJET DE LA POLITIQUE
            _buildSection(
              "1. Objet de la politique",
              "La présente politique vise à informer toute personne utilisant l'application MaFortune ou ses services :\n"
              "• des types de renseignements personnels collectés ;\n"
              "• des finalités de cette collecte ;\n"
              "• des modalités d'utilisation et de conservation des données ;\n"
              "• des droits des utilisateurs ;\n"
              "• ainsi que des responsabilités respectives des parties.\n\n"
              "L'utilisateur reconnaît avoir pris connaissance de la présente politique lors de son utilisation de l'application."
            ),

            // 2. DÉFINITIONS
            _buildSection(
              "2. Définitions",
              "Aux fins de la présente politique :\n\n"
              "• Renseignement personnel : toute information concernant une personne physique et permettant de l'identifier, directement ou indirectement.\n\n"
              "• Utilisateur : toute personne accédant à l'application MaFortune, à titre de commerçant ou particulier.\n\n"
              "• Application MaFortune : plateforme numérique permettant la gestion financière personnelle et professionnelle."
            ),

            // 3. NATURE DE L'APPLICATION ET RÔLE DE MAFORTUNE
            _buildSection(
              "3. Nature de l'application et rôle de MaFortune",
              "MaFortune agit exclusivement en tant qu'outil technologique de gestion financière.\n\n"
              "MaFortune :\n"
              "• ne fournit pas de conseils financiers, comptables ou juridiques professionnels ;\n"
              "• n'est pas partie aux décisions commerciales prises par les utilisateurs ;\n"
              "• n'agit pas comme employeur, mandataire, agent ou représentant des utilisateurs.\n\n"
              "En conséquence, chaque utilisateur demeure pleinement et exclusivement responsable des données qu'il saisit et des décisions qu'il prend sur la base des informations affichées."
            ),

            // 4. RENSEIGNEMENTS PERSONNELS COLLECTÉS
            _buildSection(
              "4. Renseignements personnels collectés",
              "4.1 Données fournies directement par l'utilisateur\n"
              "Dans le cadre de l'utilisation de l'application, MaFortune peut collecter les informations suivantes :\n"
              "• nom et prénom ;\n"
              "• adresse courriel ;\n"
              "• numéro de téléphone ;\n"
              "• photo de profil ;\n"
              "• type d'activité commerciale ;\n"
              "• données financières saisies (recettes, dépenses, catégories).\n\n"
              "4.2 Données collectées automatiquement\n"
              "Certaines informations sont collectées automatiquement :\n"
              "• adresse IP ;\n"
              "• identifiants d'appareil ;\n"
              "• type d'appareil et système d'exploitation ;\n"
              "• données de navigation ;\n"
              "• préférences linguistiques ;\n"
              "• fuseau horaire.\n\n"
              "4.3 Données provenant de tiers\n"
              "MaFortune peut recevoir certaines données via :\n"
              "• les plateformes de téléchargement (Google Play Store) ;\n"
              "• des fournisseurs de services techniques (hébergement, analytique, sécurité) ;\n"
              "• des services d'authentification tiers (Google Sign-In)."
            ),

            // 5. FINALITÉS DE LA COLLECTE
            _buildSection(
              "5. Finalités de la collecte",
              "Les renseignements personnels sont collectés afin de :\n"
              "• créer et gérer les comptes utilisateurs ;\n"
              "• permettre le suivi des recettes et dépenses ;\n"
              "• générer des rapports et bilans financiers ;\n"
              "• faciliter les communications avec le support ;\n"
              "• améliorer les fonctionnalités de l'application ;\n"
              "• assurer la sécurité de la plateforme ;\n"
              "• prévenir les fraudes et abus ;\n"
              "• respecter les obligations légales."
            ),

            // 6. LIMITATION DE RESPONSABILITÉ
            _buildSection(
              "6. Limitation de responsabilité",
              "Dans toute la mesure permise par la loi, MaFortune ne pourra être tenu responsable :\n"
              "• des pertes financières résultant d'une mauvaise utilisation de l'application ;\n"
              "• des dommages directs ou indirects ;\n"
              "• des erreurs de calcul ou d'affichage ;\n"
              "• des fraudes commises par des tiers ;\n"
              "• des décisions commerciales prises sur la base des données affichées.\n\n"
              "MaFortune agit uniquement en tant que fournisseur d'outil technologique de gestion."
            ),

            // 7. CONSERVATION DES DONNÉES
            _buildSection(
              "7. Conservation des données",
              "Les données sont conservées :\n"
              "• tant que le compte est actif ;\n"
              "• pendant une durée maximale de 24 mois pour les comptes inactifs ;\n"
              "• jusqu'à 5 ans pour les données liées à des litiges ou obligations légales.\n\n"
              "Après suppression du compte, les données sont définitivement effacées de nos serveurs sous un délai de 30 jours."
            ),

            // 8. PARTAGE DES RENSEIGNEMENTS
            _buildSection(
              "8. Partage des renseignements",
              "Les données ne sont jamais vendues.\n\n"
              "Elles peuvent être partagées avec :\n"
              "• les employés autorisés de MaFortune ;\n"
              "• les fournisseurs techniques (hébergement, analytique) ;\n"
              "• les autorités légales si requis par la loi."
            ),

            // 9. TRANSFERTS INTERNATIONAUX
            _buildSection(
              "9. Transferts internationaux",
              "Certains fournisseurs de services techniques peuvent être situés hors du Togo.\n\n"
              "MaFortune s'assure que des garanties adéquates sont mises en place pour protéger vos données conformément aux lois applicables en matière de protection des données personnelles."
            ),

            // 10. SÉCURITÉ DES DONNÉES
            _buildSection(
              "10. Sécurité des données",
              "MaFortune met en œuvre des mesures de sécurité raisonnables incluant :\n"
              "• le chiffrement des données sensibles ;\n"
              "• le contrôle d'accès aux informations personnelles ;\n"
              "• la surveillance des systèmes ;\n"
              "• la gestion des incidents de sécurité."
            ),

            // 11. DROITS DES UTILISATEURS
            _buildSection(
              "11. Droits des utilisateurs",
              "Les utilisateurs disposent notamment des droits suivants :\n"
              "• accès à leurs données personnelles ;\n"
              "• rectification des informations inexactes ;\n"
              "• suppression de leur compte et de leurs données ;\n"
              "• retrait du consentement ;\n"
              "• portabilité des données (lorsque applicable) ;\n"
              "• dépôt de plainte auprès des autorités compétentes en matière de protection des données."
            ),

            // 12. RESPONSABLE DE LA PROTECTION
            _buildSection(
              "12. Responsable de la protection des renseignements",
              "Pour toute question relative à la protection de vos données personnelles, vous pouvez contacter le responsable :\n\n"
              "Nom : Caden Ahadzi\n"
              "Fonction : Fondateur et Développeur\n"
              "Courriel : ahadzicaden7@gmail.com"
            ),

            // 13. MODIFICATIONS
            _buildSection(
              "13. Modifications",
              "La présente politique peut être modifiée à tout moment. Les utilisateurs seront informés des changements majeurs via une notification dans l'application. L'utilisation continue de l'application après modification constitue une acceptation des nouvelles conditions."
            ),

            // 14. CONTACT
            _buildSection(
              "14. Contact",
              "Pour toute question relative à la présente politique, vous pouvez nous contacter :"
            ),
            const SizedBox(height: 12),

            _buildContactItem(
              icon: Icons.email_outlined,
              text: "ahadzicaden7@gmail.com",
              url: "mailto:ahadzicaden7@gmail.com?subject=Question%20Politique%20de%20Confidentialite",
            ),
            const SizedBox(height: 12),
            _buildContactItem(
              icon: Icons.language_outlined,
              text: "www.mafortune.tg",
              url: "https://www.mafortune.tg",
            ),

            const SizedBox(height: 32),

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