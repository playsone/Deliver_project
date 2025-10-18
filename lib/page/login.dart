import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_project/page/home.dart';
import 'package:delivery_project/page/home_rider.dart';
import 'package:delivery_project/page/register.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFC70808),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _constructEmailFromPhone(String phoneNumber) {
    return "$phoneNumber@e.com";
  }

  Future<void> login() async {
    final phoneNumber = phoneController.text.trim();
    final password = passwordController.text.trim();

    if (phoneNumber.isEmpty || password.isEmpty) {
      _showSnackBar("กรุณากรอกเบอร์โทรศัพท์และรหัสผ่านให้ครบถ้วน");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _constructEmailFromPhone(phoneNumber);

      var result = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      var uid = result.user!.uid;

      var db = FirebaseFirestore.instance;
      var usersCollection = db.collection("users");

      var query = usersCollection.where("phone",
          isEqualTo: phoneController.text.trim());
      var data = await query.get();

      log(data.docs.first.data().toString());
      if (data.docs.isEmpty) {
        Get.snackbar("Error", "Can't Login");
      } else {
        var userData = data.docs.first.data();
        var uid = userData['uid'];
        var role = userData['role'];

        if (role == 0) {
          Get.to(() => HomeScreen(
                uid: uid,
                role: role,
              ));
        } else if (role == 1) {
          Get.to(() => RiderHomeScreen(
                uid: uid,
                role: role,
              ));
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
      _showSnackBar(errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDE9E9),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            _buildLoginForm(context),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipPath(
          clipper: CustomClipperRed(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.35,
            color: const Color(0xFFC70808), // Red color
            child: const Center(
              child: Text(
                'SPEED - DER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: ClipPath(
            clipper: CustomClipperWhite(),
            child: Container(height: 100, color: Colors.white),
          ),
        ),
        const Positioned(
          bottom: 50,
          child: Text(
            'เข้าสู่ระบบ',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFC70808),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Column(
        children: [
          _buildTextField(
            label: 'เบอร์โทรศัพท์',
            isPassword: false,
            controller: phoneController,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'รหัสผ่าน',
            isPassword: true,
            controller: passwordController,
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                _showSnackBar("ฟังก์ชันรีเซ็ตรหัสผ่านยังไม่พร้อมใช้งาน");
              },
              child: const Text(
                'รีเซ็ตรหัสผ่าน',
                style: TextStyle(color: Color(0xFFC70808), fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildLoginButton(context),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required bool isPassword,
    required TextEditingController controller,
    required TextInputType keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : login,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC70808),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : const Text(
                'เข้าสู่ระบบ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Text(
            'ถ้าคุณยังไม่ได้เป็นสมาชิก?',
            style: TextStyle(color: Colors.black54, fontSize: 14),
          ),
          TextButton(
            onPressed: () {
              Get.to(() => const RegisterPage(), transition: Transition.fadeIn);
            },
            child: const Text(
              'สมัครสมาชิก',
              style: TextStyle(
                color: Color(0xFFC70808),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomClipperRed extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 100);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 100,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}

class CustomClipperWhite extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height);
    path.quadraticBezierTo(size.width / 2, 0, size.width, size.height);
    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}
