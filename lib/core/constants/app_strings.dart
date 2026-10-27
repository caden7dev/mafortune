/// Chaînes de caractères de l'application MaFortune
class AppStrings {
  // Informations de l'application
  static const String appName = 'MaFortune';
  static const String appTagline = 'Gérez vos finances simplement\net développez votre activité';
  static const String appVersion = '1.0.0';
  
  // Écran Welcome
  static const String welcomeTitle = 'Bienvenue sur MaFortune';
  static const String welcomeSubtitle = 'Votre assistant de gestion financière';
  static const String welcomeFeature1 = 'Suivez vos recettes et dépenses';
  static const String welcomeFeature2 = 'Bilans financiers automatiques';
  static const String welcomeFeature3 = '100% mobile et hors-ligne';
  static const String welcomeCreateAccount = 'Créer un compte';
  static const String welcomeLogin = 'Se connecter';
  static const String welcomeFooter = 'Fait pour les commerçants du Togo 🇹🇬';
  
  // Écran Login
  static const String loginTitle = 'Bon retour !';
  static const String loginSubtitle = 'Connectez-vous pour continuer';
  static const String loginEmail = 'Email';
  static const String loginPassword = 'Mot de passe';
  static const String loginForgotPassword = 'Mot de passe oublié ?';
  static const String loginButton = 'Se connecter';
  static const String loginNoAccount = 'Vous n\'avez pas de compte ?';
  static const String loginSignup = 'Créer un compte gratuitement';
  static const String loginErrorInvalid = 'Email ou mot de passe incorrect';
  
  // Écran Signup
  static const String signupTitle = 'Créer un compte';
  static const String signupSubtitle = 'Rejoignez MaFortune gratuitement';
  static const String signupFirstName = 'Prénom';
  static const String signupLastName = 'Nom';
  static const String signupEmail = 'Email';
  static const String signupPhone = 'Téléphone';
  static const String signupActivity = 'Type d\'activité';
  static const String signupPassword = 'Mot de passe';
  static const String signupConfirmPassword = 'Confirmer le mot de passe';
  static const String signupTerms = 'J\'accepte les Conditions d\'utilisation et la Politique de confidentialité de MaFortune';
  static const String signupButton = 'Créer mon compte';
  static const String signupHaveAccount = 'Vous avez déjà un compte ?';
  static const String signupLogin = 'Se connecter';
  
  // Dashboard Commerçant
  static const String dashboardTitle = 'Tableau de bord';
  static const String dashboardBalance = 'Solde actuel';
  static const String dashboardTodayIncome = 'Recettes aujourd\'hui';
  static const String dashboardTodayExpense = 'Dépenses aujourd\'hui';
  static const String dashboardNewIncome = 'Nouvelle Recette';
  static const String dashboardNewExpense = 'Nouvelle Dépense';
  static const String dashboardEvolution = 'Évolution (7 derniers jours)';
  static const String dashboardRecentTransactions = 'Transactions récentes';
  static const String dashboardSeeAll = 'Voir tout';
  
  // Navigation
  static const String navHome = 'Accueil';
  static const String navBilans = 'Bilans';
  static const String navReports = 'Rapports';
  static const String navHistory = 'Historique';
  static const String navAlerts = 'Alertes';
  static const String navProfile = 'Profil';
  static const String navUsers = 'Utilisateurs';
  static const String navStats = 'Stats';
  static const String navSettings = 'Réglages';
  
  // Transactions
  static const String transactionTypeIncome = 'Recette';
  static const String transactionTypeExpense = 'Dépense';
  static const String transactionAmount = 'Montant';
  static const String transactionCategory = 'Catégorie';
  static const String transactionDescription = 'Description';
  static const String transactionDate = 'Date';
  static const String transactionPhoto = 'Photo du reçu';
  static const String transactionSave = 'Enregistrer';
  static const String transactionSuccessSaved = 'Transaction enregistrée';
  
  // Catégories
  static const String categoryProductSales = 'Vente de produits';
  static const String categoryServices = 'Prestations de services';
  static const String categoryOtherIncome = 'Autres recettes';
  static const String categoryPurchases = 'Achat de marchandises';
  static const String categoryTransport = 'Transport';
  static const String categoryRent = 'Loyer';
  static const String categoryElectricity = 'Électricité/Eau';
  static const String categorySalaries = 'Salaires';
  static const String categoryOtherExpense = 'Autres dépenses';
  
  // Bilans
  static const String bilanTitle = 'Bilans Financiers';
  static const String bilanDaily = 'Quotidien';
  static const String bilanWeekly = 'Hebdomadaire';
  static const String bilanMonthly = 'Mensuel';
  static const String bilanYearly = 'Annuel';
  static const String bilanCustom = 'Personnalisé';
  static const String bilanNetProfit = 'Bénéfice net';
  static const String bilanTotalIncome = 'Recettes totales';
  static const String bilanTotalExpense = 'Dépenses totales';
  static const String bilanCompare = 'Comparer';
  static const String bilanExport = 'Exporter';
  
  // Profil
  static const String profileTitle = 'Profil';
  static const String profilePersonalInfo = 'Informations personnelles';
  static const String profileActivity = 'Mon activité';
  static const String profileSecurity = 'Sécurité';
  static const String profileNotifications = 'Notifications';
  static const String profileDarkMode = 'Mode sombre';
  static const String profileLanguage = 'Langue';
  static const String profileCurrency = 'Devise';
  static const String profileHelp = 'Centre d\'aide';
  static const String profileContact = 'Contactez-nous';
  static const String profileLogout = 'Se déconnecter';
  
  // Admin
  static const String adminDashboard = 'Tableau de bord Admin';
  static const String adminUsers = 'Utilisateurs';
  static const String adminActiveUsers = 'Utilisateurs actifs';
  static const String adminTotalVolume = 'Volume total';
  static const String adminTransactions = 'Transactions';
  static const String adminQuickActions = 'Actions rapides';
  static const String adminRecentActivity = 'Activité récente';
  
  // Messages
  static const String msgLoading = 'Chargement...';
  static const String msgError = 'Une erreur est survenue';
  static const String msgSuccess = 'Opération réussie';
  static const String msgNoData = 'Aucune donnée disponible';
  static const String msgNoInternet = 'Pas de connexion Internet';
  static const String msgSyncLater = 'Sera synchronisé à la connexion';
  
  // Validations
  static const String validationRequired = 'Ce champ est requis';
  static const String validationEmailInvalid = 'Email invalide';
  static const String validationPasswordShort = 'Au moins 8 caractères';
  static const String validationPasswordMismatch = 'Les mots de passe ne correspondent pas';
  static const String validationPhoneInvalid = 'Numéro de téléphone invalide';
  
  // Boutons
  static const String btnSave = 'Enregistrer';
  static const String btnCancel = 'Annuler';
  static const String btnDelete = 'Supprimer';
  static const String btnEdit = 'Modifier';
  static const String btnConfirm = 'Confirmer';
  static const String btnClose = 'Fermer';
  static const String btnNext = 'Suivant';
  static const String btnPrevious = 'Précédent';
  
  // Devise
  static const String currency = 'FCFA';
}