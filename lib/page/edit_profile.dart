import 'package:flutter/material.dart';
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // Mock data to simulate user information from a database
  final String _profileImageUrl = 'https://picsum.photos/200'; // Placeholder image
  final String _defaultName = 'ชื่อ-สกุล';
  final String _defaultPhone = 'หมายเลขโทรศัพท์';
  final String _defaultAddress = 'ที่อยู่หรือสถานที่พิกัด';
  final String _defaultGps = 'พิกัดรับสินค้า';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'แก้ไขข้อมูลส่วนตัว',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFC70808),
        elevation: 0,
        shape: const ContinuousRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(50),
            bottomRight: Radius.circular(50),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeaderBackground(),
            _buildProfileSection(),
            _buildFormSection(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHeaderBackground() {
    return Container(
      height: 120,
      decoration: const BoxDecoration(
        color: Color(0xFFC70808),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Transform.translate(
      offset: const Offset(0, -60), // Move the profile image up
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: NetworkImage(_profileImageUrl),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextFieldWithLabel('ชื่อ-สกุล', _defaultName),
          const SizedBox(height: 20),
          _buildTextFieldWithLabel('หมายเลขโทรศัพท์', _defaultPhone),
          const SizedBox(height: 20),
          _buildTextFieldWithLabel('ที่อยู่หรือสถานที่พิกัด', _defaultAddress),
          const SizedBox(height: 20),
          _buildTextFieldWithLabel('พิกัด GPS หรือสถานที่รับสินค้า', _defaultGps),
          const SizedBox(height: 40),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildTextFieldWithLabel(String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black38),
            fillColor: Colors.grey.shade200,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          // Add save data logic here
          // Example: print('Saving data...');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC70808),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'บันทึกข้อมูล',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Color(0xFFC70808),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home, 'หน้าแรก', true),
          _buildNavItem(Icons.history, 'ประวัติการส่งสินค้า', false),
          _buildNavItem(Icons.more_horiz, 'อื่นๆ', false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white54,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}