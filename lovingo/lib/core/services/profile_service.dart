import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

// Provider pour l'état de mise à jour du profil
final profileUpdateStateProvider = StateNotifierProvider<ProfileUpdateNotifier, ProfileUpdateState>((ref) {
  return ProfileUpdateNotifier();
});

class ProfileUpdateState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;
  final double uploadProgress;

  const ProfileUpdateState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.uploadProgress = 0.0,
  });

  ProfileUpdateState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    double? uploadProgress,
  }) {
    return ProfileUpdateState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }
}

class ProfileUpdateNotifier extends StateNotifier<ProfileUpdateState> {
  ProfileUpdateNotifier() : super(const ProfileUpdateState());

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading, error: null);
  }

  void setProgress(double progress) {
    state = state.copyWith(uploadProgress: progress);
  }

  void setError(String error) {
    state = state.copyWith(isLoading: false, error: error);
  }

  void setSuccess() {
    state = state.copyWith(isLoading: false, isSuccess: true, error: null);
  }

  void reset() {
    state = const ProfileUpdateState();
  }
}

class ProfileService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  // ✅ Upload une photo vers Firebase Storage
  Future<String> uploadPhoto(File imageFile, String userId) async {
    try {
      final String fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage
          .ref()
          .child('user_photos')
          .child(userId)
          .child(fileName);

      // Upload avec monitoring du progrès
      final UploadTask uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Obtenir l'URL de téléchargement
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('✅ Photo uploadée: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Erreur upload photo: $e');
      throw Exception('Erreur lors de l\'upload de la photo: $e');
    }
  }

  // ✅ Upload multiple photos avec monitoring du progrès
  Future<List<String>> uploadMultiplePhotos(
    List<File> imageFiles, 
    String userId,
    Function(double)? onProgress,
  ) async {
    try {
      final List<String> urls = [];
      
      for (int i = 0; i < imageFiles.length; i++) {
        final url = await uploadPhoto(imageFiles[i], userId);
        urls.add(url);
        
        // Notifier le progrès
        if (onProgress != null) {
          onProgress((i + 1) / imageFiles.length);
        }
      }
      
      return urls;
    } catch (e) {
      print('❌ Erreur upload multiple photos: $e');
      throw Exception('Erreur lors de l\'upload des photos: $e');
    }
  }

  // ✅ Supprimer une photo de Firebase Storage
  Future<void> deletePhoto(String photoUrl) async {
    try {
      final Reference ref = _storage.refFromURL(photoUrl);
      await ref.delete();
      print('✅ Photo supprimée: $photoUrl');
    } catch (e) {
      print('❌ Erreur suppression photo: $e');
      throw Exception('Erreur lors de la suppression de la photo: $e');
    }
  }

  // ✅ CORRIGÉ : Mettre à jour le profil utilisateur avec support du nom
  Future<void> updateUserProfile({
    required String userId,
    String? name, // 🆕 AJOUTÉ : Paramètre pour modifier le nom
    String? bio,
    int? age,
    List<String>? interests,
    List<String>? newPhotoUrls,
    List<String>? photosToRemove,
    int? minAge,
    int? maxAge,
    double? maxDistance,
    Map<String, dynamic>? preferences,
  }) async {
    try {
      // Récupérer les données actuelles de l'utilisateur
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('Utilisateur introuvable');
      }

      final currentData = userDoc.data()!;
      final currentPhotos = List<String>.from(currentData['photos'] ?? []);

      // Supprimer les photos demandées
      if (photosToRemove != null) {
        for (final photoUrl in photosToRemove) {
          currentPhotos.remove(photoUrl);
          // Supprimer de Firebase Storage
          await deletePhoto(photoUrl);
        }
      }

      // Ajouter les nouvelles photos
      if (newPhotoUrls != null) {
        currentPhotos.addAll(newPhotoUrls);
      }

      // Construire les données à mettre à jour
      final Map<String, dynamic> updateData = {};

      // 🆕 AJOUTÉ : Support de la modification du nom
      if (name != null) updateData['name'] = name;
      if (bio != null) updateData['bio'] = bio;
      if (age != null) updateData['age'] = age;
      if (interests != null) updateData['interests'] = interests;
      if (newPhotoUrls != null || photosToRemove != null) {
        updateData['photos'] = currentPhotos;
      }
      if (minAge != null) updateData['minAge'] = minAge;
      if (maxAge != null) updateData['maxAge'] = maxAge;
      if (maxDistance != null) updateData['maxDistance'] = maxDistance;
      if (preferences != null) updateData['preferences'] = preferences;

      // Ajouter timestamp de dernière modification
      updateData['updatedAt'] = DateTime.now().toIso8601String();

      // Mettre à jour dans Firestore
      await _firestore.collection('users').doc(userId).update(updateData);
      
      print('✅ Profil mis à jour pour $userId');
    } catch (e) {
      print('❌ Erreur mise à jour profil: $e');
      throw Exception('Erreur lors de la mise à jour du profil: $e');
    }
  }

  // ✅ Sélectionner et uploader une photo
  Future<String?> pickAndUploadPhoto(String userId) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final imageFile = File(image.path);
        return await uploadPhoto(imageFile, userId);
      }
      
      return null;
    } catch (e) {
      print('❌ Erreur sélection/upload photo: $e');
      throw Exception('Erreur lors de la sélection de la photo: $e');
    }
  }

  // ✅ Sélectionner et uploader plusieurs photos
  Future<List<String>> pickAndUploadMultiplePhotos(
    String userId,
    Function(double)? onProgress,
  ) async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        final imageFiles = images.map((xfile) => File(xfile.path)).toList();
        return await uploadMultiplePhotos(imageFiles, userId, onProgress);
      }
      
      return [];
    } catch (e) {
      print('❌ Erreur sélection/upload multiple photos: $e');
      throw Exception('Erreur lors de la sélection des photos: $e');
    }
  }

  // ✅ Redimensionner et compresser une image
  Future<File> compressImage(File imageFile) async {
    try {
      // TODO: Implémenter avec image package si nécessaire
      // Pour l'instant, retourner l'image originale
      return imageFile;
    } catch (e) {
      print('❌ Erreur compression image: $e');
      return imageFile;
    }
  }

  // ✅ AMÉLIORÉ : Valider les données du profil avec support du nom
  bool validateProfileData({
    String? name, // 🆕 AJOUTÉ
    String? bio,
    int? age,
    int? minAge,
    int? maxAge,
    double? maxDistance,
    List<String>? interests,
  }) {
    // 🆕 Validation du nom
    if (name != null && (name.trim().isEmpty || name.length < 2 || name.length > 50)) {
      throw Exception('Le nom doit contenir entre 2 et 50 caractères');
    }

    // Validation de l'âge
    if (age != null && (age < 18 || age > 99)) {
      throw Exception('L\'âge doit être entre 18 et 99 ans');
    }

    // Validation de la tranche d'âge
    if (minAge != null && maxAge != null && minAge > maxAge) {
      throw Exception('L\'âge minimum ne peut pas être supérieur à l\'âge maximum');
    }

    // Validation de la bio
    if (bio != null && bio.length > 500) {
      throw Exception('La bio ne peut pas dépasser 500 caractères');
    }

    // Validation de la distance
    if (maxDistance != null && (maxDistance < 1 || maxDistance > 500)) {
      throw Exception('La distance doit être entre 1 et 500 km');
    }

    // Validation des centres d'intérêt
    if (interests != null && interests.length > 10) {
      throw Exception('Vous ne pouvez sélectionner que 10 centres d\'intérêt maximum');
    }

    return true;
  }

  // ✅ Réorganiser l'ordre des photos
  Future<void> reorderPhotos(String userId, List<String> orderedPhotoUrls) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'photos': orderedPhotoUrls,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      print('✅ Ordre des photos mis à jour');
    } catch (e) {
      print('❌ Erreur réorganisation photos: $e');
      throw Exception('Erreur lors de la réorganisation des photos: $e');
    }
  }

  // ✅ Obtenir l'espace de stockage utilisé par l'utilisateur
  Future<int> getStorageUsed(String userId) async {
    try {
      final ListResult result = await _storage
          .ref()
          .child('user_photos')
          .child(userId)
          .listAll();

      int totalSize = 0;
      for (final Reference ref in result.items) {
        final FullMetadata metadata = await ref.getMetadata();
        totalSize += metadata.size ?? 0;
      }

      return totalSize;
    } catch (e) {
      print('❌ Erreur calcul stockage: $e');
      return 0;
    }
  }

  // ✅ Nettoyer les photos orphelines (non référencées dans le profil)
  Future<void> cleanupOrphanedPhotos(String userId) async {
    try {
      // Récupérer les photos actuelles du profil
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final profilePhotos = List<String>.from(userDoc.data()!['photos'] ?? []);
      
      // Récupérer toutes les photos dans le storage
      final ListResult result = await _storage
          .ref()
          .child('user_photos')
          .child(userId)
          .listAll();

      // Supprimer les photos non référencées
      for (final Reference ref in result.items) {
        final String downloadUrl = await ref.getDownloadURL();
        if (!profilePhotos.contains(downloadUrl)) {
          await ref.delete();
          print('✅ Photo orpheline supprimée: $downloadUrl');
        }
      }
    } catch (e) {
      print('❌ Erreur nettoyage photos orphelines: $e');
    }
  }

  updateUserProfileLocation({required String userId, required String city, required String country, required double latitude, required double longitude}) {}
}