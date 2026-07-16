import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../models/utilisateur_model.dart';

class ModifierProfilScreen extends StatefulWidget {
  final UtilisateurModel currentUser;

  const ModifierProfilScreen({super.key, required this.currentUser});

  @override
  State<ModifierProfilScreen> createState() => _ModifierProfilScreenState();
}

class _ModifierProfilScreenState extends State<ModifierProfilScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  late TextEditingController _nomController;
  late TextEditingController _prenomController;
  late TextEditingController _telephoneController;
  late TextEditingController _adresseController;
  late TextEditingController _typeActiviteController;

  XFile? _selectedImage;
  bool _isLoading = false;
  bool _isUploading = false;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.currentUser.nom);
    _prenomController = TextEditingController(text: widget.currentUser.prenom);
    _telephoneController =
        TextEditingController(text: widget.currentUser.telephone);
    _adresseController =
        TextEditingController(text: widget.currentUser.adresse ?? '');
    _typeActiviteController =
        TextEditingController(text: widget.currentUser.typeActivite ?? '');
    _profileImageUrl = widget.currentUser.photo;
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _telephoneController.dispose();
    _adresseController.dispose();
    _typeActiviteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 60,
      );
      if (pickedFile != null) {
        setState(() => _selectedImage = pickedFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e', style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '📸 Choisir une photo',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Prendre une photo
              _buildSheetOption(
                emoji: '📷',
                label: 'Prendre une photo',
                color: AppColors.primaryGreen,
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 12),

              // Galerie
              _buildSheetOption(
                emoji: '🖼️',
                label: 'Choisir dans la galerie',
                color: AppColors.primaryGreen,
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),

              // Supprimer
              if (_profileImageUrl != null || _selectedImage != null) ...[
                const SizedBox(height: 12),
                _buildSheetOption(
                  emoji: '🗑️',
                  label: 'Supprimer la photo',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _deleteImage();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetOption({
    required String emoji,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 18),
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteImage() async {
    setState(() => _isUploading = true);
    try {
      if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
        final fileName = 'profile_${widget.currentUser.id}.jpg';
        try {
          await _storage.ref().child('profile_photos/$fileName').delete();
        } catch (_) {}
      }
      setState(() {
        _selectedImage = null;
        _profileImageUrl = null;
      });
      final updatedUser = widget.currentUser.copyWith(photo: null);
      await _authService.updateUserProfile(updatedUser);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo supprimée', style: TextStyle(fontSize: 16)),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e', style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;
    setState(() => _isUploading = true);
    try {
      final fileName = 'profile_${widget.currentUser.id}.jpg';
      final ref = _storage.ref().child('profile_photos/$fileName');
      final bytes = await _selectedImage!.readAsBytes();
      await ref.putData(bytes);
      return await ref.getDownloadURL();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur upload: $e', style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      String? newPhotoUrl = _profileImageUrl;
      if (_selectedImage != null) {
        final uploaded = await _uploadImage();
        if (uploaded != null) newPhotoUrl = uploaded;
      }

      final updatedUser = widget.currentUser.copyWith(
        nom: _nomController.text.trim(),
        prenom: _prenomController.text.trim(),
        telephone: _telephoneController.text.trim(),
        adresse: _adresseController.text.trim().isEmpty
            ? null
            : _adresseController.text.trim(),
        typeActivite: _typeActiviteController.text.trim().isEmpty
            ? null
            : _typeActiviteController.text.trim(),
        photo: newPhotoUrl,
      );

      await _authService.updateUserProfile(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profil mis à jour', style: TextStyle(fontSize: 16)),
            backgroundColor: AppColors.primaryGreen,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e', style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── BUILD PRINCIPAL ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '✏️ Modifier mon profil',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isLoading || _isUploading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
          children: [
            // ── Photo de profil ──────────────────────────────────────────────
            _buildPhotoSection(),

            const SizedBox(height: 28),

            // ── Champs éditables ─────────────────────────────────────────────
            _buildSectionTitle('👤', 'Mes informations'),
            const SizedBox(height: 14),
            _buildFieldCard([
              _buildField(
                controller: _nomController,
                emoji: '🪪',
                label: 'Nom',
                required: true,
              ),
              _buildField(
                controller: _prenomController,
                emoji: '✍️',
                label: 'Prénom',
                required: true,
              ),
              _buildField(
                controller: _telephoneController,
                emoji: '📱',
                label: 'Téléphone',
                keyboardType: TextInputType.phone,
                required: true,
              ),
              _buildField(
                controller: _adresseController,
                emoji: '📍',
                label: 'Adresse',
                required: false,
              ),
              _buildField(
                controller: _typeActiviteController,
                emoji: '🏪',
                label: 'Type d\'activité',
                required: false,
                isLast: true,
              ),
            ]),

            const SizedBox(height: 24),

            // ── Infos fixes ──────────────────────────────────────────────────
            _buildSectionTitle('ℹ️', 'Informations fixes'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildInfoRow('📧', 'Email', widget.currentUser.email),
                  const SizedBox(height: 14),
                  _buildInfoRow(
                    '📅',
                    'Membre depuis',
                    _formatDate(widget.currentUser.dateCreation),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Boutons action ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 62,
              child: ElevatedButton(
                onPressed: (_isLoading || _isUploading) ? null : _enregistrer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primaryGreen.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('💾', style: TextStyle(fontSize: 22)),
                          SizedBox(width: 10),
                          Text(
                            'Enregistrer',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed:
                    _isLoading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Annuler',
                    style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SECTION PHOTO ───────────────────────────────────────────────────────────
  Widget _buildPhotoSection() {
    return Center(
      child: Column(
        children: [
          // Avatar cliquable
          GestureDetector(
            onTap: (_isUploading || _isLoading) ? null : _showImagePickerSheet,
            child: Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: AppColors.primaryGreen, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(child: _buildProfileImage()),
                ),

                // Badge caméra
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: _isUploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('📷',
                              style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Lien texte
          TextButton(
            onPressed:
                (_isUploading || _isLoading) ? null : _showImagePickerSheet,
            child: const Text(
              'Changer la photo',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TITRE SECTION ───────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String emoji, String title) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ],
    );
  }

  // ─── CARD AVEC PLUSIEURS CHAMPS ──────────────────────────────────────────────
  Widget _buildFieldCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  // ─── CHAMP INDIVIDUEL ────────────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String emoji,
    required String label,
    TextInputType? keyboardType,
    bool required = true,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            enabled: !_isLoading,
            style: const TextStyle(fontSize: 17, color: Colors.black87),
            decoration: InputDecoration(
              labelText: '$emoji  $label${required ? '' : ' (optionnel)'}',
              labelStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primaryGreen, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: required
                ? (v) => (v == null || v.isEmpty) ? '$label requis' : null
                : null,
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: Colors.grey[100], indent: 16, endIndent: 16),
      ],
    );
  }

  // ─── LIGNE INFO FIXE ────────────────────────────────────────────────────────
  Widget _buildInfoRow(String emoji, String label, String value) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── IMAGE PROFIL ────────────────────────────────────────────────────────────
  Widget _buildProfileImage() {
    if (_selectedImage != null) {
      return Image.file(
        File(_selectedImage!.path),
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
      );
    }

    final url = _profileImageUrl;
    bool isValidUrl = false;
    if (url != null && url.trim().isNotEmpty) {
      try {
        final uri = Uri.parse(url);
        if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
          isValidUrl = true;
        }
      } catch (_) {}
    }

    if (isValidUrl) {
      return Image.network(
        url!,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          );
        },
        errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
      );
    }

    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    final initial = widget.currentUser.nom.isNotEmpty
        ? widget.currentUser.nom[0].toUpperCase()
        : '?';
    return Container(
      color: AppColors.primaryGreen.withOpacity(0.15),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}