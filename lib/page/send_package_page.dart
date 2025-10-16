import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path/path.dart' hide Path;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:flutter_map/flutter_map.dart';

// --- IMPORT MODELS AND PAGES ---
// !สำคัญ: แก้ path ให้ตรงกับโปรเจกต์ของคุณ
import '../models/order_model.dart';
import '../models/address_model.dart';
import '../models/status_history_model.dart';
import './order_status_page.dart';

// Mock createOrder function
Future<DocumentReference> createOrder({
  required String customerId,
  required String orderDetails,
  String? orderPicture,
  required AddressModel pickup,
  required AddressModel delivery,
}) async {
  final ordersCollection = FirebaseFirestore.instance.collection('orders');
  final now = Timestamp.now();
  final initialStatus = StatusHistoryModel(status: 'pending', timestamp: now);

  final newOrder = OrderModel(
    id: '',
    customerId: customerId,
    riderId: null,
    orderDetails: orderDetails,
    orderPicture: orderPicture,
    currentStatus: 'pending',
    createdAt: now,
    pickupDatetime: null,
    deliveryDatetime: null,
    pickupAddress: pickup,
    deliveryAddress: delivery,
    statusHistory: [initialStatus],
  );

  return await ordersCollection.add(newOrder.toMap());
}

// ------------------------------------------------------------------
// Page 1: Map Picker (สำหรับเลือกตำแหน่งปลายทาง)
// ------------------------------------------------------------------
class MapPickerPage extends StatefulWidget {
  final LatLng initialLocation;
  const MapPickerPage({super.key, required this.initialLocation});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  late LatLng _selectedLocation;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เลือกตำแหน่งปลายทาง'),
        backgroundColor: const Color(0xFFC70808),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 16.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() => _selectedLocation = position.center!);
                }
              },
            ),
            children: [
              TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
            ],
          ),
          const Center(
              child:
                  Icon(Icons.location_pin, size: 50, color: Color(0xFFC70808))),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('ยืนยันตำแหน่งนี้'),
              onPressed: () => Get.back(result: _selectedLocation),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC70808),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Controller (จัดการ Logic ทั้งหมดของหน้า SendPackagePage)
// ------------------------------------------------------------------
class SendPackageController extends GetxController {
  final String uid;
  final int role;
  SendPackageController({required this.uid, required this.role});

  // --- State ---
  final detailController = TextEditingController();
  final deliveryAddressDetailsController = TextEditingController();
  final Rx<XFile?> imageFile = Rx(null);
  final RxInt step = 1.obs;
  final RxBool isLoading = true.obs;

  // User Info
  final RxString userName = 'กำลังโหลด...'.obs;
  final RxString userPhone = '...'.obs;
  final RxString profileImageUrl = 'https://picsum.photos/200'.obs;

  // Location
  final Location _location = Location();
  final Rx<LocationData?> currentUserLocation = Rx(null);
  final Rx<LatLng?> selectedDestinationLocation = Rx(null);
  final RxString destinationAddressText = 'แตะเพื่อเลือกบนแผนที่'.obs;

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  Future<void> _initialize() async {
    isLoading.value = true;
    await _fetchUserData();
    await _getCurrentUserLocation();
    isLoading.value = false;
  }

