import 'package:firebase_core/firebase_core.dart';
import 'dart:io';

class FirebaseConfig {
  static FirebaseOptions get currentPlatform {
    if (Platform.isIOS) {
      return ios;
    } else if (Platform.isAndroid) {
      return android;
    } else {
      throw UnsupportedError('Plateforme non supportée');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    appId: '1:123456789:android:abcdef123456789',
    messagingSenderId: '123456789',
    projectId: 'lovingo-app',
    storageBucket: 'lovingo-app.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    appId: '1:123456789:ios:abcdef123456789',
    messagingSenderId: '123456789',
    projectId: 'lovingo-app',
    storageBucket: 'lovingo-app.appspot.com',
    iosClientId: '123456789-abcdef.apps.googleusercontent.com',
    iosBundleId: 'com.lovingo.app',
  );
}