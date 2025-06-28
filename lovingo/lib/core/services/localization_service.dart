import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/user_model.dart';

// =============================================================================
// PROVIDERS
// =============================================================================

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final localizationServiceProvider = StateNotifierProvider<LocalizationService, LocalizationState>(
  (ref) => LocalizationService(),
);

final userLocationProvider = StateNotifierProvider<UserLocationNotifier, UserLocationState>(
  (ref) => UserLocationNotifier(),
);

// =============================================================================
// ÉTATS ET MODÈLES
// =============================================================================

class LocalizationState {
  final Locale currentLocale;
  final bool isLoading;
  final Map<String, String> translations;

  const LocalizationState({
    required this.currentLocale,
    this.isLoading = false,
    this.translations = const {},
  });

  LocalizationState copyWith({
    Locale? currentLocale,
    bool? isLoading,
    Map<String, String>? translations,
  }) {
    return LocalizationState(
      currentLocale: currentLocale ?? this.currentLocale,
      isLoading: isLoading ?? this.isLoading,
      translations: translations ?? this.translations,
    );
  }
}

class UserLocationState {
  final UserLocation? location;
  final bool isLoading;
  final bool hasPermission;
  final String? error;
  final bool isGpsEnabled;

  const UserLocationState({
    this.location,
    this.isLoading = false,
    this.hasPermission = false,
    this.error,
    this.isGpsEnabled = false,
  });

  UserLocationState copyWith({
    UserLocation? location,
    bool? isLoading,
    bool? hasPermission,
    String? error,
    bool? isGpsEnabled,
  }) {
    return UserLocationState(
      location: location ?? this.location,
      isLoading: isLoading ?? this.isLoading,
      hasPermission: hasPermission ?? this.hasPermission,
      error: error,
      isGpsEnabled: isGpsEnabled ?? this.isGpsEnabled,
    );
  }
}

// =============================================================================
// SERVICE DE GÉOLOCALISATION GPS
// =============================================================================

class LocationService {
  static const String _locationKey = 'saved_location';

  // Vérifier et demander les permissions
  Future<bool> requestLocationPermission() async {
    try {
      final permission = await Permission.location.request();
      
      if (permission.isGranted) {
        return true;
      } else if (permission.isPermanentlyDenied) {
        return false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Vérifier si le GPS est activé
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Obtenir la position actuelle
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        throw Exception('Permission de localisation refusée');
      }

      final isEnabled = await isLocationServiceEnabled();
      if (!isEnabled) {
        throw Exception('Service de localisation désactivé');
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) {
      return null;
    }
  }

  // Convertir position en adresse (reverse geocoding)
  Future<UserLocation?> getLocationFromPosition(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        
        return UserLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          city: placemark.locality ?? placemark.subAdministrativeArea ?? 'Ville inconnue',
          country: placemark.country ?? 'Pays inconnu',
        );
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  // Obtenir position ET adresse complète
  Future<UserLocation?> getCurrentLocationWithAddress() async {
    try {
      final position = await getCurrentPosition();
      if (position == null) return null;

      return await getLocationFromPosition(position);
    } catch (e) {
      return null;
    }
  }

  // Sauvegarder la localisation
  Future<void> saveLocation(UserLocation location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationData = {
        'latitude': location.latitude,
        'longitude': location.longitude,
        'city': location.city,
        'country': location.country,
      };
      
      await prefs.setString(_locationKey, locationData.toString());
    } catch (e) {
      // Erreur silencieuse
    }
  }

  // Calculer la distance entre deux points
  double calculateDistance(UserLocation from, UserLocation to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    ) / 1000; // Convertir en kilomètres
  }
}

// =============================================================================
// SERVICE DE LOCALISATION/TRADUCTION (VOTRE CODE EXISTANT AMÉLIORÉ)
// =============================================================================