  Future<void> _fetchUserData() async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        userName.value = data['fullname'] ?? 'ผู้ใช้';
        userPhone.value = data['phone'] ?? 'ไม่มีเบอร์โทร';
        profileImageUrl.value = data['profile'] ?? profileImageUrl.value;
      }
    } catch (e) {
      userName.value = 'ไม่พบข้อมูล';
    }
  }

  Future<void> _getCurrentUserLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) serviceEnabled = await _location.requestService();
    if (!serviceEnabled) {
      Get.snackbar('ข้อผิดพลาด', 'กรุณาเปิด GPS เพื่อใช้งาน');
      return;
    }
    PermissionStatus permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
      if (permission != PermissionStatus.granted) {
        Get.snackbar('ข้อผิดพลาด', 'ไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง');
        return;
      }
    }
    currentUserLocation.value = await _location.getLocation();
  }

  Future<void> navigateToMapPicker() async {
    final initialLatLng = currentUserLocation.value != null
        ? LatLng(currentUserLocation.value!.latitude!,
            currentUserLocation.value!.longitude!)
        : const LatLng(13.7563, 100.5018); // Default Bangkok

    final result =
        await Get.to(() => MapPickerPage(initialLocation: initialLatLng));

    if (result != null && result is LatLng) {
      selectedDestinationLocation.value = result;
      destinationAddressText.value =
          'เลือกตำแหน่งแล้ว: ${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)}';
    }
  }

  Future<void> takePhoto() async {
    try {
      final pickedFile = await ImagePicker()
          .pickImage(source: ImageSource.camera, maxWidth: 800);
      if (pickedFile != null) imageFile.value = pickedFile;
    } catch (e) {
      Get.snackbar('เกิดข้อผิดพลาด', 'ไม่สามารถเปิดกล้องได้');
    }
  }

  void submitStep1() {
    if (detailController.text.isEmpty ||
        deliveryAddressDetailsController.text.isEmpty) {
      Get.snackbar('ข้อมูลไม่ครบ', 'กรุณากรอกรายละเอียดให้ครบถ้วน');
      return;
    }
    if (imageFile.value == null) {
      Get.snackbar('ข้อมูลไม่ครบ', 'กรุณาถ่ายรูปสินค้า');
      return;
    }
    if (currentUserLocation.value == null) {
      Get.snackbar('ข้อมูลไม่ครบ', 'ไม่พบตำแหน่งต้นทางของคุณ');
      return;
    }
    if (selectedDestinationLocation.value == null) {
      Get.snackbar('ข้อมูลไม่ครบ', 'กรุณาเลือกตำแหน่งปลายทางบนแผนที่');
      return;
    }
    step.value = 2;
  }

  void confirmStep2() => step.value = 3;
  void goBack() {
    if (step.value > 1 && step.value < 4) {
      step.value--;
    } else {
      Get.back();
    }
  }

  Future<void> completeSubmission() async {
    Get.dialog(const Center(child: CircularProgressIndicator()),
        barrierDismissible: false);

    try {
      // 1. Upload Image
      final cloudinary =
          CloudinaryPublic('dnutmbomv', 'delivery888'); // ! แก้เป็นของคุณ
      final response = await cloudinary
          .uploadFile(CloudinaryFile.fromFile(imageFile.value!.path));
      final imageUrl = response.secureUrl;

      // 2. Prepare Address Models
      final pickupAddress = AddressModel(
        detail: 'ตำแหน่งปัจจุบันของผู้ส่ง',
        gps: GeoPoint(currentUserLocation.value!.latitude!,
            currentUserLocation.value!.longitude!),
      );
      final deliveryAddress = AddressModel(
        detail: deliveryAddressDetailsController.text,
        gps: GeoPoint(selectedDestinationLocation.value!.latitude,
            selectedDestinationLocation.value!.longitude),
      );

      // 3. Create Order using the service function
      final docRef = await createOrder(
        customerId: uid,
        orderDetails: detailController.text,
        orderPicture: imageUrl,
        pickup: pickupAddress,
        delivery: deliveryAddress,
      );

      Get.back(); // Close loading dialog
      step.value = 4;

      Future.delayed(const Duration(seconds: 2), () {
        Get.off(
            () => OrderStatusPage(orderId: docRef.id, uid: uid, role: role));
      });
    } catch (e) {
      Get.back();
      Get.snackbar('เกิดข้อผิดพลาด', 'ไม่สามารถสร้างออเดอร์ได้: $e');
    }
  }
}

// ------------------------------------------------------------------
// Page 2: Send Package Page (UI)
// ------------------------------------------------------------------
class SendPackagePage extends StatelessWidget {
  final String uid;
  final int role;
  const SendPackagePage({super.key, required this.uid, required this.role});

