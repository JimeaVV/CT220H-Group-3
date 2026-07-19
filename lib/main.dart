import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseReady = false;
  Object? firebaseError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (error) {
    firebaseError = error;
  }

  runApp(
    ProviderScope(
      child: FinTrackApp(
        firebaseReady: firebaseReady,
        firebaseError: firebaseError,
      ),
    ),
  );
}
