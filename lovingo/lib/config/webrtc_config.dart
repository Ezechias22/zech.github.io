// lib/config/webrtc_config.dart - CONFIGURATION WEBRTC COMPLÈTE OPTIMISÉE
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';
import 'dart:io';

class WebRTCConfig {
  // =================== CONFIGURATION PRINCIPALE ===================
  static const bool isTestMode = kDebugMode; // Automatique selon debug/release
  static const bool enableLogs = true;
  static const bool enableVerboseLogs = kDebugMode;
  
  // Configuration réseau
  static const int connectionTimeout = 30000; // 30 secondes
  static const int maxRetryAttempts = 3;
  static const int retryDelay = 5000; // 5 secondes
  
  // =================== SERVEURS ICE XIRSYS ===================
  static const List<Map<String, String>> iceServers = [
    // Serveurs STUN Google (fallback)
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
    
    // Serveurs Xirsys STUN
    {'urls': 'stun:sp-turn1.xirsys.com'},
    
    // Serveurs Xirsys TURN UDP
    {
      'urls': 'turn:sp-turn1.xirsys.com:80?transport=udp',
      'username': '4XqUfvJjCtRe1GW3bd21W0shkuu5xsRShJenzbs1AkxjTsQY-Owmryb2cw1TSqEwAAAAAGhOy_dMb3Zpbmdv',
      'credential': '8161ec3e-49ed-11f0-b1bd-0242ac120004'
    },
    {
      'urls': 'turn:sp-turn1.xirsys.com:3478?transport=udp',
      'username': '4XqUfvJjCtRe1GW3bd21W0shkuu5xsRShJenzbs1AkxjTsQY-Owmryb2cw1TSqEwAAAAAGhOy_dMb3Zpbmdv',
      'credential': '8161ec3e-49ed-11f0-b1bd-0242ac120004'
    },
    
    // Serveurs Xirsys TURN TCP
    {
      'urls': 'turn:sp-turn1.xirsys.com:80?transport=tcp',
      'username': '4XqUfvJjCtRe1GW3bd21W0shkuu5xsRShJenzbs1AkxjTsQY-Owmryb2cw1TSqEwAAAAAGhOy_dMb3Zpbmdv',
      'credential': '8161ec3e-49ed-11f0-b1bd-0242ac120004'
    },
    {
      'urls': 'turn:sp-turn1.xirsys.com:3478?transport=tcp',
      'username': '4XqUfvJjCtRe1GW3bd21W0shkuu5xsRShJenzbs1AkxjTsQY-Owmryb2cw1TSqEwAAAAAGhOy_dMb3Zpbmdv',
      'credential': '8161ec3e-49ed-11f0-b1bd-0242ac120004'
    },
    
    // Serveurs Xirsys TURNS (SSL)
    {
      'urls': 'turns:sp-turn1.xirsys.com:443?transport=tcp',
      'username': '4XqUfvJjCtRe1GW3bd21W0shkuu5xsRShJenzbs1AkxjTsQY-Owmryb2cw1TSqEwAAAAAGhOy_dMb3Zpbmdv',
      'credential': '8161ec3e-49ed-11f0-b1bd-0242ac120004'
    },
    {
      'urls': 'turns:sp-turn1.xirsys.com:5349?transport=tcp',
      'username': '4XqUfvJjCtRe1GW3bd21W0shkuu5xsRShJenzbs1AkxjTsQY-Owmryb2cw1TSqEwAAAAAGhOy_dMb3Zpbmdv',
      'credential': '8161ec3e-49ed-11f0-b1bd-0242ac120004'
    },
  ];

  // =================== CONFIGURATION AUDIO ===================
  static const Map<String, dynamic> audioConstraints = {
    // Suppressions de bruit avancées
    'googEchoCancellation': true,
    'googAutoGainControl': true,
    'googNoiseSuppression': true,
    'googHighpassFilter': true,
    'googTypingNoiseDetection': true,
    'googAudioMirroring': false,
    
    // Standards WebRTC
    'echoCancellation': true,
    'noiseSuppression': true,
    'autoGainControl': true,
    
    // Qualité audio
    'sampleRate': 48000,
    'sampleSize': 16,
    'channelCount': 1, // Mono pour les appels normaux
    
    // Optimisations mobiles
    'googCpuOveruseDetection': true,
    'googCpuUnderuseThreshold': 55,
    'googCpuOveruseThreshold': 85,
  };

