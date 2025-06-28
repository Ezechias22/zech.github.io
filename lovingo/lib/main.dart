// lib/main.dart - VERSION SANS TESTS
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// 🚀 IMPORTS POUR LOVINGO
import 'firebase_options.dart';
import 'shared/themes/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'config/webrtc_config.dart';
import 'features/calls/providers/call_provider.dart';
import 'core/services/call_notification_service.dart';
import 'core/services/auth_service.dart';

// ✅ NAVIGATION GLOBALE POUR WEBRTC - DÉFINIE DANS MAIN.DART
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ✅ HANDLER GLOBAL POUR MESSAGES EN BACKGROUND (requis par Firebase)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('📱 Message background handler: ${message.messageId}');
  
  if (message.data['type'] == 'incoming_call') {
    debugPrint('📞 Appel entrant en background de: ${message.data['caller_name'] ?? 'Inconnu'}');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔥 Initialiser Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // ✅ CONFIGURER FIREBASE MESSAGING DÈS LE DÉMARRAGE
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // 🚀 INITIALISER WEBRTC LOVINGO
  try {
    await WebRTCConfig.initialize();
    debugPrint('✅ WebRTC Lovingo initialisé avec succès');
  } catch (e) {
    debugPrint('❌ Erreur initialisation WebRTC: $e');
  }
  
  runApp(const ProviderScope(child: LovingoApp()));
}

class LovingoApp extends ConsumerStatefulWidget {
  const LovingoApp({super.key});

  @override
  ConsumerState<LovingoApp> createState() => _LovingoAppState();
}

class _LovingoAppState extends ConsumerState<LovingoApp> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // ✅ INITIALISER LES SERVICES IMMÉDIATEMENT
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotificationServices();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ✅ INITIALISER LES SERVICES DE NOTIFICATIONS DÈS LE DÉMARRAGE
  Future<void> _initializeNotificationServices() async {
    try {
      debugPrint('🚀 Initialisation des services de notifications...');
      
      final notificationService = ref.read(callNotificationServiceProvider);
      await notificationService.initializeBasicFCM();
      
      debugPrint('✅ Services de notifications de base initialisés');
    } catch (e) {
      debugPrint('❌ Erreur initialisation services notifications: $e');
    }
  }

  // ✅ INITIALISER LES SERVICES COMPLETS APRÈS CONNEXION
  Future<void> _initializeFullServices() async {
    try {
      debugPrint('🚀 Initialisation des services complets...');
      
      await ref.read(callNotificationServiceProvider).initialize();
      ref.read(callProvider.notifier);
      
      debugPrint('✅ Services d\'appels complets initialisés');
    } catch (e) {
      debugPrint('❌ Erreur initialisation services complets: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ ÉCOUTER LES CHANGEMENTS D'AUTHENTIFICATION
    ref.listen(authServiceProvider, (previous, next) async {
      final previousUser = previous?.user;
      final currentUser = next.user;
      
      if (currentUser != null && previousUser == null) {
        // Utilisateur vient de se connecter
        debugPrint('👤 Utilisateur connecté: ${currentUser.name}');
        await _initializeFullServices();
      } else if (currentUser == null && previousUser != null) {
        // Utilisateur vient de se déconnecter
        debugPrint('👤 Utilisateur déconnecté');
        try {
          await ref.read(callNotificationServiceProvider).clearUserFCMToken();
        } catch (e) {
          debugPrint('❌ Erreur nettoyage token: $e');
        }
      }
    });

    // ✅ ÉCOUTER LES APPELS ENTRANTS GLOBALEMENT
    ref.listen(incomingCallProvider, (previous, next) {
      // L'écoute est gérée automatiquement par le CallNotifier
    });

    return MaterialApp(
      title: 'Lovingo',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const LoginScreen(),
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const LoginScreen(),
      },
    );
  }

  // ✅ GÉRER LES CHANGEMENTS D'ÉTAT DE L'APP
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('📱 App resumed - réactiver services');
        _reactivateServices();
        break;
      case AppLifecycleState.paused:
        debugPrint('📱 App paused - maintenir écoute appels');
        break;
      case AppLifecycleState.detached:
        debugPrint('📱 App detached');
        break;
      case AppLifecycleState.inactive:
        debugPrint('📱 App inactive');
        break;
      case AppLifecycleState.hidden:
        debugPrint('📱 App hidden');
        break;
    }
  }

  Future<void> _reactivateServices() async {
    try {
      await ref.read(callNotificationServiceProvider).updateUserFCMToken();
    } catch (e) {
      debugPrint('❌ Erreur réactivation services: $e');
    }
  }
}