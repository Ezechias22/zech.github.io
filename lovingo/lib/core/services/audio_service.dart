// lib/core/services/audio_service.dart - SERVICE AUDIO POUR SONS D'APPEL - CORRIGÉ SANS AUDIOPLAYERS
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/webrtc_config.dart';

class AudioService {
  static AudioService? _instance;
  static AudioService get instance => _instance ??= AudioService._();
  
  AudioService._();

  // État des sons
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  double _volume = 0.8;
  
  // Timers
  Timer? _ringtoneTimer;
  
  // État de lecture
  bool _isPlayingRingtone = false;
  bool _isPlayingEffect = false;
  bool _isPlayingNotification = false;
  
  // ✅ INITIALISER LE SERVICE AUDIO
  Future<void> initialize() async {
    try {
      // En mode démo/développement, pas besoin de vraies librairies audio
      WebRTCConfig.logInfo('✅ Service audio initialisé (mode démo)');
    } catch (e) {
      WebRTCConfig.logError('Erreur initialisation audio', e);
    }
  }

  // ✅ JOUER UN SON D'ACTION (SIMULATION)
  Future<void> playActionSound(AudioAction action) async {
    try {
      if (!_soundEnabled) return;
      
      // Marquer le bon état de lecture selon le type
      switch (action) {
        case AudioAction.callIncoming:
        case AudioAction.callOutgoing:
          _isPlayingRingtone = true;
          _startRingtoneTimer(action);
          break;
        case AudioAction.notification:
        case AudioAction.giftReceived:
        case AudioAction.newMessage:
          _isPlayingNotification = true;
          // Arrêter automatiquement après 2 secondes
          Timer(const Duration(seconds: 2), () {
            _isPlayingNotification = false;
          });
          break;
        default:
          _isPlayingEffect = true;
          // Arrêter automatiquement après 1 seconde
          Timer(const Duration(seconds: 1), () {
            _isPlayingEffect = false;
          });
      }
      
      // Vibration pour certains sons
      if (_vibrationEnabled && _shouldVibrate(action)) {
        _vibrate(action);
      }
      
      WebRTCConfig.logInfo('🔊 Son joué (simulation): ${action.name}');
    } catch (e) {
      WebRTCConfig.logError('Erreur lecture son', e);
      // Fallback avec vibration seulement
      if (_vibrationEnabled && _shouldVibrate(action)) {
        _vibrate(action);
      }
    }
  }

  // ✅ JOUER SONNERIE (APPELÉ PAR LES ÉCRANS D'APPELS)
  Future<void> playRingtone() async {
    await playActionSound(AudioAction.callIncoming);
  }

  // ✅ JOUER SON D'ACCEPTATION D'APPEL (APPELÉ PAR LES ÉCRANS)
  Future<void> playCallAcceptSound() async {
    await stopRingtone(); // Arrêter la sonnerie d'abord
    await playActionSound(AudioAction.callAccept);
  }

  // ✅ JOUER SON DE REFUS D'APPEL (APPELÉ PAR LES ÉCRANS)
  Future<void> playCallDeclineSound() async {
    await stopRingtone(); // Arrêter la sonnerie d'abord
    await playActionSound(AudioAction.callDecline);
  }

  // ✅ ARRÊTER TOUS LES SONS
  Future<void> stopAll() async {
    try {
      _ringtoneTimer?.cancel();
      _isPlayingRingtone = false;
      _isPlayingEffect = false;
      _isPlayingNotification = false;
      
      WebRTCConfig.logInfo('🔇 Tous les sons arrêtés');
    } catch (e) {
      WebRTCConfig.logError('Erreur arrêt sons', e);
    }
  }

  // ✅ ARRÊTER LA SONNERIE SPÉCIFIQUEMENT
  Future<void> stopRingtone() async {
    try {
      _ringtoneTimer?.cancel();
      _isPlayingRingtone = false;
      WebRTCConfig.logInfo('🔇 Sonnerie arrêtée');
    } catch (e) {
      WebRTCConfig.logError('Erreur arrêt sonnerie', e);
    }
  }

