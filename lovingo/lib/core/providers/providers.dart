// lib/core/providers/providers.dart - PROVIDERS CORRIGÉS COMPLETS
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ✅ IMPORTS DES SERVICES ET LEURS PROVIDERS
import '../services/auth_service.dart'; 
import '../services/discovery_service.dart';
import '../services/chat_service.dart'; // ✅ Contient déjà chatServiceProvider et chatRoomsProvider
import '../services/webrtc_call_service.dart'; // ✅ Contient déjà webrtcCallServiceProvider
import '../services/profile_service.dart';
import '../services/localization_service.dart'; // ✅ Contient déjà localizationServiceProvider  
import '../services/currency_service.dart'; // ✅ Contient déjà currencyServiceProvider
import '../services/wallet_service.dart'; // ✅ Contient déjà walletServiceProvider
import '../services/audio_service.dart'; // ✅ AudioService
import '../services/gift_service.dart'; // ✅ Contient déjà giftServiceProvider
import '../models/user_model.dart';
import '../models/chat_model.dart';

// ✅ TOUS LES PROVIDERS PRINCIPAUX SONT DÉJÀ DÉFINIS DANS LES SERVICES :
// - authServiceProvider et currentUserProvider → auth_service.dart
// - chatServiceProvider, chatRoomsProvider, chatUserProvider → chat_service.dart
// - webrtcCallServiceProvider → webrtc_call_service.dart  
// - localizationServiceProvider → localization_service.dart
// - currencyServiceProvider → currency_service.dart
// - walletServiceProvider → wallet_service.dart
// - giftServiceProvider → gift_service.dart

// ✅ PROVIDERS RESTANTS (qui ne sont pas dans les services individuels)

// Provider Discovery Service - CORRIGÉ
final discoveryServiceProvider = StateNotifierProvider<DiscoveryService, DiscoveryState>((ref) {
  return DiscoveryService(ref); // ✅ CORRIGÉ : Passer le paramètre ref
});

// Provider Profile Service
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

// ✅ PROVIDERS POUR LES ÉTATS DE L'APPLICATION

// État de localisation utilisateur (utilise le provider du localization_service.dart)
// final userLocationProvider est déjà défini dans localization_service.dart

// État des mises à jour de profil
final profileUpdateStateProvider = StateNotifierProvider<ProfileUpdateNotifier, ProfileUpdateState>((ref) {
  return ProfileUpdateNotifier();
});

// ✅ NOTIFIERS ET ÉTATS POUR PROFILE UPDATE

class ProfileUpdateState {
  final bool isLoading;
  final double uploadProgress;
  final String? error;
  final bool isSuccess;

  const ProfileUpdateState({
    this.isLoading = false,
    this.uploadProgress = 0.0,
    this.error,
    this.isSuccess = false,
  });

  ProfileUpdateState copyWith({
    bool? isLoading,
    double? uploadProgress,
    String? error,
    bool? isSuccess,
  }) {
    return ProfileUpdateState(
      isLoading: isLoading ?? this.isLoading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: error ?? this.error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class ProfileUpdateNotifier extends StateNotifier<ProfileUpdateState> {
  ProfileUpdateNotifier() : super(const ProfileUpdateState());

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading, uploadProgress: 0.0);
  }

  void setProgress(double progress) {
    state = state.copyWith(uploadProgress: progress);
  }

  void setError(String error) {
    state = state.copyWith(isLoading: false, error: error);
  }

  void setSuccess() {
    state = state.copyWith(isLoading: false, isSuccess: true);
  }

  void reset() {
    state = const ProfileUpdateState();
  }
}

// ✅ EXPORTS POUR FACILITER L'UTILISATION
// Re-export des providers des services pour un accès centralisé

// Authentification (depuis auth_service.dart)
// export 'package:your_package/core/services/auth_service.dart' show authServiceProvider, currentUserProvider;

// Chat (depuis chat_service.dart) 
// export 'package:your_package/core/services/chat_service.dart' show chatServiceProvider, chatRoomsProvider, chatUserProvider, chatMessagesProvider;

// WebRTC (depuis webrtc_call_service.dart)
// export 'package:your_package/core/services/webrtc_call_service.dart' show webrtcCallServiceProvider;

// Localisation (depuis localization_service.dart)
// export 'package:your_package/core/services/localization_service.dart' show localizationServiceProvider, userLocationProvider, locationServiceProvider;

// Currency (depuis currency_service.dart)  
// export 'package:your_package/core/services/currency_service.dart' show currencyServiceProvider;

// ✅ PROVIDERS UTILITAIRES POUR L'APP

// Provider pour les paramètres globaux de l'app
final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});

class AppSettings {
  final bool isDarkMode;
  final bool isNotificationsEnabled;
  final bool isSoundEnabled;
  final double volume;

  const AppSettings({
    this.isDarkMode = false,
    this.isNotificationsEnabled = true,
    this.isSoundEnabled = true,
    this.volume = 0.8,
  });

  AppSettings copyWith({
    bool? isDarkMode,
    bool? isNotificationsEnabled,
    bool? isSoundEnabled,
    double? volume,
  }) {
    return AppSettings(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isNotificationsEnabled: isNotificationsEnabled ?? this.isNotificationsEnabled,
      isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled,
      volume: volume ?? this.volume,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings());

  void toggleDarkMode() {
    state = state.copyWith(isDarkMode: !state.isDarkMode);
  }

  void toggleNotifications() {
    state = state.copyWith(isNotificationsEnabled: !state.isNotificationsEnabled);
  }

  void toggleSound() {
    state = state.copyWith(isSoundEnabled: !state.isSoundEnabled);
  }

  void setVolume(double volume) {
    state = state.copyWith(volume: volume.clamp(0.0, 1.0));
  }
}