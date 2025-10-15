import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/firebase_options.dart';
import 'package:delivery_project/service/authen_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:delivery_project/page/index.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'speed-der',
      theme: ThemeData(primarySwatch: Colors.purple),
      home: const SpeedDerApp(),
    );
  }
}