  // ✅ JOUER SON DE RÉUSSITE
  Future<void> playSuccessSound() async {
    await playActionSound(AudioAction.success);
  }

  // ✅ JOUER SON D'ERREUR
  Future<void> playErrorSound() async {
    await playActionSound(AudioAction.error);
  }

  // ✅ JOUER SON DE NOTIFICATION
  Future<void> playNotificationSound() async {
    await playActionSound(AudioAction.notification);
  }

  // ✅ OBTENIR LE CHEMIN DU FICHIER AUDIO (POUR RÉFÉRENCE)
  String? _getSoundPath(AudioAction action) {
    switch (action) {
      case AudioAction.callIncoming:
        return 'sounds/incoming_call.mp3';
      case AudioAction.callOutgoing:
        return 'sounds/outgoing_call.mp3';
      case AudioAction.callAccept:
        return 'sounds/call_accept.mp3';
      case AudioAction.callDecline:
        return 'sounds/call_decline.mp3';
      case AudioAction.callEnd:
        return 'sounds/call_end.mp3';
      case AudioAction.buttonTap:
        return 'sounds/button_tap.mp3';
      case AudioAction.notification:
        return 'sounds/notification.mp3';
      case AudioAction.newMessage:
        return 'sounds/new_message.mp3';
      case AudioAction.giftReceived:
        return 'sounds/gift_received.mp3';
      case AudioAction.giftSent:
        return 'sounds/gift_sent.mp3';
      case AudioAction.liveStart:
        return 'sounds/live_start.mp3';
      case AudioAction.liveEnd:
        return 'sounds/live_end.mp3';
      case AudioAction.userJoined:
        return 'sounds/user_joined.mp3';
      case AudioAction.userLeft:
        return 'sounds/user_left.mp3';
      case AudioAction.success:
        return 'sounds/success.mp3';
      case AudioAction.error:
        return 'sounds/error.mp3';
      case AudioAction.warning:
        return 'sounds/warning.mp3';
      case AudioAction.combo:
        return 'sounds/combo.mp3';
      case AudioAction.achievement:
        return 'sounds/achievement.mp3';
    }
  }

  // ✅ DÉMARRER LE TIMER DE SONNERIE
  void _startRingtoneTimer(AudioAction action) {
    _ringtoneTimer?.cancel();
    
    // Arrêter automatiquement après 30 secondes
    _ringtoneTimer = Timer(const Duration(seconds: 30), () {
      stopRingtone();
    });
  }

  // ✅ VÉRIFIER SI DOIT VIBRER
  bool _shouldVibrate(AudioAction action) {
    return [
      AudioAction.callIncoming,
      AudioAction.callOutgoing,
      AudioAction.callAccept,
      AudioAction.callDecline,
      AudioAction.notification,
      AudioAction.giftReceived,
      AudioAction.error,
      AudioAction.warning,
    ].contains(action);
  }

  // ✅ DÉCLENCHER LA VIBRATION
  void _vibrate(AudioAction action) {
    try {
      switch (action) {
        case AudioAction.callIncoming:
        case AudioAction.callOutgoing:
          // Vibration longue pour les appels
          HapticFeedback.heavyImpact();
          Timer(const Duration(milliseconds: 500), () {
            if (_isPlayingRingtone) {
              HapticFeedback.heavyImpact();
            }
          });
          break;
        case AudioAction.callAccept:
          // Vibration de confirmation
          HapticFeedback.mediumImpact();
          Timer(const Duration(milliseconds: 100), () {
            HapticFeedback.lightImpact();
          });
          break;
        case AudioAction.callDecline:
          // Vibration de refus
          HapticFeedback.heavyImpact();
          break;
        case AudioAction.notification:
        case AudioAction.giftReceived:
          // Vibration moyenne pour les notifications
          HapticFeedback.mediumImpact();
          break;
        case AudioAction.error:
        case AudioAction.warning:
          // Vibration forte pour les erreurs
          HapticFeedback.heavyImpact();
          break;
        default:
          // Vibration légère pour les autres actions
          HapticFeedback.lightImpact();
      }
    } catch (e) {
      WebRTCConfig.logError('Erreur vibration', e);
    }
  }

