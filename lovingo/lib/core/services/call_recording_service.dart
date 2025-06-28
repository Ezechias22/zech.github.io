// lib/core/services/call_recording_service.dart - SERVICE ENREGISTREMENT D'APPELS
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../config/webrtc_config.dart';
import '../models/call_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

final callRecordingServiceProvider = Provider<CallRecordingService>((ref) {
  return CallRecordingService(ref.read(authServiceProvider as ProviderListenable<AuthService>));
});

class CallRecordingService {
  final AuthService _authService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Recorder et player
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  
  // État de l'enregistrement
  bool _isInitialized = false;
  bool _isRecording = false;
  String? _currentRecordingPath;
  String? _currentRecordingId;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  
  // Streams controllers
  final StreamController<RecordingState> _stateController = StreamController.broadcast();
  final StreamController<Duration> _durationController = StreamController.broadcast();
  final StreamController<double> _amplitudeController = StreamController.broadcast();
  
  // Getters publics
  Stream<RecordingState> get stateStream => _stateController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<double> get amplitudeStream => _amplitudeController.stream;
  
  bool get isRecording => _isRecording;
  bool get isInitialized => _isInitialized;

  CallRecordingService(this._authService);

  // ✅ INITIALISER LE SERVICE D'ENREGISTREMENT
  Future<bool> initialize() async {
    try {
      if (_isInitialized) return true;
      
      _recorder = FlutterSoundRecorder();
      _player = FlutterSoundPlayer();
      
      await _recorder!.openRecorder();
      await _player!.openPlayer();
      
      _isInitialized = true;
      _stateController.add(RecordingState.ready);
      
      WebRTCConfig.logInfo('✅ Service d\'enregistrement initialisé');
      return true;
    } catch (e) {
      WebRTCConfig.logError('Erreur initialisation enregistrement', e);
      return false;
    }
  }

  // ✅ VÉRIFIER LES PERMISSIONS D'ENREGISTREMENT
  Future<bool> checkRecordingPermissions() async {
    try {
      final permissions = await [
        Permission.microphone,
        Permission.storage,
      ].request();
      
      return permissions[Permission.microphone] == PermissionStatus.granted &&
             permissions[Permission.storage] == PermissionStatus.granted;
    } catch (e) {
      WebRTCConfig.logError('Erreur vérification permissions', e);
      return false;
    }
  }

  // ✅ DÉMARRER L'ENREGISTREMENT
  Future<String?> startRecording({
    required String callId,
    required UserModel otherUser,
    required CallType callType,
    RecordingQuality quality = RecordingQuality.high,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (!_isInitialized) {
        final initialized = await initialize();
        if (!initialized) return null;
      }
      
      if (_isRecording) {
        WebRTCConfig.logError('Enregistrement déjà en cours');
        return null;
      }
      
      // Vérifier les permissions
      final hasPermissions = await checkRecordingPermissions();
      if (!hasPermissions) {
        WebRTCConfig.logError('Permissions d\'enregistrement manquantes');
        return null;
      }
      
      // Générer le chemin de fichier
      final recordingId = _generateRecordingId();
      final fileName = 'recording_${recordingId}_${DateTime.now().millisecondsSinceEpoch}.aac';
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      
      // Configuration d'enregistrement
      final codec = Codec.aacADTS;
      final sampleRate = _getSampleRateForQuality(quality);
      
      // Démarrer l'enregistrement
      await _recorder!.startRecorder(
        toFile: filePath,
        codec: codec,
        sampleRate: sampleRate,
        numChannels: 1,
      );
      
      // Mettre à jour l'état
      _isRecording = true;
      _currentRecordingPath = filePath;
      _currentRecordingId = recordingId;
      _recordingStartTime = DateTime.now();
      
      // Démarrer les timers
      _startRecordingTimers();
      
      // Créer l'entrée d'enregistrement dans Firestore
      await _createRecordingEntry(
        recordingId: recordingId,
        callId: callId,
        otherUser: otherUser,
        callType: callType,
        quality: quality,
        metadata: metadata,
      );
      
      _stateController.add(RecordingState.recording);
      
      WebRTCConfig.logInfo('✅ Enregistrement démarré: $recordingId');
      return recordingId;
    } catch (e) {
      WebRTCConfig.logError('Erreur démarrage enregistrement', e);
      return null;
    }
  }

