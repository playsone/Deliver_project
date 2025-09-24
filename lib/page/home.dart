import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(context),
              _buildIconButtons(),
              // คุณสามารถเพิ่มเนื้อหาอื่น ๆ ได้ที่นี่
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  /// สร้างส่วนหัวของหน้าจอ รวมถึงรูปโปรไฟล์และช่องค้นหา
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFC70808),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'สวัสดีคุณ พ่อครูกรัน',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              // ใช้ GestureDetector เพื่อให้รูปโปรไฟล์สามารถกดได้
              GestureDetector(
                onTap: () {
                  _showProfileOptions(context);
                },
                child: const CircleAvatar(
                  radius: 30,
                  // คุณสามารถใช้ Image.network() เพื่อดึงรูปจาก URL ได้ในภายหลัง
                  // ตัวอย่างเช่น: Image.network('your_image_url')
                  backgroundImage: AssetImage(
                    'assets/images/profile_placeholder.png',
                  ),
                  // หรือถ้าไม่มีรูป ให้ใช้ไอคอนแทน
                  // child: Icon(Icons.person, size: 40, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSearchBar(),
          const SizedBox(height: 20),
          _buildLocationBar(),
        ],
      ),
    );
  }

  /// สร้างแถบค้นหา
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: 'ค้นหาผู้รับสินค้า',
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
        ),
      ),
    );
  }

  /// สร้างแถบที่อยู่
  Widget _buildLocationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        children: [
          Icon(Icons.location_on, color: Colors.white),
          SizedBox(width: 10),
          Text('หอพักอาณาจักรฟ้า', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  /// สร้างปุ่มไอคอนสำหรับบริการต่างๆ
  Widget _buildIconButtons() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildIconButton('พัสดุที่ต้องรับ', Icons.all_inbox),
              _buildIconButton('คุยแชทกับไรเดอร์', Icons.chat),
              _buildIconButton('ส่วนลดแพ็คเกจ', Icons.discount),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildIconButton('สถานะสินค้า', Icons.local_shipping),
              _buildIconButton('ส่งสินค้า', Icons.delivery_dining),
            ],
          ),
        ],
      ),
    );
  }

  /// สร้างปุ่มไอคอนแต่ละอัน
  Widget _buildIconButton(String text, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, size: 40, color: Colors.black),
        ),
        const SizedBox(height: 5),
        Text(text, textAlign: TextAlign.center),
      ],
    );
  }

  /// สร้างแถบนำทางด้านล่าง
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'หน้าแรก'),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'ประวัติการส่งสินค้า',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'อื่นๆ'),
      ],
      selectedItemColor: const Color(0xFFC70808),
      unselectedItemColor: Colors.grey,
    );
  }

  /// แสดงเมนูตัวเลือกเมื่อกดที่รูปโปรไฟล์
  void _showProfileOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent, // ทำให้พื้นหลังโปร่งใสเพื่อจะได้เห็นขอบมน
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOptionButton(
                context,
                'แก้ไขข้อมูลส่วนตัว',
                Icons.person_outline,
                () {
                  // TODO: ใส่โค้ดสำหรับนำทางไปยังหน้าแก้ไขข้อมูลส่วนตัว
                  Navigator.pop(context); // ปิด modal
                },
              ),
              _buildOptionButton(
                context,
                'เปลี่ยนรหัสผ่าน',
                Icons.lock_outline,
                () {
                  // TODO: ใส่โค้ดสำหรับนำทางไปยังหน้าเปลี่ยนรหัสผ่าน
                  Navigator.pop(context); // ปิด modal
                },
              ),
              _buildOptionButton(context, 'ออกจากระบบ', Icons.logout, () {
                // TODO: ใส่โค้ดสำหรับการออกจากระบบ
                Navigator.pop(context); // ปิด modal
              }),
            ],
          ),
        );
      },
    );
  }

  /// สร้างปุ่มตัวเลือกแต่ละอันใน Modal
  Widget _buildOptionButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 24, color: Colors.black54),
            const SizedBox(width: 15),
            Text(title, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
