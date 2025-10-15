// send_package_page.dart

import 'dart:io'; // เพิ่ม import สำหรับ File
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart'; // เพิ่ม import สำหรับกล้อง
import 'package:firebase_storage/firebase_storage.dart'; // เพิ่ม import สำหรับ Storage
import 'package:cloud_firestore/cloud_firestore.dart'; // เพิ่ม import สำหรับ Firestore
import 'package:delivery_project/page/order_status_page.dart'; // **สำคัญ:** ตรวจสอบว่าหน้านี้รับ orderId ได้

// Constants
const Color _primaryColor = Color(0xFFC70808);
const Color _backgroundColor = Color(0xFFFDE9E9);

class SendPackagePage extends StatefulWidget {
  const SendPackagePage({super.key});

  @override
  State<SendPackagePage> createState() => _SendPackagePageState();
}

class _SendPackagePageState extends State<SendPackagePage> {
  // ตัวแปรสำหรับฟอร์ม (ใช้ Controller แทน)
  final TextEditingController _nameController =
      TextEditingController(text: 'นาย ก. ไรเดอร์');
  final TextEditingController _phoneController =
      TextEditingController(text: '08147155**');
  final TextEditingController _addressController =
      TextEditingController(text: 'หอพักอาณาจักรฟ้า');
  final TextEditingController _detailController = TextEditingController();

  // สถานะเพื่อจัดการขั้นตอน
  int _step = 1; // 1: กรอกข้อมูล, 2: ยืนยัน, 3: ถามยืนยัน, 4: สำเร็จ

  // **ส่วนที่เพิ่มเข้ามา: 1. ตัวแปรสำหรับจัดการรูปภาพ**
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();

  // ฟังก์ชันจำลองการส่ง
  void _submitData() {
    // ตรวจสอบว่ากรอกข้อมูลครบหรือไม่
    if (_detailController.text.isEmpty || _imageFile == null) {
      Get.snackbar('ข้อมูลไม่ครบ', 'กรุณาถ่ายรูปและใส่รายละเอียดสินค้า');
      return;
    }
    setState(() {
      _step = 2;
    });
  }

  // ฟังก์ชันจำลองการถามยืนยัน
  void _confirmSubmission() {
    setState(() {
      _step = 3;
    });
  }

