import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

// 🎨 CHARTE GRAPHIQUE
const Color emeraldDark = Color(0xFF0B4F36);
const Color terracotta = Color(0xFFD96B43);
const Color textDark = Color(0xFF222222);

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  ChatMessage({required this.text, required this.isUser, DateTime? time}) : time = time ?? DateTime.now();
}

class ChatbotSupportScreen extends StatefulWidget {
  const ChatbotSupportScreen({super.key});

  @override
  State<ChatbotSupportScreen> createState() => _ChatbotSupportScreenState();
}

class _ChatbotSupportScreenState extends State<ChatbotSupportScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  late final GenerativeModel _model;
  late final ChatSession _chatSession;

  @override
  void initState() {
    super.initState();
    
    // ️ REMPLACE CECI PAR TA VRAIE CLÉ API GOOGLE
    const String apiKey = 'TA_CLE_API_ICI'; 

    _model = GenerativeModel(
      model: 'gemini-1.5-flash-latest', 
      apiKey: apiKey,
      // ✅ ANTI-SÈCHE ULTRA-COMPLÈTE : L'IA connaît TOUTES les fonctionnalités
      systemInstruction: Content.system('''
        Tu es le Chatbot officiel de l'application "MaFortune", une application de gestion financière pour les commerçants au Togo.
        
        BASE DE CONNAISSANCES COMPLÈTE DE L'APPLICATION :
        
        1. VENTES & DÉPENSES :
           - Bouton '+' en bas de l'écran d'accueil pour ajouter.
           - Choix entre "J'ai VENDU" et "J'ai DÉPENSÉ".
           - Mode produits (sélection rapide) ou montant libre.
           - Moyens de paiement : Espèces, Flooz, Mixx by Yas, Virement.
           - Possibilité d'ajouter une quantité et une description.
        
        2. PRODUITS & SERVICES :
           - Onglet Profil > Mes produits & services.
           - Ajouter, modifier le prix, supprimer un produit.
           - Associer un emoji et une catégorie à chaque produit.
           - Les produits apparaissent en saisie rapide.
        
        3. RAPPORTS, BILANS & IMPRESSION :
           - Onglets "Bilans" et "Rapports" en bas de l'écran.
           - Vue mensuelle, trimestrielle, annuelle.
           - Bouton de partage/export en haut pour générer un PDF.
           - Possibilité d'imprimer ou d'envoyer par WhatsApp/Email.
        
        4. COMPTE & SÉCURITÉ :
           - Connexion par numéro de téléphone ou Google.
           - Code PIN à 4 chiffres pour sécuriser l'accès.
           - Profil > Changer le code PIN / Mot de passe.
           - Profil > Lier un compte (email ou Google).
           - Suppression de compte : Profil > Supprimer mon compte (délai de grâce 30 jours).
        
        5. QR CODE :
           - Profil > Mon QR Code.
           - Basculer entre "Mon Code" et "Scanner" en haut.
           - Permet de partager ses coordonnées ou d'ajouter un contact.
        
        6. MODE HORS-LIGNE :
           - L'application fonctionne 100% sans internet.
           - Synchronisation automatique dès que le réseau revient.
           - Toutes les données sont sauvegardées localement.
        
        7. NOTIFICATIONS & ALERTES :
           - Profil > Notifications pour configurer les alertes.
           - Alertes de budget dépassé, rappels de saisie.
        
        8. BUDGET MENSUEL :
           - Profil > Budget mensuel.
           - Définir un plafond de dépenses par mois.
           - Suivi visuel de la consommation.
        
        9. CATÉGORIES PERSONNALISÉES :
           - Profil > Mes catégories.
           - Créer, modifier, supprimer des catégories de dépenses/recettes.
        
        10. PROFIL & PERSONNALISATION :
            - Photo de profil modifiable (clic sur l'icône appareil photo).
            - Thème clair/sombre : Profil > Thème.
            - Modifier ses informations personnelles.
        
        11. SUPPORT & AIDE :
            - Cette page de chatbot pour les questions fréquentes.
            - Profil > Messagerie Admin pour contacter le support humain.
            - Profil > Aide & Support pour la FAQ complète.
        
        RÈGLES STRICTES :
        1. Utilise cette base de connaissances pour répondre PRÉCISÉMENT.
        2. Sois concis, utile, professionnel et utilise des émojis pertinents.
        3. Si la question est hors sujet, politique, religieuse ou illégale, réponds EXACTEMENT : "Je suis désolé, je suis programmé pour répondre uniquement aux questions concernant l'utilisation de l'application MaFortune."
        4. Réponds toujours en français.
      '''),
    );

    _chatSession = _model.startChat();

    _addBotMessage("Bonjour !  Je suis le **Chatbot MaFortune**. \n\nPosez-moi n'importe quelle question sur l'application. Je connais toutes les fonctionnalités et suis là pour vous aider !");
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: false));
      _isTyping = false;
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isTyping = true;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;
    _controller.clear();
    HapticFeedback.lightImpact();

    _addUserMessage(text);

    try {
      final response = await _chatSession.sendMessage(Content.text(text));
      final reply = response.text;
      
      if (reply != null && reply.isNotEmpty) {
        _addBotMessage(reply);
      } else {
        throw Exception("Réponse vide");
      }

    } catch (e) {
      debugPrint('⚠️ IA indisponible, bascule sur le mode local: $e');
      final localResponse = _getLocalBotResponse(text.toLowerCase());
      _addBotMessage(localResponse);
    }
  }

  // 🛡️ SYSTÈME DE SECOURS LOCAL ULTRA-ENRICHI
  String _getLocalBotResponse(String query) {
    bool hasKeyword(List<String> keywords) {
      return keywords.any((keyword) => query.contains(keyword));
    }

    // 1. Salutations
    if (hasKeyword(['bonjour', 'salut', 'hello', 'coucou', 'slt', 'cc', 'hey', 'bonsoir'])) {
      return "Bonjour ! 👋 Comment puis-je vous aider avec MaFortune aujourd'hui ?";
    }

    // 2. Remerciements
    if (hasKeyword(['merci', 'thanks', 'super', 'parfait', 'génial', 'ok', 'daccord', 'daccord'])) {
      return "Avec plaisir ! 😊 N'hésitez pas si vous avez d'autres questions.";
    }

    // 3. Présentation de l'app
    if (hasKeyword(['c\'est quoi', 'c est quoi', 'mafortune', 'application', 'app', 'présentation', 'presentation'])) {
      return "📱 **MaFortune** est une application de gestion financière conçue pour les commerçants au Togo. Elle vous permet de :\n• Suivre vos ventes et dépenses\n• Gérer vos produits\n• Générer des rapports PDF\n• Fonctionner hors-ligne\n• Sécuriser vos données avec un code PIN";
    }

    // 4. Ventes
    if (hasKeyword(['vente', 'vendre', 'vendu', 'recette', 'encaisser', 'gagner', 'ajouter une vente', 'saisir vente', 'client'])) {
      return "✅ **Pour ajouter une vente :**\n1. Appuyez sur le gros bouton **'+'** en bas de l'écran d'accueil.\n2. Choisissez 'J'ai VENDU'.\n3. Sélectionnez vos produits ou entrez un montant libre.\n4. Choisissez le moyen de paiement (Espèces, Flooz, Mixx, Virement).\n5. Validez !";
    }

    // 5. Dépenses
    if (hasKeyword(['dépense', 'depense', 'dépenser', 'sortie', 'payer', 'achat', 'ajouter une dépense', 'facture'])) {
      return "✅ **Pour ajouter une dépense :**\n1. Appuyez sur le gros bouton **'+'** en bas de l'écran d'accueil.\n2. Choisissez 'J'ai DÉPENSÉ'.\n3. Sélectionnez une catégorie (Loyer, Transport, Électricité, etc.).\n4. Entrez le montant et validez.";
    }

    // 6. Moyens de paiement
    if (hasKeyword(['flooz', 'mixx', 'virement', 'espèces', 'especes', 'mobile money', 'paiement', 'payer'])) {
      return "💳 **Moyens de paiement acceptés :**\n• 💵 Espèces\n• 🟠 Flooz (Togo Telecom)\n• 🟡 Mixx by Yas\n• 🏦 Virement bancaire\n\nVous pouvez choisir le moyen lors de chaque saisie de transaction.";
    }

    // 7. Produits & Stock
    if (hasKeyword(['produit', 'article', 'stock', 'inventaire', 'prix', 'service', 'catalogue', 'ajouter un produit'])) {
      return "📦 **Gérer vos produits :**\n1. Allez dans **Profil** ➔ **Mes produits & services**.\n2. Cliquez sur le bouton '+' pour ajouter un produit.\n3. Renseignez le nom, le prix, l'emoji et la catégorie.\n4. Ils apparaîtront automatiquement en saisie rapide !";
    }

    // 8. Catégories
    if (hasKeyword(['catégorie', 'categorie', 'catégories', 'categories', 'personnaliser'])) {
      return "🏷️ **Catégories personnalisées :**\nAllez dans **Profil** ➔ **Mes catégories**. Vous pouvez créer, modifier ou supprimer des catégories de dépenses et recettes pour mieux organiser vos transactions.";
    }

    // 9. Rapports, Bilans, Impression, PDF
    if (hasKeyword(['imprimer', 'pdf', 'exporter', 'télécharger', 'telecharger', 'rapport', 'bilan', 'document', 'partager', 'whatsapp', 'email', 'statistique', 'graphique'])) {
      return " **Rapports et Impression :**\n1. Allez dans l'onglet **Rapports** ou **Bilans** en bas de l'écran.\n2. Choisissez la période (mois, trimestre, année).\n3. Appuyez sur l'icône de **partage/export** en haut à droite.\n4. Vous pouvez générer un PDF et l'envoyer par WhatsApp, Email ou l'imprimer.";
    }

    // 10. Budget
    if (hasKeyword(['budget', 'plafond', 'limite', 'dépense mensuelle', 'depense mensuelle'])) {
      return " **Budget mensuel :**\nAllez dans **Profil** ➔ **Budget mensuel**. Vous pouvez définir un plafond de dépenses. L'application vous alertera quand vous approcherez de la limite !";
    }

    // 11. Notifications / Alertes
    if (hasKeyword(['notification', 'alerte', 'rappel', 'avertissement', 'son'])) {
      return "🔔 **Notifications :**\nAllez dans **Profil** ➔ **Notifications**. Vous pouvez activer/désactiver les alertes de budget, les rappels de saisie, etc.";
    }

    // 12. Mot de passe / PIN / Connexion
    if (hasKeyword(['mot de passe', 'password', 'pin', 'code', 'oublié', 'perdu', 'changer', 'modifier', 'connexion', 'connecter', 'login', 'sécurité', 'securite'])) {
      if (hasKeyword(['oublié', 'perdu', 'bloqué'])) {
        return "🔒 **Mot de passe ou PIN oublié :**\n• Sur l'écran de connexion : utilisez 'Mot de passe oublié'.\n• Si vous êtes connecté : **Profil**  **Changer le code PIN**.";
      }
      if (hasKeyword(['changer', 'modifier'])) {
        return "️ **Changer ses identifiants :**\nAllez dans **Profil**, puis choisissez :\n• 'Changer le code PIN'\n• 'Changer le mot de passe'";
      }
      return "🔐 **Sécurité :**\nVotre compte est protégé par un code PIN à 4 chiffres. Allez dans **Profil** pour le modifier ou lier un compte Google/email.";
    }

    // 13. Compte Google / Email
    if (hasKeyword(['google', 'gmail', 'email', 'lier', 'associer'])) {
      return " **Lier un compte Google ou Email :**\nAllez dans **Profil** ➔ **Lier un compte**. Vous pourrez ajouter un email ou un compte Google pour sécuriser votre accès et récupérer votre compte facilement.";
    }

    // 14. Photo de profil
    if (hasKeyword(['photo', 'avatar', 'image profil', 'picture'])) {
      return "📸 **Photo de profil :**\nSur la page **Profil**, appuyez sur la petite icône d'appareil photo en bas à droite de votre avatar pour choisir une nouvelle photo depuis votre galerie.";
    }

    // 15. Thème (sombre/clair)
    if (hasKeyword(['thème', 'theme', 'sombre', 'noir', 'clair', 'blanc', 'apparence', 'couleur'])) {
      return "🎨 **Changer le thème :**\nAllez dans **Profil**  **Thème**. Vous pouvez basculer entre le mode clair et le mode sombre selon votre préférence.";
    }

    // 16. QR Code
    if (hasKeyword(['qr', 'scanner', 'code qr', 'partager', 'flasher', 'contact'])) {
      return " **QR Code :**\nAllez dans **Profil** ➔ **Mon QR Code**. En haut, basculez entre :\n• 'Mon Code' : pour le montrer et partager vos coordonnées.\n• 'Scanner' : pour scanner le code de quelqu'un d'autre.";
    }

    // 17. Mode Hors-ligne
    if (hasKeyword(['internet', 'réseau', 'hors ligne', 'offline', 'wifi', 'data', 'sans connexion', 'coupure', 'marche sans'])) {
      return "📴 **Mode Hors-ligne :**\nMaFortune fonctionne **100% hors-ligne** ! Vous pouvez saisir toutes vos ventes et dépenses sans internet. L'application synchronisera automatiquement vos données dès que vous retrouverez du réseau.";
    }

    // 18. Modifier/Supprimer une transaction
    if (hasKeyword(['modifier', 'corriger', 'changer', 'transaction', 'erreur', 'supprimer une transaction', 'enlever'])) {
      return "✏️ **Modifier ou supprimer une transaction :**\nSur l'écran d'accueil, dans la liste de vos transactions récentes, appuyez sur la transaction concernée. Vous aurez les options 'Modifier' et 'Supprimer'.";
    }

    // 19. Suppression de compte
    if (hasKeyword(['supprimer', 'effacer', 'désinstaller', 'fermer', 'quitter', 'delete', 'suppression', 'désactiver', 'desactiver'])) {
      return "⚠️ **Supprimer le compte :**\nAllez dans **Profil** ➔ Tout en bas ➔ **Supprimer mon compte**.\n\n📌 Important : vous aurez un **délai de grâce de 30 jours** pour annuler cette demande avant l'effacement définitif de vos données.";
    }

    // 20. Solde / Finances
    if (hasKeyword(['solde', 'combien', 'total', 'gain', 'bénéfice', 'benefice', 'argent', 'revenu'])) {
      return "💰 **Consulter vos finances :**\n• Votre **solde actuel** s'affiche en haut du **Tableau de bord**.\n• L'onglet **Bilans** montre vos gains et dépenses.\n• L'onglet **Rapports** offre des statistiques détaillées.";
    }

    // 21. Sauvegarde des données
    if (hasKeyword(['sauvegarde', 'sauvegarder', 'backup', 'perdre', 'perte', 'données', 'donnees'])) {
      return " **Sauvegarde des données :**\nVos données sont automatiquement sauvegardées dans le cloud Firebase dès que vous avez internet. En hors-ligne, elles sont stockées localement sur votre téléphone. Vous ne perdrez rien !";
    }

    // 22. Support / Contacter l'admin
    if (hasKeyword(['support', 'contacter', 'admin', 'humain', 'agent', 'problème', 'probleme', 'bug', 'erreur', 'aide'])) {
      return "📞 **Contacter le support :**\n• **Messagerie Admin** : Profil ➔ Messagerie Admin (pour discuter directement).\n• **Email** : support@mafortune.tg\n• **Téléphone** : +228 90 00 00 00\n• **Site web** : www.mafortune.tg";
    }

    // 23. Prix / Abonnement
    if (hasKeyword(['prix', 'gratuit', 'payer', 'abonnement', 'combien coûte', 'cout', 'tarif'])) {
      return "💸 **Tarification :**\nMaFortune est **gratuite** ! Vous pouvez utiliser toutes les fonctionnalités de base sans payer. Des fonctionnalités premium pourront être ajoutées à l'avenir.";
    }

    // 24. Mise à jour
    if (hasKeyword(['mise à jour', 'mise a jour', 'update', 'nouvelle version', 'version'])) {
      return "🔄 **Mise à jour :**\nPour bénéficier des dernières fonctionnalités, allez sur le **Google Play Store**, cherchez 'MaFortune' et appuyez sur 'Mettre à jour' si disponible.";
    }

    // 25. Langues
    if (hasKeyword(['langue', 'français', 'anglais', 'language', 'traduction'])) {
      return " **Langues :**\nMaFortune est actuellement disponible en **français**. D'autres langues (anglais, langues locales) seront ajoutées prochainement !";
    }

    // 26. Multi-comptes
    if (hasKeyword(['plusieurs comptes', 'multi', 'switch', 'changer de compte'])) {
      return "🔄 **Changer de compte :**\nAllez dans **Profil** ➔ **Changer de compte**. Vous pourrez vous déconnecter et vous connecter avec un autre numéro ou compte Google.";
    }

    // 27. Fallback ultra-utile
    return "Je n'ai pas bien compris votre question. 🤔\n\n💡 **Voici ce que je peux vous expliquer :**\n• Ajouter une vente ou dépense\n• Gérer vos produits et catégories\n• Imprimer un rapport PDF\n• Changer votre code PIN\n• Utiliser le mode hors-ligne\n• Configurer votre budget\n• Utiliser le QR Code\n\n📞 Pour toute autre question, contactez le support via **Profil ➔ Messagerie Admin**.";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Chatbot MaFortune', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: emeraldDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          if (_isTyping)
            Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: emeraldDark, shape: BoxShape.circle),
                    child: const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('Le Chatbot réfléchit...', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Posez votre question...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.grey),
                        ),
                        onSubmitted: _handleSubmitted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _handleSubmitted(_controller.text),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: emeraldDark,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: emeraldDark, shape: BoxShape.circle),
              child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? emeraldDark : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: isUser ? Colors.white : textDark,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}