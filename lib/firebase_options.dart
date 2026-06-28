import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyArYlwokCAWyu7G961oJ-k04WnUQGhiP0c',
    appId: '1:455567012708:web:bb8c8075f4b1d94f6b4071',
    messagingSenderId: '455567012708',
    projectId: 'myapptestinng',
    authDomain: 'myapptestinng.firebaseapp.com',
    storageBucket: 'myapptestinng.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyArYlwokCAWyu7G961oJ-k04WnUQGhiP0c',
    appId: '1:455567012708:android:placeholder',
    messagingSenderId: '455567012708',
    projectId: 'myapptestinng',
    storageBucket: 'myapptestinng.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyArYlwokCAWyu7G961oJ-k04WnUQGhiP0c',
    appId: '1:455567012708:ios:placeholder',
    messagingSenderId: '455567012708',
    projectId: 'myapptestinng',
    storageBucket: 'myapptestinng.firebasestorage.app',
    iosBundleId: 'com.example.myApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyArYlwokCAWyu7G961oJ-k04WnUQGhiP0c',
    appId: '1:455567012708:ios:placeholder',
    messagingSenderId: '455567012708',
    projectId: 'myapptestinng',
    storageBucket: 'myapptestinng.firebasestorage.app',
    iosBundleId: 'com.example.myApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyArYlwokCAWyu7G961oJ-k04WnUQGhiP0c',
    appId: '1:455567012708:web:placeholder',
    messagingSenderId: '455567012708',
    projectId: 'myapptestinng',
    authDomain: 'myapptestinng.firebaseapp.com',
    storageBucket: 'myapptestinng.firebasestorage.app',
  );
}