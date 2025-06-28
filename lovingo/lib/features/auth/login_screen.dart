import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

// ✅ IMPORTS WEBRTC LOVINGO CORRIGÉS
import '../../core/services/auth_service.dart';
import '../../shared/themes/app_theme.dart';
import '../../config/webrtc_config.dart';
import '../../core/services/webrtc_call_service.dart';
import '../home/home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authServiceProvider, (previous, next) {
      if (next.isAuthenticated) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
      
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      setState(() {
        _isLoading = next.isLoading;
      });
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: AnimationLimiter(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    
                    // Logo et titre
                    AnimationConfiguration.staggeredList(
                      position: 0,
                      child: SlideAnimation(
                        verticalOffset: 50,
                        child: FadeInAnimation(
                          child: Column(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 20,
                                      color: Colors.black.withOpacity(0.1),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.favorite,
                                  size: 60,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Lovingo',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Trouvez l\'amour, partagez la joie',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // Formulaire de connexion
                    AnimationConfiguration.staggeredList(
                      position: 1,
                      child: SlideAnimation(
                        verticalOffset: 50,
                        child: FadeInAnimation(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 20,
                                  color: Colors.black.withOpacity(0.1),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Email
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(Icons.email),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Veuillez entrer votre email';
                                    }
                                    if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                      return 'Email invalide';
                                    }
                                    return null;
                                  },
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Mot de passe
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Mot de passe',
                                    prefixIcon: const Icon(Icons.lock),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Veuillez entrer votre mot de passe';
                                    }
                                    if (value.length < 6) {
                                      return 'Le mot de passe doit contenir au moins 6 caractères';
                                    }
                                    return null;
                                  },
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Mot de passe oublié
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _showForgotPasswordDialog,
                                    child: const Text('Mot de passe oublié ?'),
                                  ),
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Bouton connexion
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: _isLoading
                                        ? const CircularProgressIndicator(
                                            color: Colors.white,
                                          )
                                        : const Text(
                                            'Se connecter',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Lien inscription
                    AnimationConfiguration.staggeredList(
                      position: 2,
                      child: SlideAnimation(
                        verticalOffset: 50,
                        child: FadeInAnimation(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Pas encore de compte ? ',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const RegisterScreen(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'S\'inscrire',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // ✅ SECTION DEBUG - DIAGNOSTIC WEBRTC (SEULEMENT EN MODE DEBUG)
                    if (kDebugMode) ...[
                      const SizedBox(height: 40),
                      AnimationConfiguration.staggeredList(
                        position: 3,
                        child: SlideAnimation(
                          verticalOffset: 50,
                          child: FadeInAnimation(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.build,
                                        color: Colors.white.withOpacity(0.8),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Outils de développement',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // ✅ BOUTON DE DIAGNOSTIC WEBRTC CORRIGÉ
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _runWebRTCDiagnostic,
                                      icon: const Icon(Icons.phone, size: 18),
                                      label: const Text(
                                        'Tester Configuration WebRTC',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.withOpacity(0.8),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 8),
                                  Text(
                                    'Vérifiez que les appels WebRTC audio/vidéo sont configurés correctement',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ MÉTHODE POUR EXÉCUTER LE DIAGNOSTIC WEBRTC - CORRIGÉE
  void _runWebRTCDiagnostic() async {
    // Capturer la référence Navigator avant l'opération async
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    
    // Afficher dialog de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('🔍 Test de configuration en cours...'),
            SizedBox(height: 8),
            Text(
              'Vérification des appels WebRTC audio/vidéo',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      // Exécuter le diagnostic complet
      final success = await _performWebRTCDiagnostic();
      
      // ✅ CORRECTION : Vérifier mounted avant utilisation de context
      if (!mounted) return;
      
      // Fermer le dialog de chargement
      navigator.pop();
      
      // ✅ CORRECTION : Vérifier mounted à nouveau
      if (!mounted) return;
      
      // Afficher le résultat
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: success ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(success ? 'Configuration OK ✅' : 'Problème détecté ❌'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                success 
                  ? '🎉 Votre configuration WebRTC est correcte !\n\n'
                    '✅ Xirsys TURN opérationnel\n'
                    '✅ Permissions accordées\n'
                    '✅ Configuration validée\n\n'
                    'Vous pouvez maintenant utiliser les appels audio et vidéo dans l\'application.'
                  : '⚠️ Il y a un problème avec la configuration des appels.\n\n'
                    'Vérifiez:\n'
                    '• Les permissions microphone/caméra\n'
                    '• La configuration Xirsys\n'
                    '• La connexion internet\n'
                    '• Les logs dans la console\n\n'
                    'Contactez le support si le problème persiste.',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tests effectués :',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('• Configuration WebRTC'),
                    const Text('• Permissions microphone/caméra'),
                    const Text('• Serveurs STUN/TURN Xirsys'),
                    const Text('• Génération de contraintes médias'),
                    if (success) const Text('• Test de connectivité ICE'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
            if (!success)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Relancer le diagnostic
                  _runWebRTCDiagnostic();
                },
                child: const Text('Réessayer'),
              ),
          ],
        ),
      );
    } catch (e) {
      // ✅ CORRECTION : Vérifier mounted avant utilisation de context
      if (!mounted) return;
      
      navigator.pop(); // Fermer le dialog de chargement
      
      // ✅ CORRECTION : Vérifier mounted à nouveau
      if (!mounted) return;
      
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur pendant le diagnostic: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ DIAGNOSTIC WEBRTC COMPLET - CORRIGÉ (LIGNE 545)
  Future<bool> _performWebRTCDiagnostic() async {
    debugPrint('🔍 === DIAGNOSTIC WEBRTC COMPLET DEPUIS LOGIN ===');
    
    try {
      // Test 1: Configuration WebRTC
      debugPrint('📋 Test 1: Configuration WebRTC');
      debugPrint('   Configuré: ${WebRTCConfig.isConfigured}');
      debugPrint('   Xirsys configuré: ${WebRTCConfig.hasXirsysConfig}');
      debugPrint('   Mode test: ${WebRTCConfig.isTestMode}');
      debugPrint('   Serveurs ICE: ${WebRTCConfig.iceServers.length}');
      
      if (!WebRTCConfig.isConfigured) {
        debugPrint('❌ Configuration WebRTC invalide');
        return false;
      }
      debugPrint('✅ Configuration WebRTC OK');
      
      // Test 2: Permissions
      debugPrint('📋 Test 2: Permissions');
      
      var micStatus = await Permission.microphone.status;
      if (micStatus != PermissionStatus.granted) {
        debugPrint('⚠️ Demande permission microphone...');
        micStatus = await Permission.microphone.request();
      }
      
      var cameraStatus = await Permission.camera.status;
      if (cameraStatus != PermissionStatus.granted) {
        debugPrint('⚠️ Demande permission caméra...');
        cameraStatus = await Permission.camera.request();
      }
      
      debugPrint('   Microphone: $micStatus');
      debugPrint('   Caméra: $cameraStatus');
      
      if (micStatus != PermissionStatus.granted) {
        debugPrint('❌ Permission microphone requise');
        return false;
      }
      debugPrint('✅ Permissions OK');
      
      // Test 3: Service WebRTC - ✅ CORRECTION LIGNE 545
      debugPrint('📋 Test 3: Service WebRTC');
      final webrtcService = ref.read(webrtcCallServiceProvider);
      
      // ✅ CORRECTION : Ajouter userId requis pour initialize()
      final serviceInit = await webrtcService.initialize(
        userId: 'diagnostic_test_user_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      if (!serviceInit) {
        debugPrint('❌ Échec initialisation service WebRTC');
        return false;
      }
      debugPrint('✅ Service WebRTC initialisé');
      
      // Test 4: Configuration des types d'appels
      debugPrint('📋 Test 4: Types d\'appels WebRTC');
      
      try {
        final audioConfig = WebRTCConfig.getConfigForCallType(WebRTCCallType.audio);
        final videoConfig = WebRTCConfig.getConfigForCallType(WebRTCCallType.video);
        final liveConfig = WebRTCConfig.getConfigForCallType(WebRTCCallType.live);
        
        debugPrint('   Audio: ${audioConfig['audio'] != false ? '✅' : '❌'}');
        debugPrint('   Vidéo: ${videoConfig['video'] != false ? '✅' : '❌'}');
        debugPrint('   Live: ${liveConfig['video'] != false ? '✅' : '❌'}');
        
        debugPrint('✅ Configuration types d\'appels OK');
      } catch (e) {
        debugPrint('❌ Erreur configuration appels: $e');
        return false;
      }
      
      // Test 5: Test de connectivité Xirsys (si configuré) - ✅ CORRIGÉ ICI
      if (WebRTCConfig.hasXirsysConfig) {
        debugPrint('📋 Test 5: Connectivité Xirsys');
        try {
          // ✅ CORRECTION : Utiliser la nouvelle API qui retourne ConnectivityResult
          final xirsysResult = await WebRTCConfig.testXirsysConnectivity();
          
          // ✅ CORRECTION : Utiliser .xirsysReachable au lieu de !xirsysTest
          if (!xirsysResult.xirsysReachable) {
            debugPrint('⚠️ Problème connectivité Xirsys - connexions limitées');
            debugPrint('   STUN: ${xirsysResult.stunWorking ? "✅" : "❌"}');
            debugPrint('   TURN: ${xirsysResult.turnWorking ? "✅" : "❌"}');
          } else {
            debugPrint('✅ Xirsys opérationnel');
            debugPrint('   STUN: ${xirsysResult.stunWorking ? "✅" : "❌"}');
            debugPrint('   TURN: ${xirsysResult.turnWorking ? "✅" : "❌"}');
            debugPrint('   IPv6: ${xirsysResult.ipv6Supported ? "✅" : "❌"}');
          }
        } catch (e) {
          debugPrint('⚠️ Erreur test Xirsys: $e');
        }
      }
      
      debugPrint('🎉 === DIAGNOSTIC WEBRTC RÉUSSI ===');
      return true;
      
    } catch (e) {
      debugPrint('❌ Erreur diagnostic: $e');
      return false;
    }
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      // ✅ CORRECTION : Capturer les références avant async
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      
      final success = await ref.read(authServiceProvider.notifier).signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      // ✅ CORRECTION : Vérifier mounted avant utilisation de context
      if (!mounted) return;
      
      if (!success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Erreur de connexion'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mot de passe oublié'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'Entrez votre email',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              // ✅ CORRECTION : Capturer les références avant async
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              
              final success = await ref.read(authServiceProvider.notifier)
                  .resetPassword(emailController.text.trim());
              
              // ✅ CORRECTION : Vérifier mounted avant utilisation de context
              if (!mounted) return;
              
              navigator.pop();
              
              // ✅ CORRECTION : Vérifier mounted à nouveau
              if (!mounted) return;
              
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Email de réinitialisation envoyé'
                        : 'Erreur lors de l\'envoi',
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}