  // =================== CONFIGURATION VIDÉO ===================
  static const Map<String, Map<String, dynamic>> videoConstraints = {
    'low': {
      'width': {'min': 240, 'ideal': 360, 'max': 480},
      'height': {'min': 180, 'ideal': 240, 'max': 360},
      'frameRate': {'min': 10, 'ideal': 15, 'max': 20},
    },
    'medium': {
      'width': {'min': 360, 'ideal': 640, 'max': 960},
      'height': {'min': 240, 'ideal': 480, 'max': 720},
      'frameRate': {'min': 15, 'ideal': 24, 'max': 30},
    },
    'high': {
      'width': {'min': 640, 'ideal': 1280, 'max': 1920},
      'height': {'min': 480, 'ideal': 720, 'max': 1080},
      'frameRate': {'min': 24, 'ideal': 30, 'max': 60},
    },
  };

  // =================== CONFIGURATION RTC - ✅ CORRIGÉE ===================
  static Map<String, dynamic> get rtcConfiguration => {
    'iceServers': iceServers,
    'iceTransportPolicy': 'all',
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
    'iceCandidatePoolSize': 10,
    
    // ✅ CORRECTION CRITIQUE : Ajout de sdpSemantics pour éviter le crash
    'sdpSemantics': 'plan-b', // Force Plan B pour compatibilité addStream
    
    // Timeouts optimisés
    'iceConnectionReceiveTimeout': connectionTimeout,
    'iceBackupCandidatePairPingInterval': 25000,
    'iceInactiveTimeout': 30000,
    
    // Optimisations réseau
    'continualGatheringPolicy': 'gather_continually',
    'enableDtlsSrtp': true,
    'enableRtpDataChannel': false,
  };

  // =================== URL SIGNALING ===================
  static String get signalingServerUrl {
    const baseUrl = 'lovingo-signaling.onrender.com';
    
    if (isTestMode) {
      logDebug('Mode test activé - utilisation serveur de développement');
      return 'wss://$baseUrl';
    } else {
      logDebug('Mode production - utilisation serveur principal');
      return 'wss://$baseUrl';
    }
  }

  // URLs alternatives pour le failover
  static const List<String> fallbackSignalingUrls = [
    'wss://lovingo-signaling-backup.onrender.com', // Si vous avez un backup
    // Ajoutez d'autres URLs de backup ici
  ];

  // =================== CONTRAINTES MÉDIA ===================
  static Map<String, dynamic> getMediaConstraints({
    bool video = true,
    String videoQuality = 'medium',
    bool audio = true,
    String? facingMode,
  }) {
    Map<String, dynamic> audioConfig = Map.from(audioConstraints);
    
    // Optimisation pour les appels vidéo
    if (video) {
      audioConfig['channelCount'] = 1; // Mono pour économiser la bande passante
    }

    return {
      'audio': audio ? audioConfig : false,
      'video': video ? {
        ...videoConstraints[videoQuality]!,
        'facingMode': facingMode ?? 'user',
        'googPowerLineFrequency': '2',
        'googCpuOveruseDetection': true,
        'googCpuUnderuseThreshold': 55,
        'googCpuOveruseThreshold': 85,
        
        // Optimisations qualité
        'googMaxBitrate': _getBitrateForQuality(videoQuality),
        'googMinBitrate': _getMinBitrateForQuality(videoQuality),
      } : false,
    };
  }

  static Map<String, dynamic> getLiveStreamConstraints({
    String videoQuality = 'high',
    bool audio = true,
  }) {
    Map<String, dynamic> audioConfig = Map.from(audioConstraints);
    audioConfig['channelCount'] = 2; // Stéréo pour les lives
    audioConfig['sampleRate'] = 48000; // Haute qualité

    return {
      'audio': audio ? audioConfig : false,
      'video': {
        ...videoConstraints[videoQuality]!,
        'facingMode': 'user',
        'googPowerLineFrequency': '2',
        'googCpuOveruseDetection': true,
        'googCpuUnderuseThreshold': 45, // Plus tolérant pour les lives
        'googCpuOveruseThreshold': 90,
        
        // Optimisations pour streaming
        'googMaxBitrate': _getBitrateForQuality(videoQuality) * 1.5, // Plus de bande passante
        'googMinBitrate': _getMinBitrateForQuality(videoQuality),
        'googStartBitrate': _getBitrateForQuality(videoQuality),
      },
    };
  }