  // ✅ ARRÊTER L'ENREGISTREMENT
  Future<bool> stopRecording(String recordingId) async {
    try {
      if (!_isRecording || _currentRecordingId != recordingId) {
        WebRTCConfig.logError('Pas d\'enregistrement en cours avec cet ID');
        return false;
      }
      
      // Arrêter l'enregistrement
      await _recorder!.stopRecorder();
      
      // Arrêter les timers
      _stopRecordingTimers();
      
      // Calculer la durée
      final duration = _recordingStartTime != null 
          ? DateTime.now().difference(_recordingStartTime!)
          : Duration.zero;
      
      // Uploader le fichier
      final downloadUrl = await _uploadRecording(
        _currentRecordingPath!,
        recordingId,
      );
      
      // Mettre à jour l'entrée Firestore
      await _updateRecordingEntry(
        recordingId: recordingId,
        duration: duration,
        filePath: downloadUrl,
        fileSize: await _getFileSize(_currentRecordingPath!),
      );
      
      // Nettoyer le fichier temporaire
      final file = File(_currentRecordingPath!);
      if (await file.exists()) {
        await file.delete();
      }
      
      // Reset l'état
      _isRecording = false;
      _currentRecordingPath = null;
      _currentRecordingId = null;
      _recordingStartTime = null;
      
      _stateController.add(RecordingState.completed);
      
      WebRTCConfig.logInfo('✅ Enregistrement arrêté: $recordingId');
      return true;
    } catch (e) {
      WebRTCConfig.logError('Erreur arrêt enregistrement', e);
      return false;
    }
  }

  // ✅ LIRE UN ENREGISTREMENT
  Future<bool> playRecording(String recordingId) async {
    try {
      if (!_isInitialized) {
        final initialized = await initialize();
        if (!initialized) return false;
      }
      
      // Récupérer l'URL de l'enregistrement
      final recording = await getRecording(recordingId);
      if (recording == null || recording.filePath == null) {
        WebRTCConfig.logError('Enregistrement introuvable');
        return false;
      }
      
      // Lire depuis l'URL
      await _player!.startPlayer(
        fromURI: recording.filePath,
        codec: Codec.aacADTS,
      );
      
      _stateController.add(RecordingState.playing);
      
      WebRTCConfig.logInfo('✅ Lecture enregistrement: $recordingId');
      return true;
    } catch (e) {
      WebRTCConfig.logError('Erreur lecture enregistrement', e);
      return false;
    }
  }

  // ✅ ARRÊTER LA LECTURE
  Future<void> stopPlayback() async {
    try {
      if (_player != null) {
        await _player!.stopPlayer();
        _stateController.add(RecordingState.ready);
      }
    } catch (e) {
      WebRTCConfig.logError('Erreur arrêt lecture', e);
    }
  }

  // ✅ OBTENIR UN ENREGISTREMENT
  Future<CallRecording?> getRecording(String recordingId) async {
    try {
      final doc = await _firestore
          .collection('call_recordings')
          .doc(recordingId)
          .get();
      
      if (!doc.exists) return null;
      
      return CallRecording.fromFirestore(doc);
    } catch (e) {
      WebRTCConfig.logError('Erreur récupération enregistrement', e);
      return null;
    }
  }

  // ✅ OBTENIR TOUS LES ENREGISTREMENTS D'UN UTILISATEUR
  Future<List<CallRecording>> getUserRecordings({
    int limit = 50,
    CallType? filterType,
  }) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return [];
      
      Query query = _firestore
          .collection('call_recordings')
          .where('participantIds', arrayContains: currentUser.id);
      
      if (filterType != null) {
        query = query.where('callType', isEqualTo: filterType.name);
      }
      
