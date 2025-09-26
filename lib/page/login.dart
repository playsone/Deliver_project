import 'package:delivery_project/page/home.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // 1. Controllers
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  // 2. สถานะสำหรับ Loading
  bool _isLoading = false;

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // 3. ฟังก์ชันสำหรับแสดงข้อความแจ้งเตือน
  void _showSnackBar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : const Color(0xFFC70808),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // 4. ฟังก์ชันแปลงเบอร์โทรศัพท์เป็น Email (ต้องเหมือนกับหน้า Login)
  String _constructEmailFromPhone(String phoneNumber) {
    // ลบอักขระที่ไม่ใช่ตัวเลขออก แล้วต่อท้ายด้วยโดเมนที่กำหนด
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    // ใช้โดเมนสมมติเพื่อใช้กับ Firebase Auth
    return "$cleanPhone@speedder.com";
  }

  // 5. ฟังก์ชันสมัครสมาชิก
  Future<void> register() async {
    final phoneNumber = phoneController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    // ตรวจสอบความถูกต้อง
    if (phoneNumber.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar("กรุณากรอกข้อมูลให้ครบถ้วน");
      return;
    }
    if (password != confirmPassword) {
      _showSnackBar("รหัสผ่านและการยืนยันรหัสผ่านไม่ตรงกัน");
      return;
    }
    if (password.length < 6) {
      _showSnackBar("รหัสผ่านต้องมีความยาวอย่างน้อย 6 ตัวอักษร");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // แปลงเบอร์โทรศัพท์เป็น Email สำหรับการสมัครสมาชิก
      final email = _constructEmailFromPhone(phoneNumber);

      // สร้างบัญชีผู้ใช้ใน Firebase ด้วย Email ปลอมและรหัสผ่านจริง
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      _showSnackBar("สมัครสมาชิกสำเร็จ! กำลังเข้าสู่ระบบ...", success: true);

      // เมื่อสมัครสำเร็จ ให้ไปยังหน้าหลัก
      Get.offAll(() => const HomeScreen());
    } on FirebaseAuthException catch (e) {
      String errorMessage = "การสมัครสมาชิกไม่สำเร็จ";
      if (e.code == 'email-already-in-use') {
        errorMessage = "เบอร์โทรศัพท์นี้ถูกใช้สมัครสมาชิกแล้ว";
      } else if (e.code == 'weak-password') {
        errorMessage = "รหัสผ่านอ่อนแอเกินไป กรุณาตั้งรหัสที่ซับซ้อนกว่านี้";
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
            _buildRegisterForm(context),
            _buildFooter(),
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
            color: const Color(0xFFC70808),
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
          bottom: 50,
          child: const Text(
            'สมัครสมาชิก',
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

  Widget _buildRegisterForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Column(
        children: [
          // ช่องกรอกเบอร์โทรศัพท์
          _buildTextField(
            label: 'เบอร์โทรศัพท์',
            controller: phoneController,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          // ช่องกรอกรหัสผ่าน
          _buildTextField(
            label: 'รหัสผ่าน (อย่างน้อย 6 ตัว)',
            controller: passwordController,
            isPassword: true,
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 20),
          // ช่องยืนยันรหัสผ่าน
          _buildTextField(
            label: 'ยืนยันรหัสผ่าน',
            controller: confirmPasswordController,
            isPassword: true,
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 30),
          _buildRegisterButton(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool isPassword = false,
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

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : register,
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
                'ลงทะเบียน',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'มีบัญชีอยู่แล้ว?',
            style: TextStyle(color: Colors.black54, fontSize: 14),
          ),
          TextButton(
            onPressed: () {
              // ย้อนกลับไปหน้า Login
              Get.back();
            },
            child: const Text(
              'เข้าสู่ระบบ',
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

// Custom Clipper for the red background shape (คัดลอกจาก LoginPage)
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

// Custom Clipper for the white background shape (คัดลอกจาก LoginPage)
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
