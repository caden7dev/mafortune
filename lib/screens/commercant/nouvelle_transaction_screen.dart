import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';
import '../../widgets/custom_bottom_nav.dart';

class NouvelleTransactionScreen extends StatefulWidget {
  final bool isRecette;
  final TransactionModel? transactionToEdit;

  const NouvelleTransactionScreen({
    super.key,
    required this.isRecette,
    this.transactionToEdit,
  });

  @override
  State<NouvelleTransactionScreen> createState() => _NouvelleTransactionScreenState();
}

class _NouvelleTransactionScreenState extends State<NouvelleTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TransactionService _transactionService = TransactionService();

  // Contrôleurs
  final TextEditingController _montantController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _clientController = TextEditingController();

  // Variables
  bool _isRecette = true;
  DateTime _selectedDate = DateTime.now();
  String _selectedCategorieId = '';
  String _selectedCategorie = '';
  ModePaiement _selectedMode = ModePaiement.especes;
  bool _isLoading = false;
  bool _isEditMode = false;

  // Catégories
  final List<Map<String, dynamic>> _categoriesRecette = [
    {'id': 'ventes', 'label': 'Ventes', 'icon': '🛒'},
    {'id': 'services', 'label': 'Services', 'icon': '🔧'},
    {'id': 'autres', 'label': 'Autres', 'icon': '💼'},
  ];

  final List<Map<String, dynamic>> _categoriesDepense = [
    {'id': 'achats', 'label': 'Achats', 'icon': '📦'},
    {'id': 'loyer', 'label': 'Loyer', 'icon': '🏠'},
    {'id': 'salaires', 'label': 'Salaires', 'icon': '👨‍💼'},
    {'id': 'transport', 'label': 'Transport', 'icon': '🚗'},
    {'id': 'electricite', 'label': 'Électricité', 'icon': '💡'},
    {'id': 'autres', 'label': 'Autres', 'icon': '📊'},
  ];

  @override
  void initState() {
    super.initState();
    _isRecette = widget.isRecette;
    _isEditMode = widget.transactionToEdit != null;

    if (_isEditMode) {
      final t = widget.transactionToEdit!;
      _montantController.text = _formatMontant(t.montant.toStringAsFixed(0));
      _descriptionController.text = t.description ?? '';
      _selectedDate = t.date;
      _selectedCategorieId = t.categorieId;
      _selectedCategorie = t.categorie;
      _selectedMode = t.modePaiement ?? ModePaiement.especes;
    } else {
      final categories = _isRecette ? _categoriesRecette : _categoriesDepense;
      if (categories.isNotEmpty) {
        _selectedCategorieId = categories[0]['id'] as String;
        _selectedCategorie = categories[0]['label'] as String;
      }
    }
  }

  @override
  void dispose() {
    _montantController.dispose();
    _descriptionController.dispose();
    _clientController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  String _formatMontant(String text) {
    if (text.isEmpty) return '';
    final value = text.replaceAll(' ', '');
    return value.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }

  Future<void> _enregistrer() async {
  if (!_formKey.currentState!.validate()) return;

  if (_selectedCategorieId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Veuillez sélectionner une catégorie')),
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    final user = await _authService.getCurrentUserData();
    if (user == null) throw Exception('Utilisateur non connecté');

    final montant =
        double.parse(_montantController.text.replaceAll(' ', ''));

    if (_isEditMode) {
      final updated = widget.transactionToEdit!.copyWith(
        montant: montant,
        categorieId: _selectedCategorieId,
        categorie: _selectedCategorie,
        description: _descriptionController.text.trim(),
        date: _selectedDate,
        modePaiement: _selectedMode,
        dateModification: DateTime.now(),
      );

      // ✅ On lance l'opération sans attendre la réponse serveur
      _transactionService.updateTransaction(updated).catchError((e) {
        debugPrint('Sync en attente: $e');
      });
    } else {
      final transaction = TransactionModel(
        id: '',
        commercantId: user.id,
        categorieId: _selectedCategorieId,
        montant: montant,
        type:
            _isRecette ? TypeTransaction.recette : TypeTransaction.depense,
        description: _descriptionController.text.trim(),
        date: _selectedDate,
        dateCreation: DateTime.now(),
        modePaiement: _selectedMode,
        categorie: _selectedCategorie,
      );

      // ✅ On lance l'opération sans attendre la réponse serveur
      _transactionService.addTransaction(transaction).catchError((e) {
        debugPrint('Sync en attente: $e');
      });
    }

    // ✅ On ferme l'écran immédiatement — pas besoin d'attendre Firebase
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? '✅ Modification enregistrée'
                : '✅ Transaction enregistrée',
          ),
          backgroundColor: _isRecette
              ? AppColors.primaryGreen
              : AppColors.expenseRed,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, true);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }
}
  @override
  Widget build(BuildContext context) {
    final categories = _isRecette ? _categoriesRecette : _categoriesDepense;
    final primaryColor = _isRecette ? AppColors.primaryGreen : AppColors.expenseRed;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // 🎨 APP BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isRecette
                      ? [const Color(0xFF2E7D32), const Color(0xFF43A047)]
                      : [const Color(0xFFD32F2F), const Color(0xFFF44336)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      _isEditMode ? 'Modifier Transaction' : 'Nouvelle Transaction',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 📝 FORMULAIRE
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔄 TYPE SELECTOR (désactivé en mode édition)
                      if (!_isEditMode)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTypeButton(
                                label: '📈 Recette',
                                isSelected: _isRecette,
                                onTap: () => setState(() {
                                  _isRecette = true;
                                  _selectedCategorieId = _categoriesRecette[0]['id'] as String;
                                  _selectedCategorie = _categoriesRecette[0]['label'] as String;
                                }),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTypeButton(
                                label: '📉 Dépense',
                                isSelected: !_isRecette,
                                onTap: () => setState(() {
                                  _isRecette = false;
                                  _selectedCategorieId = _categoriesDepense[0]['id'] as String;
                                  _selectedCategorie = _categoriesDepense[0]['label'] as String;
                                }),
                              ),
                            ),
                          ],
                        ),

                      if (!_isEditMode) const SizedBox(height: 20),

                      // 💰 MONTANT
                      _buildLabel('Montant', required: true),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
                        ),
                        child: TextFormField(
                          controller: _montantController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: TextStyle(color: Colors.grey[300]),
                            suffixText: 'FCFA',
                            suffixStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF999999),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(15),
                          ),
                          onChanged: (value) {
                            final formatted = _formatMontant(value);
                            if (formatted != value) {
                              _montantController.value = TextEditingValue(
                                text: formatted,
                                selection: TextSelection.collapsed(offset: formatted.length),
                              );
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Montant requis';
                            }
                            final montant = double.tryParse(value.replaceAll(' ', ''));
                            if (montant == null || montant <= 0) {
                              return 'Montant invalide';
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 🏷️ CATÉGORIE
                      _buildLabel('Catégorie', required: true),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final isSelected = _selectedCategorieId == category['id'];

                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedCategorieId = category['id'] as String;
                              _selectedCategorie = category['label'] as String;
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (_isRecette ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE))
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? primaryColor : const Color(0xFFE0E0E0),
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    category['icon'] as String,
                                    style: const TextStyle(fontSize: 30),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    category['label'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: isSelected ? primaryColor : Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // 📝 DESCRIPTION
                      _buildLabel('Description'),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
                        ),
                        child: TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            hintText: 'Ex: Achat de produit',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(15),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Description requise';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Optionnel - Ajoutez des détails sur cette transaction',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 📅 DATE
                      _buildLabel('Date', required: true),
                      InkWell(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
                          ),
                          child: Row(
                            children: [
                              Text(
                                DateFormat('yyyy-MM-dd').format(_selectedDate),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 💳 MODE DE PAIEMENT
                      _buildLabel('Mode de paiement'),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
                        ),
                        child: DropdownButtonFormField<ModePaiement>(
                          value: _selectedMode,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                          items: const [
                            DropdownMenuItem(value: ModePaiement.especes, child: Text('Espèces')),
                            DropdownMenuItem(value: ModePaiement.mobileMoney, child: Text('Mobile Money')),
                            DropdownMenuItem(value: ModePaiement.carte, child: Text('Carte bancaire')),
                            DropdownMenuItem(value: ModePaiement.cheque, child: Text('Chèque')),
                          ],
                          onChanged: (value) => setState(() => _selectedMode = value!),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 📸 PHOTO (uniquement en mode création)
                      if (!_isEditMode) ...[
                        _buildLabel('Photo du reçu'),
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('📸 Fonctionnalité photo à venir')),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE0E0E0),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text('📸', style: TextStyle(fontSize: 48)),
                                const SizedBox(height: 10),
                                const Text(
                                  'Ajouter une photo',
                                  style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Appuyez pour prendre une photo',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 💾 BOUTON ENREGISTRER/MODIFIER
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _enregistrer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  _isEditMode
                                      ? '💾 Enregistrer les modifications'
                                      : '💾 Enregistrer ${_isRecette ? "la recette" : "la dépense"}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      
      // ✅ Utilisation du CustomBottomNav avec badge dynamique
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 0,
        onTap: (index) {
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildTypeButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSelected
              ? (_isRecette ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE))
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (_isRecette ? AppColors.primaryGreen : AppColors.expenseRed)
                : const Color(0xFFE0E0E0),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? (_isRecette ? AppColors.primaryGreen : AppColors.expenseRed)
                  : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
          children: required
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: Color(0xFFD32F2F)),
                  ),
                ]
              : [],
        ),
      ),
    );
  }
}