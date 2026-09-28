import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBKTj8Nmbn4Ty88Ww2aOsmXavnnaFXwInE',
    appId: '1:481314825478:web:0ed25952b75987d15fea87',
    messagingSenderId: '481314825478',
    projectId: 'expnz-123',
    authDomain: 'expnz-123.firebaseapp.com',
    storageBucket: 'expnz-123.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBKTj8Nmbn4Ty88Ww2aOsmXavnnaFXwInE',
    appId: '1:481314825478:android:0ed25952b75987d15fea87',
    messagingSenderId: '481314825478',
    projectId: 'expnz-123',
    storageBucket: 'expnz-123.firebasestorage.app',
  );
}