      final snapshot = await query
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs
          .map((doc) => CallRecording.fromFirestore(doc))
          .toList();
    } catch (e) {
      WebRTCConfig.logError('Erreur récupération enregistrements', e);
      return [];
    }
  }

  // ✅ SUPPRIMER UN ENREGISTREMENT
  Future<bool> deleteRecording(String recordingId) async {
    try {
      final recording = await getRecording(recordingId);
      if (recording == null) return false;
      
      // Supprimer le fichier du Storage
      if (recording.filePath != null) {
        try {
          final ref = _storage.refFromURL(recording.filePath!);
          await ref.delete();
        } catch (e) {
          WebRTCConfig.logError('Erreur suppression fichier Storage', e);
        }
      }
      
      // Supprimer l'entrée Firestore
      await _firestore.collection('call_recordings').doc(recordingId).delete();
      
      WebRTCConfig.logInfo('✅ Enregistrement supprimé: $recordingId');
      return true;
    } catch (e) {
      WebRTCConfig.logError('Erreur suppression enregistrement', e);
      return false;
    }
  }

  // ✅ MÉTHODES PRIVÉES

  void _startRecordingTimers() {
    // Timer pour la durée
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_recordingStartTime != null) {
        final duration = DateTime.now().difference(_recordingStartTime!);
        _durationController.add(duration);
      }
    });
    
    // Timer pour l'amplitude (si supporté)
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      
      // Simuler l'amplitude (WebRTC peut fournir les vraies valeurs)
      final amplitude = 0.5 + (DateTime.now().millisecond % 100) / 200;
      _amplitudeController.add(amplitude);
    });
  }

  void _stopRecordingTimers() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  int _getSampleRateForQuality(RecordingQuality quality) {
    switch (quality) {
      case RecordingQuality.low:
        return 16000;
      case RecordingQuality.medium:
        return 32000;
      case RecordingQuality.high:
        return 44100;
    }
  }

  Future<void> _createRecordingEntry({
    required String recordingId,
    required String callId,
    required UserModel otherUser,
    required CallType callType,
    required RecordingQuality quality,
    Map<String, dynamic>? metadata,
  }) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;
    
    final recording = CallRecording(
      id: recordingId,
      callId: callId,
      participantIds: [currentUser.id, otherUser.id],
      callType: callType,
      quality: quality,
      createdAt: DateTime.now(),
      createdBy: currentUser.id,
      status: RecordingStatus.recording,
      metadata: metadata ?? {},
    );
    
    await _firestore
        .collection('call_recordings')
        .doc(recordingId)
        .set(recording.toMap());
  }

  Future<void> _updateRecordingEntry({
    required String recordingId,
    required Duration duration,
    required String? filePath,
    required int fileSize,
  }) async {
    await _firestore
        .collection('call_recordings')
        .doc(recordingId)
        .update({
      'duration': duration.inSeconds,
      'filePath': filePath,
      'fileSize': fileSize,
      'status': RecordingStatus.completed.name,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> _uploadRecording(String localPath, String recordingId) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;
      
      final ref = _storage.ref().child('recordings').child('$recordingId.aac');
      final uploadTask = ref.putFile(file);
      
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      WebRTCConfig.logError('Erreur upload enregistrement', e);
      return null;
    }
  }

  Future<int> _getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      return await file.length();
    } catch (e) {
      return 0;
    }
  }

  String _generateRecordingId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'rec_${timestamp}_$random';
  }

  // ✅ NETTOYAGE
  Future<void> dispose() async {
    try {
      _recordingTimer?.cancel();
      
      if (_isRecording) {
        await _recorder?.stopRecorder();
      }
      
      await _recorder?.closeRecorder();
      await _player?.closePlayer();
      
      _stateController.close();
      _durationController.close();
      _amplitudeController.close();
      
      WebRTCConfig.logInfo('✅ Service d\'enregistrement libéré');
    } catch (e) {
      WebRTCConfig.logError('Erreur libération enregistrement', e);
    }
  }
}

