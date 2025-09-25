import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // ตัวแปรควบคุมการแสดงผลฟอร์ม
  bool _isRider = false;
  // ตัวแปรสำหรับเก็บไฟล์รูปภาพ (เปลี่ยนจาก File? เป็น XFile?)
  XFile? _profileImage;
  XFile? _vehicleImage;

  // Controllers สำหรับการจัดการข้อมูลในฟอร์ม
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _address2Controller = TextEditingController();
  final _gpsController = TextEditingController();
  final _vehicleRegController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _address2Controller.dispose();
    _gpsController.dispose();
    _vehicleRegController.dispose();
    super.dispose();
  }

  // ฟังก์ชันสำหรับเลือกรูปภาพจาก Gallery (เปลี่ยนให้รับ XFile โดยตรง)
  Future<void> _pickImage(bool isProfile) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        if (isProfile) {
          _profileImage = pickedFile;
        } else {
          _vehicleImage = pickedFile;
        }
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

  // Header Section
  Widget _buildHeader(BuildContext context) {
    return Column(
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
        Container(
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
      ],
    );
  }

  // User Type Selector
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

  // Profile Image Section
  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: () => _pickImage(true), // isProfile = true
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              shape: BoxShape.circle,
              // อัปเดตการแสดงผลรูปภาพ โดยใช้ FileImage จาก path ของ XFile
              image: _profileImage != null
                  ? DecorationImage(
                      image: FileImage(File(_profileImage!.path)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _profileImage == null
                ? const Icon(Icons.person, size: 60, color: Colors.grey)
                : null,
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
      ),
    );
  }

  // Vehicle Image Section (เฉพาะไรเดอร์)
  Widget _buildVehicleImage() {
    return GestureDetector(
      onTap: () => _pickImage(false), // isProfile = false
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              shape: BoxShape.circle,
              // อัปเดตการแสดงผลรูปภาพ โดยใช้ FileImage จาก path ของ XFile
              image: _vehicleImage != null
                  ? DecorationImage(
                      image: FileImage(File(_vehicleImage!.path)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _vehicleImage == null
                ? const Icon(Icons.motorcycle, size: 60, color: Colors.grey)
                : null,
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
      ),
    );
  }

  // User Registration Form
  Widget _buildUserForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Column(
        children: [
          _buildTextField('ชื่อ-สกุล', controller: _fullNameController),
          const SizedBox(height: 20),
          _buildTextField(
            'อีเมล',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            'เบอร์โทรศัพท์',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            'รหัสผ่าน',
            controller: _passwordController,
            isPassword: true,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            'รหัสผ่านอีกครั้ง',
            controller: _confirmPasswordController,
            isPassword: true,
          ),
          const SizedBox(height: 20),
          _buildTextField('ที่อยู่', controller: _addressController),
          const SizedBox(height: 20),
          _buildTextField('ที่อยู่ 2', controller: _address2Controller),
          const SizedBox(height: 20),
          _buildTextFieldWithIcon(
            'พิกัด GPS',
            Icons.location_on,
            controller: _gpsController,
          ),
        ],
      ),
    );
  }

  // Rider Registration Form
  Widget _buildRiderForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Column(
        children: [
          _buildTextField('ชื่อ-สกุล', controller: _fullNameController),
          const SizedBox(height: 20),
          _buildTextField(
            'อีเมล',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            'เบอร์โทรศัพท์',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            'รหัสผ่าน',
            controller: _passwordController,
            isPassword: true,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            'รหัสผ่านอีกครั้ง',
            controller: _confirmPasswordController,
            isPassword: true,
          ),
          const SizedBox(height: 20),
          _buildTextField('ทะเบียนรถ', controller: _vehicleRegController),
          const SizedBox(height: 20),
          _buildVehicleImage(), // Vehicle image upload for rider
        ],
      ),
    );
  }

  // Generic TextField
  Widget _buildTextField(
    String label, {
    TextEditingController? controller,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
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

  // TextField with icon
  Widget _buildTextFieldWithIcon(
    String label,
    IconData icon, {
    TextEditingController? controller,
  }) {
    return TextField(
      controller: controller,
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

  // Submit Button
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

  // Success Dialog
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
