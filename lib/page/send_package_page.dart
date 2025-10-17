// send_package_page.dart

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:delivery_project/page/order_status_page.dart';

// ------------------------------------------------------------------
// Controller (จัดการ Logic ทั้งหมดของหน้า)
// ------------------------------------------------------------------
class SendPackageController extends GetxController {
  final String uid;
  final int role;
  SendPackageController({required this.uid, required this.role});

  // --- Form Controllers ---
  final detailController = TextEditingController();
  final pickupAddressController = TextEditingController();
  final deliveryAddressController = TextEditingController();
  final receiverNameController = TextEditingController();
  final receiverPhoneController = TextEditingController();

  // --- State ---
  final Rx<XFile?> imageFile = Rx(null);
  final RxInt step = 1.obs;
  final RxBool isLoading = true.obs;

  // User (Sender) Info
  final RxString userName = 'กำลังโหลด...'.obs;

  // Location
  final Location _location = Location();
  final Rx<LocationData?> currentUserLocation = Rx(null);
  final Rx<LatLng?> selectedDestinationLocation = Rx(null);
  final RxString destinationAddressText = 'แตะเพื่อเลือกบนแผนที่'.obs;
  StreamSubscription<LocationData>? _locationSubscription;

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  @override
  void onClose() {
    detailController.dispose();
    pickupAddressController.dispose();
    deliveryAddressController.dispose();
    receiverNameController.dispose();
    receiverPhoneController.dispose();
    _locationSubscription?.cancel();
    super.onClose();
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
    _locationSubscription = _location.onLocationChanged.listen((locationData) {
      currentUserLocation.value = locationData;
    });
  }