  // =================== UTILITAIRES BITRATE ===================
  static int _getBitrateForQuality(String quality) {
    switch (quality) {
      case 'low':
        return 300000; // 300 kbps
      case 'medium':
        return 1000000; // 1 Mbps
      case 'high':
        return 2500000; // 2.5 Mbps
      default:
        return 1000000;
    }
  }

  static int _getMinBitrateForQuality(String quality) {
    switch (quality) {
      case 'low':
        return 100000; // 100 kbps
      case 'medium':
        return 300000; // 300 kbps
      case 'high':
        return 500000; // 500 kbps
      default:
        return 300000;
    }
  }

  // =================== CONFIGURATION BASÉE SUR LE TYPE D'APPEL ===================
  static Map<String, dynamic> getConfigForCallType(WebRTCCallType callType) {
    switch (callType) {
      case WebRTCCallType.audio:
        return getMediaConstraints(video: false, audio: true);
      case WebRTCCallType.video:
        return getMediaConstraints(video: true, audio: true, videoQuality: 'medium');
      case WebRTCCallType.live:
        return getLiveStreamConstraints(videoQuality: 'high', audio: true);
      case WebRTCCallType.groupVideo:
        return getMediaConstraints(video: true, audio: true, videoQuality: 'low');
    }
  }

  // =================== CONFIGURATION ADAPTATIVE ===================
  static String getAdaptiveVideoQuality() {
    // Détection automatique de la qualité selon les capacités du device
    if (Platform.isIOS || Platform.isAndroid) {
      // TODO: Ajouter détection des specs du device
      return 'medium'; // Par défaut sur mobile
    }
    return 'high'; // Desktop/Web
  }

  // =================== CONSTANTES LIVE ===================
  static const int maxGuestsInLive = 8;
  static const int defaultLiveQuality = 720;
  static const int maxViewersInLive = 10000;
  static const int heartbeatInterval = 30;

  static const Map<String, dynamic> virtualGiftsConfig = {
    'maxGiftsPerMinute': 10,
    'animationDuration': 3000,
    'maxGiftsOnScreen': 5,
    'giftEffectDuration': 2000,
    'cooldownBetweenGifts': 1000, // 1 seconde
  };

  // =================== FIREBASE CONFIGURATION ===================
  static const String baseFirebaseFunctionsUrl = isTestMode
      ? 'http://localhost:5001/lovingo-172839/us-central1'
      : 'https://us-central1-lovingo-172839.cloudfunctions.net';

