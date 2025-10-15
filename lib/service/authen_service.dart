import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/page/home.dart';
import 'package:delivery_project/page/home_rider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/get_navigation.dart';

class AuthenService extends ChangeNotifier {
  bool isLoggedIn = false;
  String _tel_num = '';
  String _password = '';

  login({required telnum, required password}) async {
    _tel_num = telnum;
    _password = password;
    try {
      final email = _constructEmailFromPhone(telnum);

      var result = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      var uid = result.user!.uid;

      var db = FirebaseFirestore.instance;
      var usersCollection = db.collection("users");

      // ดึง user ตาม phone
      var query = usersCollection.where("phone", isEqualTo: _tel_num.trim());
      var data = await query.get();

      log(data.docs.first.data().toString());
      if (data.docs.isEmpty) {
        Get.snackbar("Error", "Can't Login");
      } else {
        var userData = data.docs.first.data(); // Map<String, dynamic>
        var role = userData['role']; // ดึงค่า role

        if (role == 0) {
          Get.to(() => HomeScreen());
        } else if (role == 1) {
          Get.to(() => RiderHomeScreen());
        } else {
          log("User has other role: $role");
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage =
          "การเข้าสู่ระบบล้มเหลว กรุณาตรวจสอบเบอร์โทรศัพท์และรหัสผ่าน";
      if (e.code == 'user-not-found') {
        errorMessage = "ไม่พบผู้ใช้งานด้วยเบอร์โทรศัพท์นี้";
      } else if (e.code == 'wrong-password') {
        errorMessage = "รหัสผ่านไม่ถูกต้อง";
      } else if (e.code == 'invalid-email') {
        errorMessage = "เบอร์โทรศัพท์ที่ใช้ไม่ถูกต้อง";
      }
      return errorMessage;
    }
  }
}

String _constructEmailFromPhone(String phoneNumber) {
  return "$phoneNumber@e.com";
}
