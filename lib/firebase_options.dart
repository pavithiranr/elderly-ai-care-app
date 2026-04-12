import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Configuration for Firebase initialization.
/// Auto-generated from google-services.json
class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB4th4Iwep0zVcyi26MBZ3TJRoerjFk--4',
    appId: '1:631057330468:android:05d5e131929714653a83b1',
    messagingSenderId: '631057330468',
    projectId: 'caresync-vertex',
    storageBucket: 'caresync-vertex.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB4th4Iwep0zVcyi26MBZ3TJRoerjFk--4',
    appId: '1:631057330468:ios:YOUR_IOS_APP_ID', // Update with your iOS app ID
    messagingSenderId: '631057330468',
    projectId: 'caresync-vertex',
    storageBucket: 'caresync-vertex.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAE3hE0pcYq3iLKbI4xaquQxyHzyOcMsY4',
    appId: '1:631057330468:web:62aa3e016e18b0833a83b1',
    messagingSenderId: '631057330468',
    projectId: 'caresync-vertex',
    storageBucket: 'caresync-vertex.firebasestorage.app',
    authDomain: 'caresync-vertex.firebaseapp.com',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (Platform.isAndroid) return android;
    if (Platform.isIOS) return ios;
    throw UnsupportedError('This platform is not supported');
  }
}
