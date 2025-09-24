import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _isRider = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDE9E9), // Background color
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            _buildHeader(context),
            // User Type Selector
            _buildUserTypeSelector(),
            const SizedBox(height: 20),
            // User Profile Image
            _buildProfileImage(),
            // Registration Form Section with Animation
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _isRider
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: _buildUserForm(),
              secondChild: _buildRiderForm(),
            ),
            // Submit Button
            _buildSubmitButton(context),
            const SizedBox(height: 40),
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
            height: MediaQuery.of(context).size.height * 0.28,
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
            clipper: CustomClipperBlack(),
            child: Container(
              height: 100,
              color: Colors.black,
              child: const Center(
                child: Text(
                  'สมัครสมาชิก',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserTypeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC70808), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTypeButton('ผู้ใช้งาน', !_isRider),
          _buildTypeButton('ไรเดอร์', _isRider),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String title, bool isSelected) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _isRider = title == 'ไรเดอร์';
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFC70808) : Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFFC70808),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(
            color: Color(0xFFE0E0E0),
            shape: BoxShape.circle,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildUserForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Column(
        children: [
          _buildTextField('ชื่อ-สกุล'),
          const SizedBox(height: 20),
          _buildTextField('อีเมล'),
          const SizedBox(height: 20),
          _buildTextField('ที่อยู่'),
          const SizedBox(height: 20),
          _buildTextField('เบอร์โทรศัพท์'),
          const SizedBox(height: 20),
          _buildTextFieldWithIcon('พิกัด GPS', Icons.location_on),
        ],
      ),
    );
  }

  Widget _buildRiderForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Column(
        children: [
          _buildTextField('ชื่อ-สกุล'),
          const SizedBox(height: 20),
          _buildTextField('อีเมล'),
          const SizedBox(height: 20),
          _buildTextField('ที่อยู่'),
          const SizedBox(height: 20),
          _buildTextField('เบอร์โทรศัพท์'),
          const SizedBox(height: 20),
          _buildTextFieldWithIcon('พิกัด GPS', Icons.location_on),
          const SizedBox(height: 20),
          _buildTextFieldWithIcon('ทะเบียนรถ', Icons.motorcycle),
        ],
      ),
    );
  }

  Widget _buildTextField(String label) {
    return TextField(
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

  Widget _buildTextFieldWithIcon(String label, IconData icon) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        suffixIcon: Icon(icon, color: Colors.black54),
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            // Show success dialog
            _showSuccessDialog(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC70808),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'สมัครสมาชิก',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 20),
              const Text(
                'สมัครสมาชิกเรียบร้อย',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'ตกลง',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Custom Clipper for the red background shape (same as previous example)
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

// Custom Clipper for the black background shape
class CustomClipperBlack extends CustomClipper<Path> {
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
