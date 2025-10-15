// send_package_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart'; // ใช้ Cloudinary
import 'package:delivery_project/page/order_status_page.dart';

// Constants
const Color _primaryColor = Color(0xFFC70808);
const Color _backgroundColor = Color(0xFFFDE9E9);

class SendPackagePage extends StatefulWidget {
  final String uid;
  final int role;
  const SendPackagePage({super.key, required this.uid, required this.role});

  @override
  State<SendPackagePage> createState() => _SendPackagePageState();
}

class _SendPackagePageState extends State<SendPackagePage> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();
  final TextEditingController _deliveryAddressController =
      TextEditingController();
  String _userName = 'กำลังโหลด...';
  String _userPhone = '...';
  String _profileImageUrl = 'https://picsum.photos/200';
  int _step = 1;
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _userName = data['fullname'] ?? 'ผู้ใช้';
            _userPhone = data['phone'] ?? 'ไม่มีเบอร์โทร';
            _profileImageUrl = data['profile'] ?? _profileImageUrl;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = 'ไม่พบข้อมูล';
        });
      }
    }
  }

  void _submitData() {
    if (_detailController.text.isEmpty ||
        _addressController.text.isEmpty ||
        _deliveryAddressController.text.isEmpty ||
        _imageFile == null) {
      Get.snackbar('ข้อมูลไม่ครบ', 'กรุณากรอกข้อมูลและถ่ายรูปสินค้าให้ครบถ้วน');
      return;
    }
    setState(() {
      _step = 2;
    });
  }

  void _confirmSubmission() {
    setState(() {
      _step = 3;
    });
  }

  void _completeSubmission() async {
    if (_imageFile == null) return;

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      // 1. อัปโหลดรูปภาพไปยัง Cloudinary
      final cloudinary = CloudinaryPublic('dnutmbomv', 'delivery888', cache: false);
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          _imageFile!.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      final imageUrl = response.secureUrl;

      // 2. เตรียมข้อมูลสำหรับบันทึกลง Firestore
      final orderData = {
        'customerId': widget.uid,
        'riderId': null,
        'orderDetails': _detailController.text,
        'orderImageUrl': imageUrl,
        'pickupAddress': {
          'detail': _addressController.text,
          'gps': const GeoPoint(16.4858, 102.8222)
        },
        'deliveryAddress': {
          'detail': _deliveryAddressController.text,
          'gps': const GeoPoint(16.4746, 102.8247)
        },
        'currentStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(), // <-- ตัวนี้ใช้ได้ เพราะอยู่ชั้นนอกสุด
        
        // **ส่วนที่แก้ไข: เปลี่ยนไปใช้ Timestamp.now()**
        'statusHistory': [
          {'status': 'pending', 'timestamp': Timestamp.now()} // <-- ใช้เวลาของเครื่อง ณ ตอนนั้น
        ],
      };

      // 3. บันทึกข้อมูล
      DocumentReference docRef = await FirebaseFirestore.instance
          .collection('delivery_orders')
          .add(orderData);

      Get.back();

      // 4. ไปยังหน้าสำเร็จ
      setState(() {
        _step = 4;
      });
      Future.delayed(const Duration(seconds: 2), () {
        Get.off(() => OrderStatusPage(
              orderId: docRef.id,
              uid: widget.uid,
              role: widget.role,
            ));
      });
    } catch (e) {
      Get.back();
      Get.snackbar('เกิดข้อผิดพลาด', 'ไม่สามารถสร้างออเดอร์ได้: $e');
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _detailController.dispose();
    _deliveryAddressController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.camera, maxWidth: 800);
      if (mounted) {
        setState(() {
          _imageFile = pickedFile;
        });
      }
    } catch (e) {
      Get.snackbar('เกิดข้อผิดพลาด', 'ไม่สามารถเปิดกล้องได้');
    }
  }

  @override
  Widget build(BuildContext context) {
    // โค้ดส่วน UI ทั้งหมดเหมือนเดิม ไม่ต้องแก้ไข
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

  // (โค้ดส่วน UI ทั้งหมดตั้งแต่ _buildSliverAppBar จนสุดไฟล์ สามารถใช้ของเดิมได้เลย)
  // ...
  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180.0,
      pinned: true,
      backgroundColor: _primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.zero,
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 8),
          child: Text(
            'สวัสดีคุณ\n$_userName',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ),
        background: ClipPath(
          clipper: CustomClipperWidget(),
          child: Container(
            color: _primaryColor,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 50, right: 20),
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  backgroundImage:
                      NetworkImage(_profileImageUrl),
                ),
              ),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          if (_step > 1 && _step < 4) {
            setState(() {
              _step--;
            });
          } else {
            Get.back();
          }
        },
      ),
    );
  }

  Widget _buildStepOneForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUserInfo(),
        const SizedBox(height: 15),
        _buildTextField(_addressController, 'ที่อยู่ต้นทาง', Icons.store),
        const SizedBox(height: 15),
        _buildTextField(
            _deliveryAddressController, 'ที่อยู่ปลายทาง', Icons.location_on),
        const SizedBox(height: 15),
        _buildPackageSection(),
        const SizedBox(height: 15),
        _buildTextField(
            _detailController, 'รายละเอียดสินค้า', Icons.note_alt_outlined,
            maxLines: 3),
        const SizedBox(height: 20),
        _buildPrimaryButton('ดำเนินการต่อ', _submitData),
      ],
    );
  }

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

  Widget _buildStepThreeFinalConfirmation() {
    return Column(
      children: [
        _buildConfirmSection(showPackageIcon: true),
        const SizedBox(height: 20),
        _buildDialogBox(
          'คุณต้องการสร้างรายการส่งสินค้านี้ใช่หรือไม่',
          'แก้ไข',
          'ยืนยัน',
          () => setState(() => _step = 1),
          _completeSubmission,
        ),
      ],
    );
  }

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

  Widget _buildUserInfo() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: _primaryColor),
              const SizedBox(width: 8),
              Text('ผู้ส่ง: $_userName',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(),
          Row(
            children: [
              const Icon(Icons.phone, color: _primaryColor),
              const SizedBox(width: 8),
              Text(_userPhone),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPackageSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _imageFile == null
              ? const Icon(Icons.image_search, color: Colors.grey, size: 60)
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
            onPressed: _takePhoto,
            icon: const Icon(Icons.camera_alt, color: _primaryColor),
            label: const Text('ถ่ายรูปสินค้า',
                style: TextStyle(color: _primaryColor)),
          ),
        ],
      ),
    );
  }

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
          _buildConfirmRow(Icons.store, 'จาก:', _addressController.text),
          _buildConfirmRow(
              Icons.location_on, 'ไปที่:', _deliveryAddressController.text),
          _buildConfirmRow(
              Icons.note_alt_outlined, 'รายละเอียด:', _detailController.text),
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

  Widget _buildConfirmRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primaryColor, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

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

  Widget _buildProductListFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'รายการล่าสุดของคุณ',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _buildProductStatusItem('ลำโพง Marshall', 'สถานะ: ส่งสำเร็จ'),
        _buildProductStatusItem('รองเท้า Nike', 'สถานะ: กำลังจัดส่ง'),
      ],
    );
  }

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
          const Icon(Icons.inventory, color: Colors.grey, size: 30),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(status)
        ],
      ),
    );
  }

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
          // สามารถเพิ่มการนำทางได้ที่นี่
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