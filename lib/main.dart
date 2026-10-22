import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/recipe_app.dart';
import 'app/setup_screen.dart';
import 'firebase/firebase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!FirebaseConfig.isConfigured) {
    runApp(const SetupApp());
    return;
  }

  await Firebase.initializeApp(options: FirebaseConfig.options);
  runApp(const RecipeApp());
}