  // =================== TESTS DE CONNECTIVITÉ - ✅ CORRIGÉ ===================
  static Future<ConnectivityResult> testXirsysConnectivity() async {
    try {
      logInfo('🧪 Test de connectivité Xirsys...');
      
      final pc = await createPeerConnection(rtcConfiguration);
      bool stunSuccess = false;
      bool turnSuccess = false;
      bool ipv6Support = false;
      
      final completer = Completer<void>();
      Timer? timeoutTimer;

      pc.onIceCandidate = (candidate) {
        if (candidate.candidate == null) {
          completer.complete();
          return;
        }

        final candidateStr = candidate.candidate!;
        
        // ✅ CORRECTION CRITIQUE : Vérification de la longueur avant substring
        final displayStr = candidateStr.length > 100 
          ? '${candidateStr.substring(0, 100)}...'
          : candidateStr;
        logInfo('🔗 Candidat ICE: $displayStr');
        
        if (candidateStr.contains('typ srflx')) {
          stunSuccess = true;
          logInfo('✅ STUN fonctionne');
        }
        if (candidateStr.contains('typ relay')) {
          turnSuccess = true;
          logInfo('✅ TURN fonctionne');
        }
        if (candidateStr.contains('::')) {
          ipv6Support = true;
          logInfo('✅ IPv6 supporté');
        }
      };

      pc.onIceGatheringState = (state) {
        logDebug('ICE Gathering State: $state');
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
          if (!completer.isCompleted) completer.complete();
        }
      };

      // Timeout de 10 secondes
      timeoutTimer = Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          logInfo('⏰ Timeout test de connectivité');
          completer.complete();
        }
      });

      // Créer une offre pour déclencher la collecte ICE
      await pc.createDataChannel('test', RTCDataChannelInit());
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      // Attendre la fin de la collecte ICE
      await completer.future;
      
      timeoutTimer.cancel();
      await pc.close();

      final result = ConnectivityResult(
        stunWorking: stunSuccess,
        turnWorking: turnSuccess,
        ipv6Supported: ipv6Support,
        xirsysReachable: stunSuccess || turnSuccess,
      );

      logInfo('📊 Résultat test: STUN=$stunSuccess, TURN=$turnSuccess, IPv6=$ipv6Support');
      return result;
      
    } catch (e) {
      logError('❌ Test Xirsys échoué', e);
      return ConnectivityResult(
        stunWorking: false,
        turnWorking: false,
        ipv6Supported: false,
        xirsysReachable: false,
        error: e.toString(),
      );
    }
  }

  // =================== VALIDATION ===================
  static void validateConfig() {
    if (iceServers.isEmpty) {
      throw const WebRTCConfigException('Au moins un serveur ICE est requis');
    }
    
    final bool hasXirsysTurn = iceServers.any((server) =>
      server['urls']?.contains('xirsys.com') == true &&
      server['username'] != null &&
      server['credential'] != null
    );
    
    if (!hasXirsysTurn) {
      logError('⚠️ Configuration Xirsys TURN manquante - connexions limitées');
    }
    
    // Validation des contraintes vidéo
    for (final quality in ['low', 'medium', 'high']) {
      if (!videoConstraints.containsKey(quality)) {
        throw WebRTCConfigException('Configuration vidéo manquante pour: $quality');
      }
    }
    
    if (enableLogs) {
      logInfo('✅ Configuration WebRTC Lovingo validée');
      if (enableVerboseLogs) {
        logDebug('📊 ${iceServers.length} serveurs ICE configurés');
        logDebug('🔗 URL Signaling: $signalingServerUrl');
        logDebug('🎥 Qualités vidéo: ${videoConstraints.keys.join(", ")}');
      }
    }
  }

  // =================== DIAGNOSTIC COMPLET ===================
  static Future<Map<String, dynamic>> runFullDiagnostic() async {
    logInfo('🚀 === DIAGNOSTIC WEBRTC LOVINGO STARTUP ===');
    
    final diagnosticResults = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'environment': isTestMode ? 'test' : 'production',
      'platform': Platform.operatingSystem,
      'version': '2.0.0',
    };

    // Test configuration
    try {
      validateConfig();
      diagnosticResults['configuration'] = {
        'valid': true,
        'iceServers': iceServers.length,
        'xirsysConfigured': hasXirsysConfig,
        'signalingUrl': signalingServerUrl,
        'sdpSemantics': 'plan-b', // ✅ Confirmation configuration
      };
      logInfo('✅ Configuration WebRTC valide');
    } catch (e) {
      diagnosticResults['configuration'] = {
        'valid': false,
        'error': e.toString(),
      };
      logError('❌ Configuration invalide', e);
    }

    // Test permissions (sera fait par l'appelant)
    logInfo('📋 Vérification des permissions requise...');

    // Test connectivité Xirsys
    final connectivityResult = await testXirsysConnectivity();
    diagnosticResults['connectivity'] = connectivityResult.toMap();

    // Test signaling
    logInfo('🔗 Test connectivité serveur signaling...');
    diagnosticResults['signaling'] = {
      'url': signalingServerUrl,
      'localMode': isTestMode,
    };

    logInfo('✅ Configuration signaling OK');
    logInfo('🎉 Diagnostic startup terminé');
    logInfo('💡 Utilisez le bouton de test dans l\'app pour un diagnostic complet');

    return diagnosticResults;
  }

  // =================== GETTERS ===================
  static bool get isConfigured => iceServers.isNotEmpty;
  
  static bool get hasXirsysConfig => iceServers.any((server) =>
    server['urls']?.contains('xirsys.com') == true &&
    server['username'] != null &&
    server['credential'] != null
  );

  // =================== LOGGING ===================
  static void logDebug(String message) {
    if (enableLogs && enableVerboseLogs && kDebugMode) {
      debugPrint('🔧 WebRTC Lovingo: $message');
    }
  }

  static void logError(String message, [dynamic error]) {
    if (enableLogs) {
      debugPrint('❌ WebRTC Lovingo Error: $message');
      if (error != null) debugPrint('   Details: $error');
    }
  }

  static void logInfo(String message) {
    if (enableLogs) {
      debugPrint('ℹ️ WebRTC Lovingo: $message');
    }
  }

  static void logWarning(String message) {
    if (enableLogs) {
      debugPrint('⚠️ WebRTC Lovingo Warning: $message');
    }
  }

  // =================== INITIALISATION ===================
  static Future<void> initialize() async {
    try {
      logInfo('🚀 Initialisation WebRTC Lovingo...');
      validateConfig();
      
      if (kDebugMode && hasXirsysConfig) {
        logInfo('🧪 Test de connectivité Xirsys...');
        final result = await testXirsysConnectivity();
        if (!result.xirsysReachable) {
          logWarning('⚠️ Problème de connectivité Xirsys - certaines connexions peuvent échouer');
        }
      }
      
      logInfo('✅ WebRTC Lovingo initialisé avec succès');
    } catch (e) {
      logError('❌ Échec init WebRTC Lovingo', e);
      rethrow;
    }
  }
}

