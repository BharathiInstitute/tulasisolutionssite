import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Auto-negotiate long-polling vs streaming so proxies/antivirus that abort
  // the default WebChannel connection don't break real-time list updates.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    webExperimentalAutoDetectLongPolling: true,
  );
  runApp(const ProviderScope(child: MyApp()));
}