// ✅ MODÈLES DE DONNÉES

class CallRecording {
  final String id;
  final String callId;
  final List<String> participantIds;
  final CallType callType;
  final RecordingQuality quality;
  final DateTime createdAt;
  final String createdBy;
  final RecordingStatus status;
  final Duration? duration;
  final String? filePath;
  final int? fileSize;
  final DateTime? completedAt;
  final Map<String, dynamic> metadata;

  const CallRecording({
    required this.id,
    required this.callId,
    required this.participantIds,
    required this.callType,
    required this.quality,
    required this.createdAt,
    required this.createdBy,
    required this.status,
    this.duration,
    this.filePath,
    this.fileSize,
    this.completedAt,
    required this.metadata,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'callId': callId,
    'participantIds': participantIds,
    'callType': callType.name,
    'quality': quality.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'createdBy': createdBy,
    'status': status.name,
    'duration': duration?.inSeconds,
    'filePath': filePath,
    'fileSize': fileSize,
    'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    'metadata': metadata,
  };

  factory CallRecording.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CallRecording(
      id: doc.id,
      callId: data['callId'] ?? '',
      participantIds: List<String>.from(data['participantIds'] ?? []),
      callType: CallType.values.firstWhere(
        (e) => e.name == data['callType'],
        orElse: () => CallType.audio,
      ),
      quality: RecordingQuality.values.firstWhere(
        (e) => e.name == data['quality'],
        orElse: () => RecordingQuality.medium,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      status: RecordingStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => RecordingStatus.failed,
      ),
      duration: data['duration'] != null ? Duration(seconds: data['duration']) : null,
      filePath: data['filePath'],
      fileSize: data['fileSize'],
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }
}

// ✅ ENUMS

enum RecordingState {
  idle,
  ready,
  recording,
  paused,
  completed,
  playing,
  error,
}

enum RecordingStatus {
  recording,
  completed,
  failed,
  deleted,
}

enum RecordingQuality {
  low,    // 16kHz
  medium, // 32kHz
  high,   // 44.1kHz
}

// ✅ EXTENSIONS

extension RecordingStateExtension on RecordingState {
  String get displayName {
    switch (this) {
      case RecordingState.idle:
        return 'Inactif';
      case RecordingState.ready:
        return 'Prêt';
      case RecordingState.recording:
        return 'Enregistrement';
      case RecordingState.paused:
        return 'Pause';
      case RecordingState.completed:
        return 'Terminé';
      case RecordingState.playing:
        return 'Lecture';
      case RecordingState.error:
        return 'Erreur';
    }
  }

  Color get color {
    switch (this) {
      case RecordingState.idle:
        return Colors.grey;
      case RecordingState.ready:
        return Colors.blue;
      case RecordingState.recording:
        return Colors.red;
      case RecordingState.paused:
        return Colors.orange;
      case RecordingState.completed:
        return Colors.green;
      case RecordingState.playing:
        return Colors.blue;
      case RecordingState.error:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case RecordingState.idle:
        return Icons.radio_button_unchecked;
      case RecordingState.ready:
        return Icons.fiber_manual_record_outlined;
      case RecordingState.recording:
        return Icons.fiber_manual_record;
      case RecordingState.paused:
        return Icons.pause;
      case RecordingState.completed:
        return Icons.check_circle;
      case RecordingState.playing:
        return Icons.play_arrow;
      case RecordingState.error:
        return Icons.error;
    }
  }
}

extension RecordingQualityExtension on RecordingQuality {
  String get displayName {
    switch (this) {
      case RecordingQuality.low:
        return 'Basse (16kHz)';
      case RecordingQuality.medium:
        return 'Moyenne (32kHz)';
      case RecordingQuality.high:
        return 'Haute (44kHz)';
    }
  }

  String get shortName {
    switch (this) {
      case RecordingQuality.low:
        return 'Basse';
      case RecordingQuality.medium:
        return 'Moyenne';
      case RecordingQuality.high:
        return 'Haute';
    }
  }
}