  // ✅ CONFIGURER LE VOLUME
  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);
      WebRTCConfig.logInfo('🔊 Volume défini: $_volume');
    } catch (e) {
      WebRTCConfig.logError('Erreur définition volume', e);
    }
  }

  // ✅ ACTIVER/DÉSACTIVER LES SONS
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
    WebRTCConfig.logInfo('🔊 Sons ${enabled ? 'activés' : 'désactivés'}');
    
    if (!enabled) {
      stopAll();
    }
  }

  // ✅ ACTIVER/DÉSACTIVER LA VIBRATION
  void setVibrationEnabled(bool enabled) {
    _vibrationEnabled = enabled;
    WebRTCConfig.logInfo('📳 Vibration ${enabled ? 'activée' : 'désactivée'}');
  }

  // ✅ JOUER UNE SÉQUENCE DE SONS (POUR COMBOS)
  Future<void> playComboSequence(int comboLevel) async {
    try {
      if (!_soundEnabled) return;
      
      // Son de base
      await playActionSound(AudioAction.combo);
      
      // Sons supplémentaires selon le niveau
      for (int i = 1; i < comboLevel && i < 5; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        await playActionSound(AudioAction.achievement);
      }
      
      // Vibration spéciale pour les gros combos
      if (_vibrationEnabled && comboLevel >= 3) {
        for (int i = 0; i < comboLevel && i < 5; i++) {
          HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    } catch (e) {
      WebRTCConfig.logError('Erreur séquence combo', e);
    }
  }

  // ✅ JOUER SON AVEC FADE IN/OUT (SIMULATION)
  Future<void> playWithFade({
    required AudioAction action,
    Duration fadeInDuration = const Duration(milliseconds: 500),
    Duration fadeOutDuration = const Duration(milliseconds: 500),
    Duration? totalDuration,
  }) async {
    try {
      if (!_soundEnabled) return;
      
      // Simulation des effets de fade
      WebRTCConfig.logInfo('🎵 Son avec fade: ${action.name}');
      
      // Déclencher l'action
      await playActionSound(action);
      
      // Vibration pour certains sons
      if (_vibrationEnabled && _shouldVibrate(action)) {
        _vibrate(action);
      }
      
      // Simulation du fade out après la durée spécifiée
      if (totalDuration != null) {
        Timer(totalDuration, () {
          WebRTCConfig.logInfo('🎵 Fade out terminé pour: ${action.name}');
        });
      }
    } catch (e) {
      WebRTCConfig.logError('Erreur lecture avec fade', e);
    }
  }

  // ✅ CRÉER UN PROFIL AUDIO PERSONNALISÉ
  Future<void> setAudioProfile(AudioProfile profile) async {
    try {
      switch (profile) {
        case AudioProfile.silent:
          setSoundEnabled(false);
          setVibrationEnabled(false);
          break;
        case AudioProfile.vibrate:
          setSoundEnabled(false);
          setVibrationEnabled(true);
          break;
        case AudioProfile.quiet:
          setSoundEnabled(true);
          setVibrationEnabled(true);
          await setVolume(0.3);
          break;
        case AudioProfile.normal:
          setSoundEnabled(true);
          setVibrationEnabled(true);
          await setVolume(0.8);
          break;
        case AudioProfile.loud:
          setSoundEnabled(true);
          setVibrationEnabled(true);
          await setVolume(1.0);
          break;
      }
      
      WebRTCConfig.logInfo('🎵 Profil audio: ${profile.name}');
    } catch (e) {
      WebRTCConfig.logError('Erreur profil audio', e);
    }
  }

  // ✅ GETTERS
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  double get volume => _volume;

  // ✅ VÉRIFIER SI UN SON EST EN COURS
  bool get isPlayingRingtone => _isPlayingRingtone;
  bool get isPlayingEffect => _isPlayingEffect;
  bool get isPlayingNotification => _isPlayingNotification;

  // ✅ NETTOYAGE
  Future<void> dispose() async {
    try {
      _ringtoneTimer?.cancel();
      _isPlayingRingtone = false;
      _isPlayingEffect = false;
      _isPlayingNotification = false;
      
      WebRTCConfig.logInfo('🔇 Service audio libéré');
    } catch (e) {
      WebRTCConfig.logError('Erreur libération audio', e);
    }
  }
}

// ✅ TYPES D'ACTIONS AUDIO
enum AudioAction {
  // Appels
  callIncoming,
  callOutgoing,
  callAccept,
  callDecline,
  callEnd,
  
  // Interface
  buttonTap,
  notification,
  success,
  error,
  warning,
  
  // Messages et cadeaux
  newMessage,
  giftReceived,
  giftSent,
  
  // Live streaming
  liveStart,
  liveEnd,
  userJoined,
  userLeft,
  
  // Achievements et combos
  combo,
  achievement,
}

// ✅ PROFILS AUDIO
enum AudioProfile {
  silent,   // Pas de son ni vibration
  vibrate,  // Vibration seulement
  quiet,    // Sons faibles
  normal,   // Sons normaux
  loud,     // Sons forts
}

// ✅ EXTENSIONS
extension AudioActionExtension on AudioAction {
  String get displayName {
    switch (this) {
      case AudioAction.callIncoming:
        return 'Appel entrant';
      case AudioAction.callOutgoing:
        return 'Appel sortant';
      case AudioAction.callAccept:
        return 'Appel accepté';
      case AudioAction.callDecline:
        return 'Appel refusé';
      case AudioAction.callEnd:
        return 'Fin d\'appel';
      case AudioAction.buttonTap:
        return 'Clic bouton';
      case AudioAction.notification:
        return 'Notification';
      case AudioAction.success:
        return 'Succès';
      case AudioAction.error:
        return 'Erreur';
      case AudioAction.warning:
        return 'Attention';
      case AudioAction.newMessage:
        return 'Nouveau message';
      case AudioAction.giftReceived:
        return 'Cadeau reçu';
      case AudioAction.giftSent:
        return 'Cadeau envoyé';
      case AudioAction.liveStart:
        return 'Début live';
      case AudioAction.liveEnd:
        return 'Fin live';
      case AudioAction.userJoined:
        return 'Utilisateur rejoint';
      case AudioAction.userLeft:
        return 'Utilisateur parti';
      case AudioAction.combo:
        return 'Combo';
      case AudioAction.achievement:
        return 'Réussite';
    }
  }

  bool get isCallRelated => [
    AudioAction.callIncoming,
    AudioAction.callOutgoing,
    AudioAction.callAccept,
    AudioAction.callDecline,
    AudioAction.callEnd,
  ].contains(this);

  bool get isNotification => [
    AudioAction.notification,
    AudioAction.newMessage,
    AudioAction.giftReceived,
    AudioAction.userJoined,
  ].contains(this);
}

extension AudioProfileExtension on AudioProfile {
  String get displayName {
    switch (this) {
      case AudioProfile.silent:
        return 'Silencieux';
      case AudioProfile.vibrate:
        return 'Vibration';
      case AudioProfile.quiet:
        return 'Discret';
      case AudioProfile.normal:
        return 'Normal';
      case AudioProfile.loud:
        return 'Fort';
    }
  }

  String get description {
    switch (this) {
      case AudioProfile.silent:
        return 'Aucun son ni vibration';
      case AudioProfile.vibrate:
        return 'Vibration uniquement';
      case AudioProfile.quiet:
        return 'Sons faibles avec vibration';
      case AudioProfile.normal:
        return 'Sons normaux avec vibration';
      case AudioProfile.loud:
        return 'Sons forts avec vibration';
    }
  }

  IconData get icon {
    switch (this) {
      case AudioProfile.silent:
        return Icons.volume_off;
      case AudioProfile.vibrate:
        return Icons.vibration;
      case AudioProfile.quiet:
        return Icons.volume_down;
      case AudioProfile.normal:
        return Icons.volume_up;
      case AudioProfile.loud:
        return Icons.volume_up_outlined;
    }
  }
}