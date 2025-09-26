import 'package:delivery_project/page/home.dart';
import 'package:delivery_project/page/register.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 1. Controllers สำหรับรับค่าจากผู้ใช้ (Phone Number และ Password)
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // 2. สถานะสำหรับ Loading
  bool _isLoading = false;

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // 3. ฟังก์ชันสำหรับแสดงข้อความแจ้งเตือน
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

  // 4. ฟังก์ชันแปลงเบอร์โทรศัพท์เป็น Email สำหรับ Firebase (ใช้เป็น Username)
  String _constructEmailFromPhone(String phoneNumber) {
    // ลบอักขระที่ไม่ใช่ตัวเลขออก แล้วต่อท้ายด้วยโดเมนที่กำหนด
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    // ใช้โดเมนสมมติเพื่อใช้กับ Firebase Auth
    return "$cleanPhone@speedder.com";
  }

  // 5. ฟังก์ชันหลักสำหรับจัดการการ Login ด้วยเบอร์โทรศัพท์และรหัสผ่าน
  Future<void> login() async {
    final phoneNumber = phoneController.text.trim();
    final password = passwordController.text.trim();

    // ตรวจสอบความถูกต้องเบื้องต้น
    if (phoneNumber.isEmpty || password.isEmpty) {
      _showSnackBar("กรุณากรอกเบอร์โทรศัพท์และรหัสผ่านให้ครบถ้วน");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // แปลงเบอร์โทรศัพท์เป็น Email สำหรับการ Login ใน Firebase
      final email = _constructEmailFromPhone(phoneNumber);

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ถ้า Login สำเร็จ ให้ไปยังหน้าหลัก (HomeScreen) และลบ Route ก่อนหน้าทั้งหมด
      Get.offAll(() => const HomeScreen());
    } on FirebaseAuthException catch (e) {
      // จัดการข้อผิดพลาดจาก Firebase
      String errorMessage =
          "การเข้าสู่ระบบล้มเหลว กรุณาตรวจสอบเบอร์โทรศัพท์และรหัสผ่าน";
      if (e.code == 'user-not-found') {
        errorMessage = "ไม่พบผู้ใช้งานด้วยเบอร์โทรศัพท์นี้";
      } else if (e.code == 'wrong-password') {
        errorMessage = "รหัสผ่านไม่ถูกต้อง";
      } else if (e.code == 'invalid-email') {
        // อาจเกิดขึ้นถ้าเบอร์โทรศัพท์ที่แปลงแล้วไม่ตรงตามรูปแบบ email
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
      backgroundColor: const Color(0xFFFDE9E9), // Background color
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            _buildHeader(context),
            // Login Form Section
            _buildLoginForm(context),
            // Footer Section
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
        Positioned(
          bottom: 50, // ปรับตำแหน่งให้ข้อความอยู่กึ่งกลางโค้งมน
          child: const Text(
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
          // ช่องกรอกเบอร์โทรศัพท์
          _buildTextField(
            label: 'เบอร์โทรศัพท์',
            isPassword: false,
            controller: phoneController,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          // ช่องกรอกรหัสผ่าน
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
                // TODO: Implement forgot password logic
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

  // อัปเดต _buildTextField ให้รับ TextEditingController
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
        // เชื่อมปุ่มกับฟังก์ชัน Login
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
                // ข้อความเป็น "เข้าสู่ระบบ" ตามที่ผู้ใช้ต้องการ
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
              // ใช้ GetX สำหรับการนำทางไปยังหน้า RegisterPage
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

// Custom Clipper for the red background shape
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

// Custom Clipper for the white background shape
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
