import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:delivery_project/page/order_status_page.dart';
import 'dart:developer';
import 'package:delivery_project/models/user_model.dart';

const Color _primaryColor = Color(0xFFC70808);
const Color _backgroundColor = Color(0xFFFDE9E9);

class SendPackageController extends GetxController {
  final String uid;
  final int role;
  SendPackageController({required this.uid, required this.role});

  final MapController mapDisplayController = MapController();
  final detailController = TextEditingController();
  final deliveryAddressController = TextEditingController();
  final receiverNameController = TextEditingController();
  final receiverPhoneController = TextEditingController();

  final Rx<XFile?> imageFile = Rx(null);
  final RxInt step = 1.obs;
  final RxBool isLoading = true.obs;
  final RxString userName = 'กำลังโหลด...'.obs;

  final RxList<UserModel> userList = <UserModel>[].obs;
  final Rx<Position?> currentUserLocation = Rx(null);
  final Rx<LatLng?> selectedDestinationLocation = Rx(null);
  final RxString destinationAddressText = 'แตะเพื่อเลือกบนแผนที่'.obs;
  StreamSubscription<Position>? _positionStreamSubscription;

  final Rx<UserModel?> selectedReceiver = Rx(null);

  @override
  void onInit() {
    super.onInit();
    _initialize();

    ever(selectedDestinationLocation, (LatLng? location) {
      if (location != null) {
        mapDisplayController.move(location, 17.0);
      }
    });
  }

  @override
  void onClose() {
    detailController.dispose();
    deliveryAddressController.dispose();
    receiverNameController.dispose();
    receiverPhoneController.dispose();
    _positionStreamSubscription?.cancel();
    mapDisplayController.dispose();
    super.onClose();
  }

  Future<void> _initialize() async {
    isLoading.value = true;
    await Future.wait([
      _fetchUserData(),
      _getCurrentUserLocation(),
      _fetchUsersForDropdown(),
    ]);
    isLoading.value = false;
  }