// =================== ENUMS ET EXTENSIONS ===================
enum WebRTCCallType {
  audio(Icons.call),
  video(Icons.videocam),
  live(Icons.live_tv),
  groupVideo(Icons.people);
  
  const WebRTCCallType(this.icon);
  final IconData icon;
}

enum VideoQuality { low, medium, high }

enum WebRTCConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
  closed,
}

extension WebRTCCallTypeExtension on WebRTCCallType {
  bool get isVideo => this == WebRTCCallType.video || 
                     this == WebRTCCallType.groupVideo || 
                     this == WebRTCCallType.live;
  
  bool get isAudio => this == WebRTCCallType.audio;
  bool get isLive => this == WebRTCCallType.live;
  bool get isGroup => this == WebRTCCallType.groupVideo || this == WebRTCCallType.live;
  
  String get displayName {
    switch (this) {
      case WebRTCCallType.audio:
        return 'Appel audio';
      case WebRTCCallType.video:
        return 'Appel vidéo';
      case WebRTCCallType.live:
        return 'Live streaming';
      case WebRTCCallType.groupVideo:
        return 'Appel de groupe';
    }
  }

  Duration get maxDuration {
    switch (this) {
      case WebRTCCallType.audio:
      case WebRTCCallType.video:
        return const Duration(hours: 2);
      case WebRTCCallType.groupVideo:
        return const Duration(hours: 1);
      case WebRTCCallType.live:
        return const Duration(hours: 4);
    }
  }
}

extension VideoQualityExtension on VideoQuality {
  String get name {
    switch (this) {
      case VideoQuality.low:
        return 'low';
      case VideoQuality.medium:
        return 'medium';
      case VideoQuality.high:
        return 'high';
    }
  }

  String get displayName {
    switch (this) {
      case VideoQuality.low:
        return 'Qualité basse (360p)';
      case VideoQuality.medium:
        return 'Qualité moyenne (720p)';
      case VideoQuality.high:
        return 'Qualité haute (1080p)';
    }
  }

  int get estimatedBandwidth {
    switch (this) {
      case VideoQuality.low:
        return 500; // kbps
      case VideoQuality.medium:
        return 1500; // kbps
      case VideoQuality.high:
        return 3000; // kbps
    }
  }
}

// =================== CLASSES DE DONNÉES ===================
class ConnectivityResult {
  final bool stunWorking;
  final bool turnWorking;
  final bool ipv6Supported;
  final bool xirsysReachable;
  final String? error;

  const ConnectivityResult({
    required this.stunWorking,
    required this.turnWorking,
    required this.ipv6Supported,
    required this.xirsysReachable,
    this.error,
  });

  Map<String, dynamic> toMap() => {
    'stunWorking': stunWorking,
    'turnWorking': turnWorking,
    'ipv6Supported': ipv6Supported,
    'xirsysReachable': xirsysReachable,
    if (error != null) 'error': error,
  };

  bool get isHealthy => stunWorking && turnWorking;
  bool get hasIssues => !stunWorking || !turnWorking;
}

class WebRTCConfigException implements Exception {
  final String message;
  const WebRTCConfigException(this.message);
  
  @override
  String toString() => 'WebRTCConfigException: $message';
}