import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Some operator networks allow the initial WebChannel request but stall it,
  // which prevents auto-detection from switching transports before reads time out.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    webExperimentalForceLongPolling: true,
  );
  runApp(const ProviderScope(child: MyApp()));
}
