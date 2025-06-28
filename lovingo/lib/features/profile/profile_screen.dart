import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../../core/services/auth_service.dart';
import '../../core/services/profile_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/services/currency_service.dart';
import '../../core/models/user_model.dart';
import '../../shared/themes/app_theme.dart';
import '../auth/login_screen.dart';
import '../premium/premium_screen.dart';
import '../wallet/wallet_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _ageController = TextEditingController();
  
  List<String> _selectedInterests = [];
  final List<File> _newPhotos = []; // 🔧 CORRIGÉ : final
  final List<String> _photosToRemove = []; // 🔧 CORRIGÉ : final
  bool _isEditing = false;
  
  // Préférences de recherche
  double _minAge = 18;
  double _maxAge = 50;
  double _maxDistance = 50;

  final List<String> _availableInterests = [
    'Sport', 'Musique', 'Cinéma', 'Lecture', 'Voyage', 'Cuisine',
    'Art', 'Technologie', 'Nature', 'Danse', 'Photographie', 'Mode',
    'Gaming', 'Yoga', 'Fitness', 'Animaux', 'Sciences', 'Histoire'
  ];

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  void _initializeProfile() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _nameController.text = user.name;
      _bioController.text = user.bio;
      _ageController.text = user.age.toString();
      _selectedInterests = List.from(user.interests);
      _minAge = user.minAge.toDouble();
      _maxAge = user.maxAge.toDouble();
      _maxDistance = user.maxDistance;
      _photosToRemove.clear();
      _newPhotos.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profileUpdateState = ref.watch(profileUpdateStateProvider);
    
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      resizeToAvoidBottomInset: true, // 🔧 AJOUTÉ pour gérer le clavier
      body: Stack(
        children: [
          // Background avec gradient
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
            ),
          ),
          
          // Contenu principal avec SafeArea
          SafeArea( // 🔧 AJOUTÉ SafeArea
            child: CustomScrollView(
              slivers: [
                // AppBar personnalisée
                SliverAppBar(
                  expandedHeight: 120,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  actions: [
                    IconButton(
                      onPressed: profileUpdateState.isLoading 
                          ? null 
                          : (_isEditing ? _saveProfile : _toggleEdit),
                      icon: Icon(
                        _isEditing ? Icons.save : Icons.edit,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: _showSettingsMenu,
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: true,
                    title: Text(
                      _isEditing ? 'Modifier le profil' : user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                
                // Contenu défilable
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Header avec photo de profil et badge premium
                          _buildProfileHeader(user),
                          const SizedBox(height: 24),
                          
                          // Photos Section
                          _buildPhotosSection(user),
                          const SizedBox(height: 16),
                          
                          // Basic Info Card
                          _buildBasicInfoCard(user),
                          const SizedBox(height: 16),
                          
                          // Bio Card
                          _buildBioCard(),
                          const SizedBox(height: 16),
                          
                          // Interests Card
                          _buildInterestsCard(),
                          const SizedBox(height: 16),
                          
                          // Preferences Card
                          _buildPreferencesCard(),
                          const SizedBox(height: 16),
                          
                          // Informations de compte
                          _buildAccountInfoCard(user),
                          const SizedBox(height: 16),
                          
                          // Stats Card
                          _buildStatsCard(user),
                          const SizedBox(height: 16),
                          
                          // Navigation rapide
                          _buildQuickActionsCard(),
                          const SizedBox(height: 16),
                          
                          // Paramètres
                          _buildSettingsCard(),
                          const SizedBox(height: 16),
                          
                          // Actions de compte
                          _buildAccountActionsCard(),
                          const SizedBox(height: 24),
                          
                          // Action Buttons (mode édition)
                          if (_isEditing) _buildActionButtons(),
                          
                          // 🔧 MODIFIÉ : Espace adaptatif pour éviter l'overflow
                          SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Loading overlay
          if (profileUpdateState.isLoading)
            _buildLoadingOverlay(profileUpdateState),
        ],
      ),
    );
  }

  // Header avec photo de profil
  Widget _buildProfileHeader(UserModel user) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: AppTheme.cardGradient,
        ),
        child: Column(
          children: [
            // Photo de profil principale
            Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryColor, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 56,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: user.photos.isNotEmpty 
                        ? NetworkImage(user.photos.first)
                        : null,
                    child: user.photos.isEmpty 
                        ? Icon(Icons.person, size: 60, color: Colors.grey[400])
                        : null,
                  ),
                ),
                
                // Badge Premium
                if (user.isPremium)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.stars, color: Colors.white, size: 20),
                    ),
                  ),
                
                // Badge en ligne
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: user.isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Nom et âge
            Text(
              '${user.name}, ${user.age}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            
            const SizedBox(height: 4),
            
            // Localisation avec détection automatique
            Consumer(
              builder: (context, ref, child) {
                final locationState = ref.watch(userLocationProvider);
                final localizationService = ref.watch(localizationServiceProvider.notifier);
                
                return GestureDetector(
                  onTap: () => _handleLocationTap(ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: (user.location?.city != null && user.location!.city!.isNotEmpty)
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (user.location?.city != null && user.location!.city!.isNotEmpty)
                            ? AppTheme.primaryColor.withOpacity(0.3)
                            : Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (user.location?.city != null && user.location!.city!.isNotEmpty)
                              ? Icons.location_on
                              : Icons.location_off,
                          color: (user.location?.city != null && user.location!.city!.isNotEmpty)
                              ? AppTheme.primaryColor
                              : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        if (locationState.isLoading)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Flexible(
                            child: Text(
                              _getLocationText(user, localizationService),
                              style: TextStyle(
                                color: (user.location?.city != null && user.location!.city!.isNotEmpty)
                                    ? AppTheme.primaryColor
                                    : Colors.red,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (user.location?.city == null || user.location!.city!.isEmpty) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.touch_app,
                            color: Colors.red,
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Photos Section
  Widget _buildPhotosSection(UserModel user) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Photos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_isEditing) ...[
                  Row(
                    children: [
                      IconButton(
                        onPressed: _addPhoto,
                        icon: const Icon(Icons.add_photo_alternate, 
                            color: AppTheme.primaryColor),
                      ),
                      IconButton(
                        onPressed: _addMultiplePhotos,
                        icon: const Icon(Icons.photo_library, 
                            color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: _buildPhotosList(user),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosList(UserModel user) {
    final existingPhotos = user.photos.where((photo) => !_photosToRemove.contains(photo)).toList();
    final totalPhotos = existingPhotos.length + _newPhotos.length;
    
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: totalPhotos + (_isEditing ? 1 : 0),
      itemBuilder: (context, index) {
        // Existing photos
        if (index < existingPhotos.length) {
          return _buildPhotoItem(
            imageUrl: existingPhotos[index],
            onDelete: _isEditing ? () => _removeExistingPhoto(existingPhotos[index]) : null,
          );
        }
        // New photos
        else if (index < totalPhotos) {
          final newIndex = index - existingPhotos.length;
          return _buildPhotoItem(
            imageFile: _newPhotos[newIndex],
            onDelete: () => _removeNewPhoto(newIndex),
          );
        }
        // Add button
        else {
          return _buildAddPhotoButton();
        }
      },
    );
  }

  Widget _buildPhotoItem({String? imageUrl, File? imageFile, VoidCallback? onDelete}) {
    return Container(
      width: 100,
      height: 120,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    width: 100,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.person, size: 50),
                    ),
                  )
                : imageFile != null
                    ? Image.file(
                        imageFile,
                        width: 100,
                        height: 120,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.person, size: 50),
                      ),
          ),
          if (onDelete != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddPhotoButton() {
    return GestureDetector(
      onTap: _addPhoto,
      child: Container(
        width: 100,
        height: 120,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor, style: BorderStyle.solid),
          color: AppTheme.primaryColor.withOpacity(0.1),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, color: AppTheme.primaryColor, size: 30),
            Text('Ajouter', style: TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // Basic Info Card
  Widget _buildBasicInfoCard(UserModel user) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informations de base',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Nom modifiable
            _isEditing 
                ? _buildEditableNameField()
                : _buildInfoRow(Icons.person, 'Nom', user.name),
            const SizedBox(height: 16),
            
            _isEditing 
                ? _buildEditableAgeField()
                : _buildInfoRow(Icons.calendar_today, 'Âge', '${user.age} ans'),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.people, 'Genre', _formatGender(user.gender)),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.email, 'Email', user.email),
          ],
        ),
      ),
    );
  }

  // Champ nom modifiable
  Widget _buildEditableNameField() {
    return Row(
      children: [
        const Icon(Icons.person, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Le nom est requis';
              if (value.trim().length < 2) return 'Le nom doit faire au moins 2 caractères';
              if (value.trim().length > 50) return 'Le nom ne peut pas dépasser 50 caractères';
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableAgeField() {
    return Row(
      children: [
        const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Âge',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Requis';
              final age = int.tryParse(value);
              if (age == null || age < 18 || age > 99) return 'Âge invalide (18-99)';
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBioCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'À propos de moi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _isEditing
                ? TextFormField(
                    controller: _bioController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      hintText: 'Parlez-nous de vous...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value != null && value.length > 500) {
                        return 'Maximum 500 caractères';
                      }
                      return null;
                    },
                  )
                : Text(
                    _bioController.text.isEmpty ? 'Aucune description' : _bioController.text,
                    style: const TextStyle(fontSize: 16),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Centres d\'intérêt',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_isEditing)
                  Text(
                    '${_selectedInterests.length}/10',
                    style: const TextStyle(color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isEditing) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableInterests.map((interest) {
                  final isSelected = _selectedInterests.contains(interest);
                  return FilterChip(
                    label: Text(interest),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          if (_selectedInterests.length < 10) {
                            _selectedInterests.add(interest);
                          }
                        } else {
                          _selectedInterests.remove(interest);
                        }
                      });
                    },
                    selectedColor: AppTheme.primaryColor.withOpacity(0.3),
                    checkmarkColor: AppTheme.primaryColor,
                  );
                }).toList(),
              ),
            ] else ...[
              if (_selectedInterests.isEmpty)
                const Text('Aucun centre d\'intérêt sélectionné')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedInterests.map((interest) {
                    return Chip(
                      label: Text(interest),
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    );
                  }).toList(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Préférences de recherche',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Tranche d'âge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Âge: ${_minAge.toInt()} - ${_maxAge.toInt()} ans'),
                if (_isEditing)
                  TextButton(
                    onPressed: _showAgeRangeDialog,
                    child: const Text('Modifier'),
                  ),
              ],
            ),
            
            // Slider d'âge en mode édition
            if (_isEditing) ...[
              RangeSlider(
                values: RangeValues(_minAge, _maxAge),
                min: 18,
                max: 80,
                divisions: 62,
                labels: RangeLabels('${_minAge.toInt()}', '${_maxAge.toInt()}'),
                onChanged: (values) {
                  setState(() {
                    _minAge = values.start;
                    _maxAge = values.end;
                  });
                },
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Distance maximale
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Distance: ${_maxDistance.toInt()} km'),
                if (_isEditing)
                  TextButton(
                    onPressed: _showDistanceDialog,
                    child: const Text('Modifier'),
                  ),
              ],
            ),
            
            // Slider de distance en mode édition
            if (_isEditing) ...[
              Slider(
                value: _maxDistance,
                min: 1,
                max: 500,
                divisions: 499,
                label: '${_maxDistance.toInt()} km',
                onChanged: (value) {
                  setState(() {
                    _maxDistance = value;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Informations de compte
  Widget _buildAccountInfoCard(UserModel user) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informations du compte',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            _buildInfoRow(
              Icons.person_outline, 
              'Statut', 
              user.isPremium ? 'Premium' : 'Gratuit'
            ),
            const SizedBox(height: 16),
            
            _buildInfoRow(
              Icons.account_balance_wallet, 
              'Solde', 
              '${user.wallet.balance.toStringAsFixed(2)} €'
            ),
            const SizedBox(height: 16),
            
            _buildInfoRow(
              Icons.calendar_today, 
              'Membre depuis', 
              _formatDate(user.createdAt)
            ),
            const SizedBox(height: 16),
            
            _buildInfoRow(
              Icons.access_time, 
              'Dernière activité', 
              _formatLastActive(user.lastActive)
            ),
          ],
        ),
      ),
    );
  }

  // Actions rapides
  Widget _buildQuickActionsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions rapides',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickAction(
                  icon: Icons.star,
                  label: 'Premium',
                  color: Colors.amber,
                  onTap: () => _navigateToPremium(),
                ),
                _buildQuickAction(
                  icon: Icons.account_balance_wallet,
                  label: 'Wallet',
                  color: Colors.green,
                  onTap: () => _navigateToWallet(),
                ),
                _buildQuickAction(
                  icon: Icons.support_agent,
                  label: 'Support',
                  color: Colors.blue,
                  onTap: () => _showSupport(),
                ),
                _buildQuickAction(
                  icon: Icons.share,
                  label: 'Partager',
                  color: Colors.purple,
                  onTap: () => _shareProfile(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Paramètres
  Widget _buildSettingsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paramètres',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            _buildSettingItem(
              icon: Icons.notifications,
              title: 'Notifications',
              subtitle: 'Gérer les notifications',
              onTap: () => _showNotificationSettings(),
            ),
            
            _buildSettingItem(
              icon: Icons.privacy_tip,
              title: 'Confidentialité',
              subtitle: 'Paramètres de confidentialité',
              onTap: () => _showPrivacySettings(),
            ),
            
            _buildSettingItem(
              icon: Icons.language,
              title: 'Langue',
              subtitle: 'Français',
              onTap: () => _showLanguageSettings(),
            ),
            
            _buildSettingItem(
              icon: Icons.dark_mode,
              title: 'Thème',
              subtitle: 'Mode clair',
              onTap: () => _showThemeSettings(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // Actions de compte
  Widget _buildAccountActionsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Compte',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            _buildAccountAction(
              icon: Icons.feedback,
              title: 'Envoyer un feedback',
              color: Colors.blue,
              onTap: () => _sendFeedback(),
            ),
            
            _buildAccountAction(
              icon: Icons.help,
              title: 'Aide & FAQ',
              color: Colors.green,
              onTap: () => _showHelp(),
            ),
            
            _buildAccountAction(
              icon: Icons.logout,
              title: 'Se déconnecter',
              color: Colors.orange,
              onTap: () => _logout(),
            ),
            
            _buildAccountAction(
              icon: Icons.delete_forever,
              title: 'Supprimer le compte',
              color: Colors.red,
              onTap: () => _deleteAccount(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountAction({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // Stats Card
  Widget _buildStatsCard(UserModel user) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistiques',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Likes', user.stats.totalLikes.toString()),
                _buildStatItem('Matches', user.stats.totalMatches.toString()),
                _buildStatItem('Vues', user.stats.profileViews.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Sauvegarder', 
              style: TextStyle(fontSize: 16, color: Colors.white)
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _cancelEdit,
          child: const Text('Annuler'),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay(ProfileUpdateState state) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              const Text(
                'Mise à jour du profil...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (state.uploadProgress > 0) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: state.uploadProgress,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
                const SizedBox(height: 8),
                Text('${(state.uploadProgress * 100).toInt()}%'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ========== MÉTHODES D'ACTION ==========

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (_isEditing) {
        _initializeProfile();
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _newPhotos.clear();
      _photosToRemove.clear();
      _initializeProfile();
    });
  }

  Future<void> _addPhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _newPhotos.add(File(image.path));
        });
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de l\'ajout de la photo: $e');
    }
  }

  Future<void> _addMultiplePhotos() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (images.isNotEmpty) {
        setState(() {
          _newPhotos.addAll(images.map((xfile) => File(xfile.path)));
        });
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de l\'ajout des photos: $e');
    }
  }

  void _removeExistingPhoto(String photoUrl) {
    setState(() {
      _photosToRemove.add(photoUrl);
    });
  }

  void _removeNewPhoto(int index) {
    setState(() {
      _newPhotos.removeAt(index);
    });
  }

  void _showAgeRangeDialog() {
    double tempMinAge = _minAge;
    double tempMaxAge = _maxAge;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tranche d\'âge'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Âge: ${tempMinAge.toInt()} - ${tempMaxAge.toInt()} ans'),
              const SizedBox(height: 16),
              RangeSlider(
                values: RangeValues(tempMinAge, tempMaxAge),
                min: 18,
                max: 80,
                divisions: 62,
                labels: RangeLabels('${tempMinAge.toInt()}', '${tempMaxAge.toInt()}'),
                onChanged: (values) {
                  setDialogState(() {
                    tempMinAge = values.start;
                    tempMaxAge = values.end;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _minAge = tempMinAge;
                  _maxAge = tempMaxAge;
                });
                Navigator.pop(context);
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDistanceDialog() {
    double tempMaxDistance = _maxDistance;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Distance maximale'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Distance: ${tempMaxDistance.toInt()} km'),
              const SizedBox(height: 16),
              Slider(
                value: tempMaxDistance,
                min: 1,
                max: 500,
                divisions: 499,
                label: '${tempMaxDistance.toInt()} km',
                onChanged: (value) {
                  setDialogState(() {
                    tempMaxDistance = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _maxDistance = tempMaxDistance;
                });
                Navigator.pop(context);
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final profileService = ref.read(profileServiceProvider);
    final updateNotifier = ref.read(profileUpdateStateProvider.notifier);

    try {
      updateNotifier.setLoading(true);

      // Validation des données du profil
      profileService.validateProfileData(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        age: int.tryParse(_ageController.text),
        minAge: _minAge.toInt(),
        maxAge: _maxAge.toInt(),
        maxDistance: _maxDistance,
        interests: _selectedInterests,
      );

      List<String> newPhotoUrls = [];
      if (_newPhotos.isNotEmpty) {
        newPhotoUrls = await profileService.uploadMultiplePhotos(
          _newPhotos,
          currentUser.id,
          (progress) => updateNotifier.setProgress(progress),
        );
      }

      // Mise à jour du profil utilisateur
      await profileService.updateUserProfile(
        userId: currentUser.id,
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        age: int.tryParse(_ageController.text),
        interests: _selectedInterests,
        newPhotoUrls: newPhotoUrls,
        photosToRemove: _photosToRemove,
        minAge: _minAge.toInt(),
        maxAge: _maxAge.toInt(),
        maxDistance: _maxDistance,
      );

      // Rafraîchir les données utilisateur
      ref.refresh(currentUserProvider); // ignore: unused_result

      updateNotifier.setSuccess();
      
      setState(() {
        _isEditing = false;
        _newPhotos.clear();
        _photosToRemove.clear();
      });
      
      _showSuccessSnackBar('Profil sauvegardé avec succès!');

      Future.delayed(const Duration(seconds: 2), () {
        updateNotifier.reset();
      });
      
    } catch (e) {
      updateNotifier.setError(e.toString());
      _showErrorSnackBar('Erreur: $e');

      Future.delayed(const Duration(seconds: 3), () {
        updateNotifier.reset();
      });
    }
  }

  // ========== NOUVELLES FONCTIONNALITÉS ==========

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 🔧 AJOUTÉ pour contrôler la taille
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16, // 🔧 AJOUTÉ pour le clavier
        ),
        child: SafeArea( // 🔧 AJOUTÉ SafeArea
          child: Column(
            mainAxisSize: MainAxisSize.min, // 🔧 Important pour éviter l'overflow
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Paramètres généraux'),
                onTap: () {
                  Navigator.pop(context);
                  _showGeneralSettings();
                },
              ),
              ListTile(
                leading: const Icon(Icons.security),
                title: const Text('Sécurité'),
                onTap: () {
                  Navigator.pop(context);
                  _showSecuritySettings();
                },
              ),
              ListTile(
                leading: const Icon(Icons.help),
                title: const Text('Aide'),
                onTap: () {
                  Navigator.pop(context);
                  _showHelp();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPremium() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PremiumScreen()),
    );
  }

  void _navigateToWallet() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WalletScreen()),
    );
  }

  void _showSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.support_agent, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Flexible(child: Text('Support client')), // 🔧 AJOUTÉ Flexible
          ],
        ),
        content: ConstrainedBox( // 🔧 AJOUTÉ pour limiter la hauteur
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: const SingleChildScrollView( // 🔧 AJOUTÉ pour permettre le scroll
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Besoin d\'aide ? Nous sommes là pour vous !'),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _launchEmail('support@lovingo.app');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Email', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openLiveChat();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Chat', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openFAQ();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('FAQ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _shareProfile() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      final profileText = '''
🌟 Découvrez mon profil sur Lovingo !

${user.name}, ${user.age} ans
${user.bio.isNotEmpty ? user.bio : 'Passionné(e) par la vie et les rencontres authentiques'}

💝 Centres d'intérêt : ${user.interests.take(3).join(', ')}${user.interests.length > 3 ? '...' : ''}

Téléchargez Lovingo pour faire de belles rencontres !
''';

      Share.share(
        profileText,
        subject: 'Profil de ${user.name} sur Lovingo',
      );
    }
  }

  void _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Support Lovingo - ${ref.read(currentUserProvider)?.name ?? 'Utilisateur'}',
    );
    
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        _showErrorSnackBar('Impossible d\'ouvrir l\'email. Copiez cette adresse : $email');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de l\'ouverture de l\'email');
    }
  }

  void _openLiveChat() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chat en direct à implémenter avec votre solution de chat'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _openFAQ() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('FAQ - Questions fréquentes'),
        content: ConstrainedBox( // 🔧 AJOUTÉ pour limiter la hauteur
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFAQItem(
                  'Comment modifier mes photos ?',
                  'Allez dans votre profil, cliquez sur "Modifier", puis sur l\'icône photo pour ajouter ou supprimer des images.',
                ),
                _buildFAQItem(
                  'Comment devenir Premium ?',
                  'Cliquez sur l\'icône étoile dans les actions rapides pour découvrir les avantages Premium.',
                ),
                _buildFAQItem(
                  'Comment signaler un problème ?',
                  'Utilisez le bouton "Envoyer un feedback" dans les paramètres de votre profil.',
                ),
                _buildFAQItem(
                  'Comment supprimer mon compte ?',
                  'Dans les paramètres du profil, utilisez l\'option "Supprimer le compte". Cette action est irréversible.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    _openFAQ();
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // Gestion de la localisation
  void _handleLocationTap(WidgetRef ref) {
    final user = ref.read(currentUserProvider);
    if (user?.location?.city == null || user!.location!.city!.isEmpty) {
      _showLocationEnableDialog(ref);
    } else {
      _showLocationOptions(ref);
    }
  }

  void _showLocationEnableDialog(WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.red),
            SizedBox(width: 8),
            Flexible(child: Text('Localisation non activée')), // 🔧 AJOUTÉ Flexible
          ],
        ),
        content: ConstrainedBox( // MediaQuery empêche const
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: const SingleChildScrollView( // 🔧 CORRIGÉ : ajout const
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [ // 🔧 CORRIGÉ : ajout const
                Text('Votre localisation n\'est pas définie. Cela peut limiter vos rencontres.'),
                SizedBox(height: 16),
                Text(
                  'Avantages de la localisation :',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text('• Trouver des personnes près de chez vous'),
                Text('• Afficher votre ville sur votre profil'),
                Text('• Filtrer par distance'),
                Text('• Améliorer vos matchs'),
                SizedBox(height: 16),
                Text(
                  'Si la localisation ne fonctionne pas :',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
                ),
                SizedBox(height: 4),
                Text('1. Vérifiez que le GPS est activé'),
                Text('2. Accordez les permissions de localisation'),
                Text('3. Essayez en extérieur pour un meilleur signal'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showLocationManualInput(ref);
            },
            child: const Text('Saisir manuellement'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _enableLocation(ref);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Détecter automatiquement', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLocationManualInput(WidgetRef ref) {
    final cityController = TextEditingController();
    final countryController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saisir votre localisation'),
        content: ConstrainedBox( // 🔧 AJOUTÉ pour limiter la hauteur
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: cityController,
                decoration: const InputDecoration(
                  labelText: 'Ville',
                  hintText: 'Ex: Paris, Lyon, Marseille...',
                  prefixIcon: Icon(Icons.location_city),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: countryController,
                decoration: const InputDecoration(
                  labelText: 'Pays',
                  hintText: 'Ex: France, Belgique, Suisse...',
                  prefixIcon: Icon(Icons.flag),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (cityController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                await _setManualLocation(
                  ref, 
                  cityController.text.trim(), 
                  countryController.text.trim().isEmpty ? 'France' : countryController.text.trim()
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _setManualLocation(WidgetRef ref, String city, String country) async {
    try {
      print('🚀 DÉBUT _setManualLocation pour: $city, $country');
      _showSuccessSnackBar('Mise à jour de votre localisation...');
      
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        print('❌ currentUser est null');
        _showErrorSnackBar('❌ Utilisateur non connecté');
        return;
      }
      
      print('👤 Utilisateur trouvé: ${currentUser.id}');
      
      // Coordonnées approximatives selon le pays (plus réalistes que 0,0)
      double lat = 48.8566; // Paris par défaut
      double lng = 2.3522;
      
      // Coordonnées approximatives selon le pays
      if (country.toLowerCase().contains('france')) {
        lat = 48.8566; lng = 2.3522; // Paris
      } else if (country.toLowerCase().contains('belgique') || country.toLowerCase().contains('belgium')) {
        lat = 50.8503; lng = 4.3517; // Bruxelles
      } else if (country.toLowerCase().contains('suisse') || country.toLowerCase().contains('switzerland')) {
        lat = 46.9481; lng = 7.4474; // Berne
      } else if (country.toLowerCase().contains('canada')) {
        lat = 45.5017; lng = -73.5673; // Montréal
      } else if (country.toLowerCase().contains('maroc') || country.toLowerCase().contains('morocco')) {
        lat = 33.9716; lng = -6.8498; // Rabat
      }
      
      print('📍 Coordonnées calculées: $lat, $lng');
      
      // Créer un UserLocation avec les données manuelles
      final manualLocation = UserLocation(
        latitude: lat,
        longitude: lng,
        city: city,
        country: country,
      );
      
      print('🗂️ UserLocation créé: ${manualLocation.city}');
      
      // 1. Sauvegarder localement avec LocationService
      try {
        final locationService = ref.read(locationServiceProvider);
        await locationService.saveLocation(manualLocation);
        print('✅ Sauvegarde locale réussie');
      } catch (e) {
        print('⚠️ Erreur sauvegarde locale: $e');
      }
      
      // 2. Mettre à jour le state du UserLocationNotifier
      try {
        final locationNotifier = ref.read(userLocationProvider.notifier);
        locationNotifier.state = locationNotifier.state.copyWith(
          location: manualLocation,
          isLoading: false,
          hasPermission: true,
          isGpsEnabled: true,
          error: null,
        );
        print('✅ State provider mis à jour');
      } catch (e) {
        print('⚠️ Erreur mise à jour state: $e');
      }
      
      // 3. 🔧 PRIORITÉ : Sauvegarder directement dans Firebase
      print('🔥 Début sauvegarde Firebase...');
      await _updateLocationInFirestore(currentUser.id, manualLocation);
      
      // 4. Détecter la monnaie selon le pays
      try {
        final currencyService = ref.read(currencyServiceProvider.notifier);
        await currencyService.detectCurrencyFromLocation(country);
        print('✅ Monnaie détectée');
      } catch (e) {
        print('⚠️ Erreur currency: $e');
        // Ignorer l'erreur de currency si le service n'existe pas
      }
      
      // 5. Rafraîchir les données utilisateur
      print('🔄 Rafraîchissement du provider...');
      ref.refresh(currentUserProvider); // ignore: unused_result
      
      print('🎉 _setManualLocation terminé avec succès');
      _showSuccessSnackBar('✅ Localisation sauvegardée : $city, $country');
      
    } catch (e) {
      print('💥 Erreur dans _setManualLocation: $e');
      _showErrorSnackBar('❌ Erreur lors de la mise à jour : $e');
    }
  }

  // Méthode pour mettre à jour directement dans Firestore si nécessaire
  Future<void> _updateLocationInFirestore(String userId, UserLocation location) async {
    try {
      print('🔧 DÉBUT mise à jour Firestore pour userId: $userId');
      print('🔧 Localisation: ${location.city}, ${location.country}');
      
      // Accéder à Firestore directement
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(userId).update({
        'location': {
          'city': location.city,
          'country': location.country,
          'latitude': location.latitude,
          'longitude': location.longitude,
        },
      });
      
      print('✅ Localisation sauvegardée dans Firestore avec succès');
    } catch (e) {
      print('❌ Erreur Firestore: $e');
      throw Exception('Erreur Firestore: $e');
    }
  }

  void _showLocationOptions(WidgetRef ref) {
    final user = ref.read(currentUserProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 🔧 AJOUTÉ
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20, // 🔧 AJOUTÉ pour le clavier
        ),
        child: SafeArea( // 🔧 AJOUTÉ SafeArea
          child: Column(
            mainAxisSize: MainAxisSize.min, // 🔧 Important
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Localisation actuelle',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '${user?.location?.city ?? 'Ville inconnue'}, ${user?.location?.country ?? 'Pays inconnu'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('Actualiser la localisation'),
                onTap: () {
                  Navigator.pop(context);
                  _enableLocation(ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.location_off),
                title: const Text('Effacer la localisation'),
                onTap: () {
                  Navigator.pop(context);
                  _clearLocation(ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enableLocation(WidgetRef ref) async {
    try {
      // Afficher un indicateur de chargement
      _showSuccessSnackBar('🔍 Recherche de votre position...');
      
      final locationNotifier = ref.read(userLocationProvider.notifier);
      await locationNotifier.requestLocation();
      
      final locationState = ref.read(userLocationProvider);
      
      // Vérifier que la localisation est valide
      if (locationState.location != null && 
          locationState.location!.city != null && 
          locationState.location!.city!.isNotEmpty) {
        
        // 🔧 AJOUTÉ : Sauvegarder dans Firebase aussi pour la détection automatique
        final currentUser = ref.read(currentUserProvider);
        if (currentUser != null) {
          // Priorité : écriture directe dans Firestore
          await _updateLocationInFirestore(currentUser.id, locationState.location!);
        }
        
        // Détecter automatiquement la monnaie selon le pays
        try {
          final currencyService = ref.read(currencyServiceProvider.notifier);
          await currencyService.detectCurrencyFromLocation(
            locationState.location!.country ?? 'France'
          );
        } catch (e) {
          // Ignorer l'erreur de currency si le service n'existe pas
        }
        
        // Rafraîchir les données utilisateur
        ref.refresh(currentUserProvider); // ignore: unused_result
        
        _showSuccessSnackBar('✅ Localisation activée : ${locationState.location!.city}');
        
      } else if (locationState.error != null) {
        // Proposer la saisie manuelle en cas d'erreur
        _showLocationErrorWithOptions(ref, locationState.error!);
      } else {
        _showLocationErrorWithOptions(ref, 'Localisation non trouvée. Vérifiez vos permissions GPS.');
      }
    } catch (e) {
      String errorMessage = _getLocationErrorMessage(e.toString());
      _showLocationErrorWithOptions(ref, errorMessage);
    }
  }

  void _showLocationErrorWithOptions(WidgetRef ref, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Flexible(child: Text('Problème de localisation')), // 🔧 AJOUTÉ Flexible
          ],
        ),
        content: ConstrainedBox( // 🔧 AJOUTÉ pour limiter la hauteur
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: SingleChildScrollView( // 🔧 AJOUTÉ pour permettre le scroll
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('❌ $error'),
                const SizedBox(height: 16),
                const Text(
                  'Solutions possibles :',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('• Activez le GPS sur votre appareil'),
                const Text('• Accordez les permissions de localisation'),
                const Text('• Sortez à l\'extérieur pour un meilleur signal'),
                const Text('• Ou saisissez votre ville manuellement'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showLocationManualInput(ref);
            },
            child: const Text('Saisir manuellement'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _enableLocation(ref);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getLocationErrorMessage(String error) {
    if (error.contains('permission')) {
      return 'Permission de localisation refusée. Activez-la dans les paramètres.';
    } else if (error.contains('disabled')) {
      return 'GPS désactivé. Activez la localisation sur votre appareil.';
    } else if (error.contains('timeout')) {
      return 'Délai d\'attente dépassé. Réessayez dans un endroit avec meilleur signal.';
    } else if (error.contains('network')) {
      return 'Problème de connexion. Vérifiez votre réseau.';
    } else {
      return 'Impossible d\'obtenir votre position automatiquement.';
    }
  }

  Future<void> _clearLocation(WidgetRef ref) async {
    try {
      // 1. Effacer localement
      final locationNotifier = ref.read(userLocationProvider.notifier);
      locationNotifier.clearLocation();
      
      // 2. 🔧 AJOUTÉ : Effacer aussi dans Firebase
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        try {
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('users').doc(currentUser.id).update({
            'location': null,
          });
          
          // Rafraîchir les données utilisateur
          ref.refresh(currentUserProvider); // ignore: unused_result
          
          _showSuccessSnackBar('📍 Localisation effacée complètement');
        } catch (e) {
          _showSuccessSnackBar('📍 Localisation effacée localement');
        }
      } else {
        _showSuccessSnackBar('📍 Localisation effacée');
      }
    } catch (e) {
      _showErrorSnackBar('❌ Erreur lors de l\'effacement');
    }
  }

  String _getLocationText(UserModel user, LocalizationService localizationService) {
    if (user.location?.city != null && user.location!.city!.isNotEmpty) {
      return user.location!.city!;
    } else if (user.location?.country != null && user.location!.country!.isNotEmpty) {
      return user.location!.country!;
    } else {
      return localizationService.translate('location_not_set');
    }
  }

  // Paramètres
  void _showNotificationSettings() {
    _showComingSoonDialog('Paramètres de notifications');
  }

  void _showPrivacySettings() {
    _showComingSoonDialog('Paramètres de confidentialité');
  }

  void _showLanguageSettings() {
    _showComingSoonDialog('Sélection de langue');
  }

  void _showThemeSettings() {
    _showComingSoonDialog('Sélection de thème');
  }

  void _showGeneralSettings() {
    _showComingSoonDialog('Paramètres généraux');
  }

  void _showSecuritySettings() {
    _showComingSoonDialog('Paramètres de sécurité');
  }

  void _sendFeedback() {
    _showComingSoonDialog('Fonction feedback');
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: ConstrainedBox( // 🔧 AJOUTÉ pour limiter la hauteur
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.2,
          ),
          child: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(authServiceProvider.notifier).logout();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) { // 🔧 CORRIGÉ : ajout de mounted check
                  _showErrorSnackBar('Erreur lors de la déconnexion');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le compte'),
        content: ConstrainedBox( // 🔧 AJOUTÉ pour limiter la hauteur
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.3,
          ),
          child: const SingleChildScrollView( // 🔧 AJOUTÉ pour permettre le scroll
            child: Text(
              'Cette action est irréversible. Toutes vos données seront définitivement supprimées.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showComingSoonDialog('Fonction de suppression de compte', isDestructive: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ========== MÉTHODES UTILITAIRES ==========

  void _showComingSoonDialog(String feature, {bool isDestructive = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Prochainement',
          style: TextStyle(
            color: isDestructive ? Colors.red : AppTheme.primaryColor,
          ),
        ),
        content: ConstrainedBox( // 🔧 AJOUTÉ pour limiter la hauteur
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.3,
          ),
          child: SingleChildScrollView( // 🔧 AJOUTÉ pour permettre le scroll
            child: Text('$feature sera disponible dans une prochaine mise à jour.'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            maxLines: 2, // 🔧 AJOUTÉ pour limiter les lignes
            overflow: TextOverflow.ellipsis, // 🔧 AJOUTÉ pour gérer l'overflow
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only( // 🔧 AJOUTÉ pour éviter les conflits avec le clavier
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            maxLines: 3, // 🔧 AJOUTÉ pour limiter les lignes (plus pour erreurs)
            overflow: TextOverflow.ellipsis, // 🔧 AJOUTÉ pour gérer l'overflow
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4), // 🔧 AJOUTÉ durée plus longue pour erreurs
          margin: EdgeInsets.only( // 🔧 AJOUTÉ pour éviter les conflits avec le clavier
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
        ),
      );
    }
  }

  String _formatGender(String gender) {
    switch (gender.toLowerCase()) {
      case 'male':
      case 'homme':
        return 'Homme';
      case 'female':
      case 'femme':
        return 'Femme';
      case 'non-binary':
      case 'non-binaire':
        return 'Non-binaire';
      default:
        return 'Autre';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 30) {
      return '${difference.inDays} jours';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} mois';
    } else {
      return '${(difference.inDays / 365).floor()} ans';
    }
  }

  String _formatLastActive(DateTime lastActive) {
    final now = DateTime.now();
    final difference = now.difference(lastActive);
    
    if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else {
      return 'Il y a ${difference.inDays} jours';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    super.dispose();
  }
}