class LocalizationService extends StateNotifier<LocalizationState> {
  LocalizationService() : super(
    const LocalizationState(currentLocale: Locale('fr', 'FR')), // Français par défaut
  ) {
    initialize();
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString('app_language');
      
      if (savedLanguage != null) {
        final parts = savedLanguage.split('_');
        state = state.copyWith(
          currentLocale: Locale(parts[0], parts.length > 1 ? parts[1] : null),
        );
      } else {
        // Détecter la langue système
        final systemLocale = Platform.localeName;
        final parts = systemLocale.split('_');
        final detectedLocale = Locale(parts[0], parts.length > 1 ? parts[1] : null);
        
        state = state.copyWith(currentLocale: detectedLocale);
        await _saveLanguage(detectedLocale);
      }
      
      await _loadTranslations();
    } catch (e) {
      // Garder français par défaut
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> changeLanguage(Locale locale) async {
    state = state.copyWith(currentLocale: locale);
    await _saveLanguage(locale);
    await _loadTranslations();
  }

  Future<void> _saveLanguage(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', '${locale.languageCode}_${locale.countryCode}');
  }

  Future<void> _loadTranslations() async {
    final translations = <String, String>{
      'welcome': _getTranslation('welcome'),
      'discover': _getTranslation('discover'),
      'chat': _getTranslation('chat'),
      'profile': _getTranslation('profile'),
      'premium': _getTranslation('premium'),
      'wallet': _getTranslation('wallet'),
      'location_not_set': _getTranslation('location_not_set'),
      'enable_location': _getTranslation('enable_location'),
      'currency': _getTranslation('currency'),
    };
    
    state = state.copyWith(translations: translations);
  }

  String _getTranslation(String key) {
    final languageCode = state.currentLocale.languageCode;
    
    final translations = {
      'fr': {
        'welcome': 'Bienvenue',
        'discover': 'Découvrir',
        'chat': 'Chat',
        'profile': 'Profil',
        'premium': 'Premium',
        'wallet': 'Portefeuille',
        'location_not_set': 'Localisation non définie',
        'enable_location': 'Activer la localisation',
        'currency': 'Monnaie',
      },
      'en': {
        'welcome': 'Welcome',
        'discover': 'Discover',
        'chat': 'Chat',
        'profile': 'Profile',
        'premium': 'Premium',
        'wallet': 'Wallet',
        'location_not_set': 'Location not set',
        'enable_location': 'Enable location',
        'currency': 'Currency',
      },
      'es': {
        'welcome': 'Bienvenido',
        'discover': 'Descubrir',
        'chat': 'Chat',
        'profile': 'Perfil',
        'premium': 'Premium',
        'wallet': 'Cartera',
        'location_not_set': 'Ubicación no establecida',
        'enable_location': 'Habilitar ubicación',
        'currency': 'Moneda',
      },
    };
    
    return translations[languageCode]?[key] ?? translations['fr']?[key] ?? key;
  }

  String translate(String key) {
    return state.translations[key] ?? key;
  }
}

// =============================================================================
// NOTIFIER POUR LA LOCALISATION UTILISATEUR
// =============================================================================

class UserLocationNotifier extends StateNotifier<UserLocationState> {
  UserLocationNotifier() : super(const UserLocationState());

  Future<void> requestLocation() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final locationService = LocationService();
      
      // Vérifier les permissions
      final hasPermission = await locationService.requestLocationPermission();
      if (!hasPermission) {
        state = state.copyWith(
          isLoading: false,
          hasPermission: false,
          error: 'Permission de localisation refusée',
        );
        return;
      }

      // Vérifier si le GPS est activé
      final isEnabled = await locationService.isLocationServiceEnabled();
      if (!isEnabled) {
        state = state.copyWith(
          isLoading: false,
          isGpsEnabled: false,
          error: 'Service de localisation désactivé',
        );
        return;
      }

      // Obtenir la localisation
      final location = await locationService.getCurrentLocationWithAddress();
      if (location != null) {
        await locationService.saveLocation(location);
        
        state = state.copyWith(
          location: location,
          isLoading: false,
          hasPermission: true,
          isGpsEnabled: true,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Impossible d\'obtenir la localisation',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur: $e',
      );
    }
  }

  void clearLocation() {
    state = state.copyWith(location: null, error: null);
  }
}