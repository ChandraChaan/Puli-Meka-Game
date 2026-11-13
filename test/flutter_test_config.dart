import 'dart:async';

import 'package:puli_meka/feedback.dart';

/// The audio and vibration plugins have no platform side in tests.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GameFeedback.enabled = false;
  await testMain();
}
