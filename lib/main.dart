import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/firebase_options.dart';
import 'package:delivery_project/service/authen_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:delivery_project/page/index.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (context) => AuthenService())],
      child: const MyApp(),
    ),
  );
  bg.BackgroundGeolocation.registerHeadlessTask(headlessTask);
}

void headlessTask(bg.HeadlessEvent headlessEvent) async {
  log('--- Headless Event: ${headlessEvent.name} ---');

  switch (headlessEvent.name) {
    case bg.Event.LOCATION:
      bg.Location location = headlessEvent.event as bg.Location;
      log('[headlessTask] Location: ${location.coords.latitude}, ${location.coords.longitude}');
      break;

    case bg.Event.MOTIONCHANGE:
      bg.Location location = headlessEvent.event as bg.Location;
      log('[headlessTask] MotionChange: Is moving? ${location.isMoving}');
      break;

    case bg.Event.GEOFENCE:
      var geofenceEvent = headlessEvent.event as bg.GeofenceEvent;
      log('[headlessTask] Geofence: ${geofenceEvent.action} ${geofenceEvent.identifier}');
      break;

    default:
      log('[headlessTask] Unknown event: ${headlessEvent.name}');
  }
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