  // **แก้ไข:** เปลี่ยนจากการไปหน้าใหม่ เป็นการเปิด Modal Bottom Sheet
  Future<void> selectDestinationOnMap() async {
    final initialLatLng = currentUserLocation.value != null
        ? LatLng(currentUserLocation.value!.latitude!,
            currentUserLocation.value!.longitude!)
        : const LatLng(16.2426, 103.2579);

    // ใช้ Get.bottomSheet เพื่อเปิด Modal
    final result = await Get.bottomSheet<LatLng>(
      _MapPickerModal(initialLocation: initialLatLng),
      isScrollControlled: true, // ทำให้ Modal ขยายได้เต็มที่
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );

    if (result != null) {
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
        pickupAddressController.text.isEmpty ||
        deliveryAddressController.text.isEmpty ||
        receiverNameController.text.isEmpty ||
        receiverPhoneController.text.isEmpty ||
        imageFile.value == null ||
        currentUserLocation.value == null ||
        selectedDestinationLocation.value == null) {
      Get.snackbar(
          'ข้อมูลไม่ครบ', 'กรุณากรอกข้อมูลทั้งหมดและเลือกตำแหน่งให้ครบถ้วน');
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
      final cloudinary = CloudinaryPublic('dnutmbomv', 'delivery888');
      final response = await cloudinary
          .uploadFile(CloudinaryFile.fromFile(imageFile.value!.path));
      final imageUrl = response.secureUrl;

      final orderData = {
        'customerId': uid,
        'riderId': null,
        'orderDetails': detailController.text,
        'orderImageUrl': imageUrl,
        'pickupAddress': {
          'detail': pickupAddressController.text,
          'gps': GeoPoint(currentUserLocation.value!.latitude!,
              currentUserLocation.value!.longitude!),
        },
        'deliveryAddress': {
          'detail': deliveryAddressController.text,
          'gps': GeoPoint(selectedDestinationLocation.value!.latitude,
              selectedDestinationLocation.value!.longitude),
          'receiverName': receiverNameController.text,
          'receiverPhone': receiverPhoneController.text,
        },
        'currentStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'statusHistory': [
          {
            'imgOfStatus': imageUrl,
            'status': 'pending',
            'timestamp': Timestamp.now()
          }
        ],
      };
      DocumentReference docRef =
          await FirebaseFirestore.instance.collection('orders').add(orderData);
      Get.back();
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
// Page (UI)
// ------------------------------------------------------------------
class SendPackagePage extends StatelessWidget {
  final String uid;
  final int role;
  const SendPackagePage({super.key, required this.uid, required this.role});

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
                    return const SizedBox.shrink();
                  }),
                ]),
              ),
            ),
          ],
        );
      }),
    );
  }

  // (โค้ด UI Widgets ทั้งหมดสามารถใช้ของเดิมได้)
  // ...
  Widget _buildSliverAppBar(
      BuildContext context, SendPackageController controller) {
    return SliverAppBar(
      expandedHeight: 120.0,
      pinned: true,
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      leading: IconButton(
          icon: const Icon(Icons.arrow_back), onPressed: controller.goBack),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 60, bottom: 12),
        title: const Text('สร้างรายการส่งของ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStepOneForm(
      BuildContext context, SendPackageController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("ข้อมูลผู้ส่ง",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildUserInfoMap(controller),
        const SizedBox(height: 15),
        _buildTextField(controller.pickupAddressController,
            'รายละเอียดที่อยู่ต้นทาง (เช่น ตึก, ห้อง)', Icons.store),
        const SizedBox(height: 25),
        const Text("ข้อมูลผู้รับ",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildTextField(controller.receiverNameController, 'ชื่อผู้รับ',
            Icons.person_outline),
        const SizedBox(height: 15),
        _buildTextField(controller.receiverPhoneController, 'เบอร์โทรผู้รับ',
            Icons.phone_outlined,
            keyboardType: TextInputType.phone),
        const SizedBox(height: 15),
        _buildTextField(controller.deliveryAddressController,
            'รายละเอียดที่อยู่ปลายทาง', Icons.location_city),
        const SizedBox(height: 15),
        _buildMapPickerField(controller),
        const SizedBox(height: 25),
        const Text("ข้อมูลสินค้า",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildPackageSection(controller),
        const SizedBox(height: 15),
        _buildTextField(controller.detailController,
            'รายละเอียดสินค้า (เช่น เสื้อผ้า 1 กล่อง)', Icons.note_alt_outlined,
            maxLines: 3),
        const SizedBox(height: 20),
        _buildPrimaryButton('ดำเนินการต่อ', controller.submitStep1),
      ],
    );
  }

  Widget _buildUserInfoMap(SendPackageController controller) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Obx(() {
          final location = controller.currentUserLocation.value;
          if (location == null) {
            return const Center(child: Text("กำลังค้นหาตำแหน่งของคุณ..."));
          }
          final center = LatLng(location.latitude!, location.longitude!);
          return FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 17.0,
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              TileLayer(
                  urlTemplate:
                      'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=cb153d15cb4e41f59e25cfda6468f1a0'),
              MarkerLayer(markers: [
                Marker(
                  point: center,
                  child: const Icon(Icons.my_location,
                      color: Colors.blue, size: 30),
                )
              ])
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMapPickerField(SendPackageController controller) {
    return GestureDetector(
      onTap:
          controller.selectDestinationOnMap, // **แก้ไข:** เรียกใช้ฟังก์ชันใหม่
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
              child: Text('สรุปรายการ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          const Divider(height: 20),
          const Text("ข้อมูลผู้ส่ง",
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: _primaryColor)),
          Obx(() => _buildConfirmRow(
              Icons.person, 'ชื่อ:', controller.userName.value)),
          _buildConfirmRow(
              Icons.store, 'จาก:', controller.pickupAddressController.text),
          const Divider(height: 20),
          const Text("ข้อมูลผู้รับ",
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: _primaryColor)),
          _buildConfirmRow(Icons.person_outline, 'ชื่อ:',
              controller.receiverNameController.text),
          _buildConfirmRow(Icons.phone_outlined, 'เบอร์:',
              controller.receiverPhoneController.text),
          _buildConfirmRow(Icons.location_on, 'ไปที่:',
              controller.deliveryAddressController.text),
          const Divider(height: 20),
          _buildConfirmRow(Icons.note_alt_outlined, 'รายละเอียด:',
              controller.detailController.text),
          const SizedBox(height: 15),
          if (controller.imageFile.value != null)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(controller.imageFile.value!.path),
                    height: 150, fit: BoxFit.cover),
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
          Icon(icon, color: Colors.grey.shade700, size: 20),
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
      {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
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
}

// ------------------------------------------------------------------
// **เพิ่ม:** WIDGET สำหรับ Modal เลือกแผนที่ (ย้ายมาจากไฟล์เดิม)
// ------------------------------------------------------------------
class _MapPickerModal extends StatefulWidget {
  final LatLng initialLocation;
  const _MapPickerModal({required this.initialLocation});

  @override
  State<_MapPickerModal> createState() => _MapPickerModalState();
}

class _MapPickerModalState extends State<_MapPickerModal> {
  late LatLng _selectedLocation;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'เลื่อนแผนที่เพื่อปักหมุดปลายทาง',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Stack(
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
                            'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=cb153d15cb4e41f59e25cfda6468f1a0'),
                  ],
                ),
                const Center(
                    child: Icon(Icons.location_pin,
                        size: 50, color: Color(0xFFC70808))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('ยืนยันตำแหน่งนี้'),
                onPressed: () => Get.back(result: _selectedLocation),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC70808),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
