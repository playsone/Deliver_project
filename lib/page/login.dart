import 'package:delivery_project/page/register.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/get_navigation.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

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
            child: Container(
              height: 100,
              color: Colors.white,
              child: const Center(
                child: Text(
                  'เข้าสู่ระบบ',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC70808),
                  ),
                ),
              ),
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
          _buildTextField('ชื่อผู้ใช้', false),
          const SizedBox(height: 20),
          _buildTextField('รหัสผ่าน', true),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
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

  Widget _buildTextField(String label, bool isPassword) {
    return TextField(
      obscureText: isPassword,
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
        onPressed: () {
          // Add your login logic here
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC70808),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
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
            'ถ้าคุณยังไม่ได้เป็นสมาชิกแอป(แอพแอปปป) ?',
            style: TextStyle(color: Colors.black54, fontSize: 14),
          ),
          TextButton(
            onPressed: () {
              Get.to(() => RegisterPage(), transition: Transition.fadeIn);
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