  // **ส่วนที่แก้ไข: 2. เปลี่ยนฟังก์ชันนี้ให้บันทึกข้อมูลจริง**
  void _completeSubmission() async {
    // แสดง Loading Dialog
    Get.dialog(
      const Center(
        child: CircularProgressIndicator(),
      ),
      barrierDismissible: false,
    );

    try {
      // 1. อัปโหลดรูปภาพไปยัง Firebase Storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef =
          FirebaseStorage.instance.ref().child('order_images/$fileName');
      await storageRef.putFile(File(_imageFile!.path));
      final imageUrl = await storageRef.getDownloadURL();

      // 2. เตรียมข้อมูลสำหรับบันทึกลง Firestore
      final orderData = {
        'customerId':
            "20jIUruKySPaKaqnuntdIVCxO5z1", // **สำคัญ:** ควรเปลี่ยนเป็น UID ของผู้ใช้ที่ล็อกอินอยู่จริง
        'riderId': null,
        'orderDetails': _detailController.text,
        'orderImageUrl': imageUrl,
        'pickupAddress': {
          'detail': _addressController.text,
          'gps': const GeoPoint(16.4858, 102.8222) // ตำแหน่งตัวอย่าง
        },
        'deliveryAddress': {
          'detail': 'คณะวิทยาการสารสนเทศ มข.', // ปลายทางตัวอย่าง
          'gps': const GeoPoint(16.4746, 102.8247) // ตำแหน่งตัวอย่าง
        },
        'currentStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'statusHistory': [
          {'status': 'pending', 'timestamp': FieldValue.serverTimestamp()}
        ],
      };

      // 3. บันทึกข้อมูลลงใน Collection 'delivery_orders'
      DocumentReference docRef = await FirebaseFirestore.instance
          .collection('delivery_orders')
          .add(orderData);

      Get.back(); // ปิด Loading Dialog

      // 4. เปลี่ยน _step ไปยังหน้าสำเร็จ และส่งไปหน้าดูสถานะ
      setState(() {
        _step = 4;
      });
      // หน่วงเวลาเล็กน้อยแล้วไปหน้า OrderStatusPage
      Future.delayed(const Duration(seconds: 2), () {
        Get.off(() => OrderStatusPage(orderId: docRef.id));
      });
    } catch (e) {
      Get.back(); // ปิด Loading Dialog หากเกิดข้อผิดพลาด
      Get.snackbar('เกิดข้อผิดพลาด', 'ไม่สามารถสร้างออเดอร์ได้: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  // **ส่วนที่เพิ่มเข้ามา: 3. ฟังก์ชันสำหรับเรียกใช้กล้อง**
  Future<void> _takePhoto() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800, // ลดขนาดรูปภาพเพื่อประหยัดพื้นที่และเวลาอัปโหลด
      );
      setState(() {
        _imageFile = pickedFile;
      });
    } catch (e) {
      Get.snackbar('เกิดข้อผิดพลาด', 'ไม่สามารถเปิดกล้องได้');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.all(20.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  if (_step == 1) _buildStepOneForm(context),
                  if (_step == 2) _buildStepTwoConfirmation(context),
                  if (_step == 3) _buildStepThreeFinalConfirmation(),
                  if (_step == 4) _buildStepFourSuccess(),
                  const SizedBox(height: 20),
                  // ส่วนรายการสินค้าด้านล่าง (ตามภาพตัวอย่าง)
                  _buildProductListFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  // ส่วน Header (คล้าย home.dart)
  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180.0,
      floating: false,
      pinned: true,
      backgroundColor: _primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.zero,
        centerTitle: false,
        title: const Padding(
          padding: EdgeInsets.only(left: 20, bottom: 8),
          child: Text(
            'สวัสดีคุณ\nพ่อครูกรัน',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ),
        background: ClipPath(
          clipper: CustomClipperWidget(), // ใช้ Clipper ที่กำหนดเอง
          child: Container(
            color: _primaryColor,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 50, right: 20),
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  backgroundImage: NetworkImage('https://picsum.photos/200'),
                ),
              ),
            ),
          ),
        ),
      ),
      actions: const [
        // เพิ่ม widget ต่างๆ เช่น Icon อื่นๆ ได้ที่นี่
      ],
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          if (_step > 1 && _step < 4) {
            setState(() {
              _step = _step - 1; // ย้อนกลับไปขั้นตอนก่อนหน้า
            });
          } else {
            Get.back();
          }
        },
      ),
    );
  }

  // ขั้นตอนที่ 1: กรอกข้อมูล
  Widget _buildStepOneForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUserInfo(),
        const SizedBox(height: 15),
        _buildTextField(
            _addressController, 'ที่อยู่: หอพักอาณาจักรฟ้า', Icons.location_on),
        const SizedBox(height: 15),
        _buildPackageSection(),
        const SizedBox(height: 15),
        _buildTextField(
            _detailController, 'รายการสินค้าเพิ่มเติม', Icons.note_alt_outlined,
            maxLines: 3),
        const SizedBox(height: 20),
        _buildPrimaryButton('ดำเนินการต่อ', _submitData),
      ],
    );
  }

  // ขั้นตอนที่ 2: ยืนยันข้อมูล
  Widget _buildStepTwoConfirmation(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUserInfo(),
        const SizedBox(height: 15),
        _buildConfirmSection(),
        const SizedBox(height: 20),
        _buildPrimaryButton('ยืนยันข้อมูล', _confirmSubmission),
      ],
    );
  }

  // ขั้นตอนที่ 3: ถามยืนยัน
  Widget _buildStepThreeFinalConfirmation() {
    return Column(
      children: [
        _buildConfirmSection(showPackageIcon: true),
        const SizedBox(height: 20),
        _buildDialogBox(
          'คุณต้องการส่งมอบสินค้านี้หรือไม่',
          'แก้ไข',
          'ยืนยัน',
          () => setState(() => _step = 1), // ยกเลิกกลับไปขั้นตอน 1
          _completeSubmission, // ยืนยันไปยังขั้นตอน 4
        ),
      ],
    );
  }

  // ขั้นตอนที่ 4: สำเร็จ
  Widget _buildStepFourSuccess() {
    return Column(
      children: [
        _buildConfirmSection(showPackageIcon: true),
        const SizedBox(height: 20),
        _buildSuccessDialog('สร้างรายการส่งของสำเร็จ!'),
        const SizedBox(height: 20),
        const Text('กำลังนำท่านไปยังหน้าติดตามสถานะ...'),
      ],
    );
  }

  // ข้อมูลผู้ใช้
  Widget _buildUserInfo() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: _primaryColor),
              const SizedBox(width: 8),
              Text('สวัสดีคุณ ${_nameController.text}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(),
          Row(
            children: [
              const Icon(Icons.phone, color: _primaryColor),
              const SizedBox(width: 8),
              Text(_phoneController.text),
            ],
          ),
        ],
      ),
    );
  }

  // **ส่วนที่แก้ไข: แสดงรูปที่ถ่ายและเปลี่ยน onPressed**
  Widget _buildPackageSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ถ้ายังไม่มีรูป ให้แสดง Icon
              // ถ้ามีรูปแล้ว ให้แสดงรูปที่ถ่ายจากไฟล์
              _imageFile == null
                  ? const Icon(Icons.inventory, color: Colors.grey, size: 60)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_imageFile!.path),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
              TextButton.icon(
                onPressed: _takePhoto, // **เปลี่ยนเป็นฟังก์ชันถ่ายรูป**
                icon: const Icon(Icons.camera_alt, color: _primaryColor),
                label: const Text('ถ่ายรูปสินค้า',
                    style: TextStyle(color: _primaryColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ส่วนยืนยัน (Step 2/3/4)
  Widget _buildConfirmSection({bool showPackageIcon = false}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text('สรุปรายการ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          _buildConfirmRow('ที่อยู่ต้นทาง:', _addressController.text),
          _buildConfirmRow('รายละเอียด:', _detailController.text),
          const SizedBox(height: 10),
          if (_imageFile != null)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_imageFile!.path),
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // TextField ทั่วไป
  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {int maxLines = 1, bool isReadOnly = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        readOnly: isReadOnly,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: _primaryColor),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        ),
      ),
    );
  }

  // ปุ่มหลัก
  Widget _buildPrimaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ส่วนแสดง Dialog ยืนยัน (Step 3)
  Widget _buildDialogBox(String message, String cancelText, String confirmText,
      VoidCallback onCancel, VoidCallback onConfirm) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _primaryColor, width: 2),
      ),
      child: Column(
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(cancelText,
                      style: const TextStyle(color: Colors.black)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(confirmText,
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ส่วนแสดง Dialog สำเร็จ (Step 4)
  Widget _buildSuccessDialog(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 40),
          const SizedBox(width: 15),
          Text(
            message,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ส่วนรายการสินค้าด้านล่าง
  Widget _buildProductListFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'สินค้าอื่น ๆ ที่ต้องส่งมอบ',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _buildProductStatusItem('ลำโพง Marshall', 'สถานะ: รอส่ง'),
        _buildProductStatusItem('รองเท้า Nike', 'สถานะ: รอส่ง'),
      ],
    );
  }

  // Widget สำหรับรายการสถานะสินค้าแต่ละชิ้น (ย่อจาก OrderStatusPage)
  Widget _buildProductStatusItem(String title, String status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 5),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory,
              color: Colors.grey, size: 30), // แทนรูปภาพสินค้า
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // Bottom Navigation Bar (อ้างอิงจาก home.dart)
  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _primaryColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black12, offset: Offset(0, -2), blurRadius: 5),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'หน้าแรก'),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'ประวัติการส่งสินค้า',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: 'ออกจากระบบ',
          ),
        ],
        currentIndex: 0,
        onTap: (index) {
          // ใช้ Get.back() หรือ Get.to(() => const HomeScreen()) เพื่อกลับหน้าหลัก
        },
      ),
    );
  }
}

// Custom Clipper สำหรับ Header
class CustomClipperWidget extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    double h = size.height;
    double w = size.width;
    Path path = Path();

    path.lineTo(0, h * 0.85);
    path.quadraticBezierTo(w * 0.15, h * 0.95, w * 0.45, h * 0.85);
    path.quadraticBezierTo(w * 0.65, h * 0.75, w, h * 0.8);
    path.lineTo(w, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
