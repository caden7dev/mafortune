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
    _telephoneController = TextEditingController(text: widget.currentUser.telephone);
    _adresseController = TextEditingController(text: widget.currentUser.adresse ?? '');
    _typeActiviteController = TextEditingController(text: widget.currentUser.typeActivite ?? '');
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

  // ✅ OPTIMISATION : Taille et qualité réduites pour accélérer l'upload
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 300,      // ✅ Réduit de 500 à 300 pixels
        maxHeight: 300,     // ✅ Réduit de 500 à 300 pixels
        imageQuality: 60,   // ✅ Réduit de 85 à 60 (fichier plus léger)
      );
      
      if (pickedFile != null) {
        // Afficher la taille du fichier pour info
        final bytes = await pickedFile.readAsBytes();
        final sizeInKB = bytes.length / 1024;
        print('📸 Photo: ${sizeInKB.toStringAsFixed(1)} KB');
        
        setState(() {
          _selectedImage = pickedFile;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Choisir une photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primaryGreen),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primaryGreen),
              title: const Text('Choisir dans la galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_profileImageUrl != null || _selectedImage != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Supprimer la photo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteImage();
                },
              ),
            const SizedBox(height: 10),
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
        } catch (e) {
          // Ignorer si le fichier n'existe pas
        }
      }
      
      setState(() {
        _selectedImage = null;
        _profileImageUrl = null;
      });
      
      final updatedUser = widget.currentUser.copyWith(photo: null);
      await _authService.updateUserProfile(updatedUser);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo supprimée'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
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
      
      final downloadUrl = await ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur upload: $e'), backgroundColor: Colors.red),
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
        final uploadedUrl = await _uploadImage();
        if (uploadedUrl != null) newPhotoUrl = uploadedUrl;
      }

      final updatedUser = widget.currentUser.copyWith(
        nom: _nomController.text.trim(),
        prenom: _prenomController.text.trim(),
        telephone: _telephoneController.text.trim(),
        adresse: _adresseController.text.trim().isEmpty ? null : _adresseController.text.trim(),
        typeActivite: _typeActiviteController.text.trim().isEmpty ? null : _typeActiviteController.text.trim(),
        photo: newPhotoUrl,
      );

      await _authService.updateUserProfile(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profil mis à jour'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 1),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Modifier le profil', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_isLoading || _isUploading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryGreen, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _buildProfileImage(),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploading ? null : _showImagePickerDialog,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),
            
            Center(
              child: TextButton(
                onPressed: _isUploading ? null : _showImagePickerDialog,
                child: const Text(
                  'Changer la photo',
                  style: TextStyle(color: AppColors.primaryGreen),
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _nomController,
                      label: 'Nom',
                      icon: Icons.person_outline,
                      validator: (value) => value == null || value.isEmpty ? 'Nom requis' : null,
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      controller: _prenomController,
                      label: 'Prénom',
                      icon: Icons.person,
                      validator: (value) => value == null || value.isEmpty ? 'Prénom requis' : null,
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      controller: _telephoneController,
                      label: 'Téléphone',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: (value) => value == null || value.isEmpty ? 'Téléphone requis' : null,
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      controller: _adresseController,
                      label: 'Adresse',
                      icon: Icons.location_on,
                      required: false,
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      controller: _typeActiviteController,
                      label: 'Type d\'activité',
                      icon: Icons.work_outline,
                      required: false,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Informations fixes',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    _buildInfoRow('Email', widget.currentUser.email),
                    const SizedBox(height: 8),
                    _buildInfoRow('Membre depuis', _formatDate(widget.currentUser.dateCreation)),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: BorderSide(color: Colors.grey[400]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Annuler', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _enregistrer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Enregistrer',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    if (_selectedImage != null) {
      return Image.network(
        _selectedImage!.path,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultAvatar();
        },
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
      } catch (e) {
        isValidUrl = false;
      }
    }
    
    if (isValidUrl) {
      return Image.network(
        url!,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultAvatar();
        },
      );
    }
    
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: AppColors.primaryGreen.withValues(alpha: 0.2),
      child: Center(
        child: Text(
          widget.currentUser.nom.isNotEmpty
              ? widget.currentUser.nom[0].toUpperCase()
              : '👤',
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool required = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: !_isLoading,
      decoration: InputDecoration(
        labelText: label,
        hintText: required ? null : 'Optionnel',
        prefixIcon: Icon(icon, color: AppColors.primaryGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator ??
          (required
              ? (value) => value == null || value.isEmpty ? '$label requis' : null
              : null),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
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