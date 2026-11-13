/// Starts Firebase the first time online play is opened, so the rest of the
/// app never waits for the network.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'backend.dart';
import 'firestore_backend.dart';

class OnlineServices {
  OnlineServices._();

  static OnlineBackend? _backend;

  /// Replaces the server, for tests.
  static set backendForTesting(OnlineBackend? b) => _backend = b;

  static Future<OnlineBackend> backend() async {
    final existing = _backend;
    if (existing != null) return existing;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
    } catch (e) {
      // No Firebase setup for this platform (e.g. Windows).
      debugPrint('Firebase unavailable: $e');
      throw OnlineError(OnlineErrorKind.unavailable, e);
    }
    return _backend = FirestoreBackend();
  }
}