  Future<void> _fetchUserData() async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        userName.value = doc.data()?['fullname'] ?? 'ผู้ใช้';
      }
    } catch (e) {
      userName.value = 'ไม่พบข้อมูล';
    }
  }

  Future<void> _fetchUsersForDropdown() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 0)
          .get();

      final users = snapshot.docs
          .where((doc) => doc.id != uid)
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      userList.value = users;
    } catch (e) {
      log("Error fetching users for dropdown: $e");
    }
  }

  Future<void> _getCurrentUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Get.snackbar('ข้อผิดพลาด', 'กรุณาเปิด GPS เพื่อใช้งาน');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        Get.snackbar('ข้อผิดพลาด', 'ไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      Get.snackbar('ข้อผิดพลาด', 'การเข้าถึงตำแหน่งถูกปฏิเสธถาวร');
      return;
    }

    currentUserLocation.value = await Geolocator.getCurrentPosition();

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position? position) {
        if (position != null) {
          currentUserLocation.value = position;
        }
      },
    );
  }

  void onReceiverSelected(UserModel user) {
    Get.back();
    selectedReceiver.value = user;
    receiverNameController.text = user.fullname;
    receiverPhoneController.text = user.phone;

    bool hasDefault =
        user.defaultAddress != null && user.defaultAddress!.isNotEmpty;
    bool hasSecond =
        user.secondAddress != null && user.secondAddress!.isNotEmpty;

    if (hasDefault && hasSecond) {
      _showAddressSelectionDialog(user);
    } else if (hasDefault) {
      deliveryAddressController.text = user.defaultAddress!;
      if (user.defaultGPS != null) {
        selectedDestinationLocation.value =
            LatLng(user.defaultGPS!.latitude, user.defaultGPS!.longitude);
        destinationAddressText.value =
            'เลือกตำแหน่งแล้ว: ${user.defaultGPS!.latitude.toStringAsFixed(4)}, ...';
      }
    } else if (hasSecond) {
      deliveryAddressController.text = user.secondAddress!;
      if (user.secondGPS != null) {
        selectedDestinationLocation.value =
            LatLng(user.secondGPS!.latitude, user.secondGPS!.longitude);
        destinationAddressText.value =
            'เลือกตำแหน่งแล้ว: ${user.secondGPS!.latitude.toStringAsFixed(4)}, ...';
      }
    }
  }

  void _showAddressSelectionDialog(UserModel user) {
    Get.dialog(AlertDialog(
      title: const Text('เลือกที่อยู่ปลายทาง'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('ที่อยู่หลัก'),
            subtitle: Text(user.defaultAddress ?? ''),
            onTap: () {
              deliveryAddressController.text = user.defaultAddress!;
              if (user.defaultGPS != null) {
                selectedDestinationLocation.value = LatLng(
                    user.defaultGPS!.latitude, user.defaultGPS!.longitude);
                destinationAddressText.value =
                    'เลือกตำแหน่งแล้ว: ${user.defaultGPS!.latitude.toStringAsFixed(4)}, ...';
              }
              Get.back();
            },
          ),
          ListTile(
            title: const Text('ที่อยู่รอง'),
            subtitle: Text(user.secondAddress ?? ''),
            onTap: () {
              deliveryAddressController.text = user.secondAddress!;
              if (user.secondGPS != null) {
                selectedDestinationLocation.value =
                    LatLng(user.secondGPS!.latitude, user.secondGPS!.longitude);
                destinationAddressText.value =
                    'เลือกตำแหน่งแล้ว: ${user.secondGPS!.latitude.toStringAsFixed(4)}, ...';
              }
              Get.back();
            },
          )
        ],
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text("ยกเลิก"))
      ],
    ));
  }

  void clearReceiverSelection() {
    selectedReceiver.value = null;
    receiverNameController.clear();
    receiverPhoneController.clear();
    deliveryAddressController.clear();
    selectedDestinationLocation.value = null;
    destinationAddressText.value = 'แตะเพื่อเลือกบนแผนที่';

    if (currentUserLocation.value != null) {
      mapDisplayController.move(
          LatLng(currentUserLocation.value!.latitude,
              currentUserLocation.value!.longitude),
          17.0);
    }
  }

  Future<void> selectDestinationOnMap() async {
    final initialLatLng = currentUserLocation.value != null
        ? LatLng(currentUserLocation.value!.latitude,
            currentUserLocation.value!.longitude)
        : const LatLng(16.2426, 103.2579);

    final result = await Get.bottomSheet<LatLng>(
      _MapPickerModal(initialLocation: initialLatLng),
      isScrollControlled: true,
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
          'detail': 'ตำแหน่งปัจจุบันของผู้ส่ง',
          'gps': GeoPoint(currentUserLocation.value!.latitude,
              currentUserLocation.value!.longitude),
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

class SendPackagePage extends StatelessWidget {
  final String uid;
  final int role;
  const SendPackagePage({super.key, required this.uid, required this.role});

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
                    switch (controller.step.value) {
                      case 1:
                        return _buildStepOneForm(context, controller);
                      case 2:
                        return _buildStepTwoConfirmation(context, controller);
                      case 3:
                        return _buildStepThreeFinalConfirmation(controller);
                      case 4:
                        return _buildStepFourSuccess();
                      default:
                        return const SizedBox.shrink();
                    }
                  }),
                ]),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSliverAppBar(
      BuildContext context, SendPackageController controller) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      leading: IconButton(
          icon: const Icon(Icons.arrow_back), onPressed: controller.goBack),
      flexibleSpace: const FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(left: 60, bottom: 12),
        title: Text('สร้างรายการส่งของ',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ),
    );
  }

  Widget _buildStepOneForm(
      BuildContext context, SendPackageController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("ข้อมูลผู้รับ",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildReceiverSelectionField(context, controller),
        const SizedBox(height: 15),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text("หรือ", style: TextStyle(color: Colors.grey)),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 10),
        const Center(
          child: Text("กรอกข้อมูลผู้รับด้วยตนเอง",
              style: TextStyle(fontSize: 16, color: Colors.black54)),
        ),
        _buildReceiverProfileDisplay(controller),
        Obx(() => _buildTextField(controller.receiverNameController,
            'ชื่อผู้รับ', Icons.person_outline,
            isReadOnly: controller.selectedReceiver.value != null)),
        const SizedBox(height: 15),
        Obx(() => _buildTextField(controller.receiverPhoneController,
            'เบอร์โทรผู้รับ', Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            isReadOnly: controller.selectedReceiver.value != null)),
        const SizedBox(height: 15),
        Obx(() => _buildTextField(controller.deliveryAddressController,
            'รายละเอียดที่อยู่ปลายทาง', Icons.location_city,
            maxLines: 3,
            isReadOnly: controller.selectedReceiver.value != null)),
        const SizedBox(height: 15),
        _buildMapPickerField(controller),
        const SizedBox(height: 25),
        _buildUserInfoMap(controller),
        const Text("ข้อมูลสินค้า",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildPackageSection(controller),
        const SizedBox(height: 15),
        _buildTextField(
          controller.detailController,
          'รายละเอียดสินค้า (เช่น เสื้อผ้า 1 กล่อง)',
          Icons.note_alt_outlined,
        ),
        const SizedBox(height: 20),
        _buildPrimaryButton('ดำเนินการต่อ', controller.submitStep1),
      ],
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {int maxLines = 1,
      TextInputType? keyboardType,
      bool isReadOnly = false}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: isReadOnly,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: isReadOnly ? Colors.grey.shade200 : Colors.white,
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

  Widget _buildReceiverSelectionField(
      BuildContext context, SendPackageController controller) {
    return Obx(() {
      final selectedUser = controller.selectedReceiver.value;

      String titleText;
      Color borderColor;
      FontWeight titleWeight;
      Color titleColor;

      if (selectedUser != null) {
        borderColor = Colors.green;
        titleText = 'ผู้รับ: ${selectedUser.fullname}';
        titleWeight = FontWeight.bold;
        titleColor = Colors.black;
      } else {
        borderColor = Colors.grey.shade300;
        titleText = 'แตะเพื่อเลือก/ค้นหาผู้รับจากรายชื่อ';
        titleWeight = FontWeight.normal;
        titleColor = Colors.grey.shade600;
      }

      return GestureDetector(
        onTap: selectedUser == null
            ? () => _showUserSelectionDialog(context, controller)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(
                Icons.contact_phone,
                color: selectedUser != null ? Colors.green : _primaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titleText,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: titleWeight,
                  ),
                ),
              ),
              if (selectedUser != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red),
                  onPressed: controller.clearReceiverSelection,
                )
              else
                const Icon(Icons.search, color: Colors.grey),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildReceiverProfileDisplay(SendPackageController controller) {
    return Obx(() {
      final selectedUser = controller.selectedReceiver.value;
      if (selectedUser == null) {
        return const SizedBox(height: 15);
      }

      final String imageUrl = selectedUser.profile;
      Widget profileAvatar;

      if (imageUrl.isNotEmpty) {
        profileAvatar = CircleAvatar(
          radius: 70,
          backgroundImage: NetworkImage(imageUrl),
          onBackgroundImageError: (e, s) {
            profileAvatar = const CircleAvatar(
              radius: 70,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white, size: 30),
            );
          },
        );
      } else {
        profileAvatar = const CircleAvatar(
          radius: 30,
          backgroundColor: _primaryColor,
          child: Icon(Icons.person, color: Colors.white, size: 30),
        );
      }

      return Container(
        padding: const EdgeInsets.only(top: 20, bottom: 15),
        child: Center(
          child: profileAvatar,
        ),
      );
    });
  }

  void _showUserSelectionDialog(
      BuildContext context, SendPackageController controller) {
    Get.dialog(
      AlertDialog(
        title: const Text('เลือก/ค้นหาผู้รับ'),
        content: _ReceiverSearchModalContent(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("ปิด"),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoMap(SendPackageController controller) {
    final initialCenter = controller.currentUserLocation.value != null
        ? LatLng(controller.currentUserLocation.value!.latitude,
            controller.currentUserLocation.value!.longitude)
        : const LatLng(16.2426, 103.2579);

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
        child: Stack(
          children: [
            FlutterMap(
              mapController: controller.mapDisplayController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 17.0,
              ),
              children: [
                TileLayer(
                    urlTemplate:
                        'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=cb153d15cb4e41f59e25cfda6468f1a0'),
                Obx(() {
                  final receiverLocation =
                      controller.selectedDestinationLocation.value;
                  final senderLocation = controller.currentUserLocation.value;

                  LatLng center;
                  Widget markerChild;

                  if (receiverLocation != null) {
                    center = receiverLocation;
                    markerChild = const Icon(Icons.location_pin,
                        color: _primaryColor, size: 40);
                  } else if (senderLocation != null) {
                    center = LatLng(
                        senderLocation.latitude, senderLocation.longitude);
                    markerChild = const Icon(Icons.my_location,
                        color: Colors.blue, size: 30);
                  } else {
                    return const MarkerLayer(markers: []);
                  }

                  return MarkerLayer(markers: [
                    Marker(
                      point: center,
                      child: markerChild,
                    )
                  ]);
                }),
              ],
            ),
            Obx(() {
              final textLabel =
                  controller.selectedDestinationLocation.value != null
                      ? "ตำแหน่งผู้รับ (ปลายทาง)"
                      : "ตำแหน่งของคุณ (ต้นทาง)";
              return Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Text(
                    textLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPickerField(SendPackageController controller) {
    return GestureDetector(
      onTap: controller.selectDestinationOnMap,
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
          _buildConfirmRow(Icons.store, 'จาก:', 'ตำแหน่งปัจจุบันของคุณ'),
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

class _ReceiverSearchModalContent extends StatefulWidget {
  final SendPackageController controller;
  const _ReceiverSearchModalContent({required this.controller});

  @override
  State<_ReceiverSearchModalContent> createState() =>
      _ReceiverSearchModalContentState();
}

class _ReceiverSearchModalContentState
    extends State<_ReceiverSearchModalContent> {
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _filteredUsers = widget.controller.userList;
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterUsers);
    _searchController.dispose();
    super.dispose();
  }

  void _filterUsers() {
    final searchTerm = _searchController.text.toLowerCase();
    setState(() {
      if (searchTerm.isEmpty) {
        _filteredUsers = widget.controller.userList;
      } else {
        _filteredUsers = widget.controller.userList.where((user) {
          final nameMatches = user.fullname.toLowerCase().contains(searchTerm);
          final phoneMatches = user.phone.contains(searchTerm);
          return nameMatches || phoneMatches;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.maxFinite,
      height: MediaQuery.of(context).size.height * 0.5,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'ค้นหาด้วยชื่อ หรือ เบอร์โทร',
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: _filteredUsers.isEmpty
                ? const Center(child: Text('ไม่พบรายชื่อ'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final UserModel user = _filteredUsers[index];

                      final String imageUrl = user.profile;
                      Widget leadingAvatar;
                      if (imageUrl.isNotEmpty) {
                        leadingAvatar = CircleAvatar(
                          backgroundImage: NetworkImage(imageUrl),
                          onBackgroundImageError: (exception, stackTrace) {
                            leadingAvatar = const CircleAvatar(
                              backgroundColor: Colors.grey,
                              child: Icon(Icons.person, color: Colors.white),
                            );
                          },
                        );
                      } else {
                        leadingAvatar = const CircleAvatar(
                          backgroundColor: Colors.grey,
                          child: Icon(Icons.person, color: Colors.white),
                        );
                      }

                      return ListTile(
                        leading: leadingAvatar,
                        title: Text(user.fullname),
                        subtitle: Text(user.phone),
                        onTap: () {
                          widget.controller.onReceiverSelected(user);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

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