  // Constants
  static const Color _primaryColor = Color(0xFFC70808);
  static const Color _backgroundColor = Color(0xFFFDE9E9);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SendPackageController(uid: uid, role: role));

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: _primaryColor));
        }

        return CustomScrollView(
          slivers: [
            _buildSliverAppBar(context, controller),
            SliverPadding(
              padding: const EdgeInsets.all(20.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Obx(() {
                    if (controller.step.value == 1)
                      return _buildStepOneForm(context, controller);
                    if (controller.step.value == 2)
                      return _buildStepTwoConfirmation(context, controller);
                    if (controller.step.value == 3)
                      return _buildStepThreeFinalConfirmation(controller);
                    if (controller.step.value == 4)
                      return _buildStepFourSuccess();
                    return const SizedBox.shrink(); // Fallback case
                  }),
                  const SizedBox(height: 20),
                  _buildProductListFooter(),
                ]),
              ),
            ),
          ],
        );
      }),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  // --- UI Widgets ---

  Widget _buildSliverAppBar(
      BuildContext context, SendPackageController controller) {
    return SliverAppBar(
      expandedHeight: 180.0,
      pinned: true,
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      leading: IconButton(
          icon: const Icon(Icons.arrow_back), onPressed: controller.goBack),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.zero,
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 60, bottom: 12),
          // ✅ FIX: WRAP TEXT WITH Obx
          child: Obx(() {
            return Text(
              'สวัสดีคุณ\n${controller.userName.value}',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, height: 1.2),
            );
          }),
        ),
        background: ClipPath(
          // ✅ FIX: UNCOMMENT CLIPPER
          clipper: CustomClipperWidget(),
          child: Container(
            color: _primaryColor,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 50, right: 20),
                child: Obx(() => CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      backgroundImage:
                          NetworkImage(controller.profileImageUrl.value),
                    )),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepOneForm(
      BuildContext context, SendPackageController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUserInfo(controller),
        const SizedBox(height: 15),
        const Text("ต้นทาง",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Obx(() => _buildInfoDisplay(
              controller.currentUserLocation.value != null
                  ? 'ตำแหน่งปัจจุบัน (อัตโนมัติ)'
                  : 'กำลังค้นหาตำแหน่ง...',
              Icons.my_location,
            )),
        const SizedBox(height: 15),
        const Text("ปลายทาง",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        _buildMapPickerField(controller),
        const SizedBox(height: 15),
        _buildTextField(controller.deliveryAddressDetailsController,
            'รายละเอียดปลายทาง (เช่น ชื่อตึก, ห้อง)', Icons.location_city),
        const SizedBox(height: 15),
        _buildPackageSection(controller),
        const SizedBox(height: 15),
        _buildTextField(controller.detailController, 'รายละเอียดสินค้า',
            Icons.note_alt_outlined,
            maxLines: 3),
        const SizedBox(height: 20),
        _buildPrimaryButton('ดำเนินการต่อ', controller.submitStep1),
      ],
    );
  }

  Widget _buildMapPickerField(SendPackageController controller) {
    return GestureDetector(
      onTap: controller.navigateToMapPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.map_outlined, color: _primaryColor),
            const SizedBox(width: 10),
            Expanded(
                child:
                    Obx(() => Text(controller.destinationAddressText.value))),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildStepTwoConfirmation(
      BuildContext context, SendPackageController controller) {
    return Column(
      children: [
        _buildUserInfo(controller),
        const SizedBox(height: 15),
        _buildConfirmSection(controller),
        const SizedBox(height: 20),
        _buildPrimaryButton('ยืนยันข้อมูล', controller.confirmStep2),
      ],
    );
  }

  Widget _buildStepThreeFinalConfirmation(SendPackageController controller) {
    return Column(
      children: [
        _buildConfirmSection(controller),
        const SizedBox(height: 20),
        _buildDialogBox(
          'คุณต้องการสร้างรายการส่งสินค้านี้ใช่หรือไม่',
          'แก้ไข',
          'ยืนยัน',
          () => controller.step.value = 1,
          controller.completeSubmission,
        ),
      ],
    );
  }

  Widget _buildStepFourSuccess() {
    return Column(
      children: [
        _buildSuccessDialog('สร้างรายการส่งของสำเร็จ!'),
        const SizedBox(height: 20),
        const Text('กำลังนำท่านไปยังหน้าติดตามสถานะ...'),
      ],
    );
  }

  Widget _buildUserInfo(SendPackageController controller) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Row(children: [
            const Icon(Icons.person, color: _primaryColor),
            const SizedBox(width: 8),
            Obx(() => Text('ผู้ส่ง: ${controller.userName.value}',
                style: const TextStyle(fontWeight: FontWeight.bold))),
          ]),
          const Divider(),
          Row(children: [
            const Icon(Icons.phone, color: _primaryColor),
            const SizedBox(width: 8),
            Obx(() => Text(controller.userPhone.value)),
          ]),
        ],
      ),
    );
  }

  Widget _buildPackageSection(SendPackageController controller) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Obx(() => controller.imageFile.value == null
              ? const Icon(Icons.image_search, color: Colors.grey, size: 60)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(controller.imageFile.value!.path),
                      width: 80, height: 80, fit: BoxFit.cover),
                )),
          TextButton.icon(
            onPressed: controller.takePhoto,
            icon: const Icon(Icons.camera_alt, color: _primaryColor),
            label: const Text('ถ่ายรูปสินค้า',
                style: TextStyle(color: _primaryColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmSection(SendPackageController controller) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          const Text('สรุปรายการ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          _buildConfirmRow(Icons.my_location, 'จาก:', 'ตำแหน่งปัจจุบันของคุณ'),
          // ✅ ถูกต้อง: อ่านค่า .text มาตรงๆ ไม่ต้องใช้ Obx
          _buildConfirmRow(Icons.location_on, 'ไปที่:',
              controller.deliveryAddressDetailsController.text),
          // ✅ ถูกต้อง: อ่านค่า .text มาตรงๆ ไม่ต้องใช้ Obx
          _buildConfirmRow(Icons.note_alt_outlined, 'รายละเอียด:',
              controller.detailController.text),
          const SizedBox(height: 10),
          Obx(() => controller.imageFile.value != null
              ? Center(
                  child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(controller.imageFile.value!.path),
                      height: 150, fit: BoxFit.cover),
                ))
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildInfoDisplay(String text, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: _primaryColor),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildConfirmRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: _primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Expanded(child: Text(value)),
      ]),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: _primaryColor),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
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
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        child: Text(text),
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
          Text(message,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: onCancel,
                      child: Text(cancelText,
                          style: const TextStyle(color: Colors.black)))),
              const SizedBox(width: 10),
              Expanded(
                  child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      child: Text(confirmText,
                          style: const TextStyle(color: Colors.white)))),
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
          Text(message,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildProductListFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('รายการล่าสุดของคุณ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 5)
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory, color: Colors.grey, size: 30),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
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
          BoxShadow(color: Colors.black12, offset: Offset(0, -2), blurRadius: 5)
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
              icon: Icon(Icons.history), label: 'ประวัติการส่ง'),
          BottomNavigationBarItem(
              icon: Icon(Icons.logout), label: 'ออกจากระบบ'),
        ],
        currentIndex: 0,
        onTap: (index) {},
      ),
    );
  }
}

// ✅ FIX: UNCOMMENT CUSTOM CLIPPER
// Custom Clipper สำหรับ Header
class CustomClipperWidget extends CustomClipper<ui.Path> {
  @override
  ui.Path getClip(Size size) {
    double h = size.height;
    double w = size.width;
    ui.Path path = ui.Path();
    path.lineTo(0, h * 0.85);
    path.quadraticBezierTo(w * 0.15, h * 0.95, w * 0.45, h * 0.85);
    path.quadraticBezierTo(w * 0.65, h * 0.75, w, h * 0.8);
    path.lineTo(w, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<ui.Path> oldClipper) => false;
}
