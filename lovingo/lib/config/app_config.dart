class AppConfig {
  // Configuration Firebase
  static const String firebaseProjectId = 'lovingo-app';
  
  // Configuration Stripe
  static const String stripePublishableKey = 'pk_test_your_key_here';
  static const String stripeSecretKey = 'sk_test_your_key_here';
  
  // Configuration API
  static const String baseUrl = 'https://api.lovingo.app';
  static const String websocketUrl = 'wss://ws.lovingo.app';
  
  // Configuration de l'app
  static const String appName = 'Lovingo';
  static const String appVersion = '1.0.0';
  
  // Modes de développement
  static const bool isDebug = true;
  static const bool enableLogging = true;
  
  // Configuration des fonctionnalités
  static const bool enablePremiumFeatures = true;
  static const bool enableVideoCall = true;
  static const bool enableGifts = true;
  
  // Limites de l'app
  static const int maxPhotosPerUser = 9;
  static const int maxDistanceKm = 100;
  static const int minAge = 18;
  static const int maxAge = 99;
  
  // Configuration des cadeaux
  static const int dailyFreeCredits = 10;
  static const int welcomeBonus = 100;
}
