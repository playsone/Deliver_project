import 'dart:developer';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

// ตรวจสอบว่า path ไปยัง model ของคุณถูกต้อง
import 'package:delivery_project/models/user_model.dart';

class EditProfilePage extends StatefulWidget {
  final String uid;
  final int role;
  const EditProfilePage({super.key, required this.uid, required this.role});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isDataInitialized = false;

  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _password2Controller = TextEditingController();
  final _addressController = TextEditingController();
  final _gpsController = TextEditingController();
  final _address2Controller = TextEditingController();
  final _gps2Controller = TextEditingController();
  final _vehicleRegController = TextEditingController();

  // State Variables
  UserModel? _user;
  File? _profileImageFile;
  File? _vehicleImageFile;
  String _profileImageUrl = '';
  String _vehicleImageUrl = '';
  LatLng? _defaultMarkerPos;
  LatLng? _secondMarkerPos;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _password2Controller.dispose();
    _addressController.dispose();
    _gpsController.dispose();
    _address2Controller.dispose();
    _gps2Controller.dispose();
    _vehicleRegController.dispose();
    super.dispose();
  }

  //----------- CORE LOGIC FUNCTIONS -----------//

  Future<UserModel> fetchUser(String uid) async {
    final docSnapshot =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (!docSnapshot.exists) {
      throw Exception('ไม่พบผู้ใช้งาน');
    }
    return UserModel.fromFirestore(docSnapshot);
  }

  // --- ⭐️ แก้ไข: ปรับ Logic การดึงข้อมูล ---
  void _initializeData(UserModel user) {
    if (_isDataInitialized) return;
    _user = user;
    _nameController.text = user.fullname;
    _phoneController.text = user.phone;
    _profileImageUrl = user.profile;

    if (user.role == 0) {
      // Logic สำหรับ User ทั่วไป (ดึงที่อยู่ 1 และ 2)
      _addressController.text = user.defaultAddress ?? '';
      if (user.defaultGPS != null) {
        _defaultMarkerPos =
            LatLng(user.defaultGPS!.latitude, user.defaultGPS!.longitude);
        _gpsController.text =
            "${_defaultMarkerPos!.latitude.toStringAsFixed(6)}, ${_defaultMarkerPos!.longitude.toStringAsFixed(6)}";
      }
      _address2Controller.text = user.secondAddress ?? '';
      if (user.secondGPS != null) {
        _secondMarkerPos =
            LatLng(user.secondGPS!.latitude, user.secondGPS!.longitude);
        _gps2Controller.text =
            "${_secondMarkerPos!.latitude.toStringAsFixed(6)}, ${_secondMarkerPos!.longitude.toStringAsFixed(6)}";
      }
    } else if (user.role == 1) {
      // Logic สำหรับ Rider (ไม่ดึงที่อยู่/GPS)
      _vehicleRegController.text = user.vehicleNo ?? '';
      _vehicleImageUrl = user.vehiclePicture ?? '';
    }

    _isDataInitialized = true;
  }

  Future<String?> _uploadImage(File imageFile) async {
    const String cloudName = 'dvh40wpmm';
    const String uploadPreset = 'gameshop_images';
    final url =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final decodedData = json.decode(responseData);
        return decodedData['secure_url'];
      }
    } catch (e) {
      log('Image Upload Error: $e');
    }
    return null;
  }

  // --- ⭐️ แก้ไข: ปรับ Logic การบันทึกข้อมูล ---
  Future<void> _saveProfile() async {
    if (_passwordController.text.isNotEmpty &&
        _passwordController.text != _password2Controller.text) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("รหัสผ่านใหม่ไม่ตรงกัน!")));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFC70808))),
    );

    final user = _auth.currentUser;
    if (user == null) {
      Navigator.of(context).pop(); // Dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ไม่พบข้อมูลผู้ใช้ปัจจุบัน")));
      return;
    }

    try {
      String? newProfileUrl;
      String? newVehicleUrl;
      if (_profileImageFile != null) {
        newProfileUrl = await _uploadImage(_profileImageFile!);
      }
      if (_vehicleImageFile != null) {
        newVehicleUrl = await _uploadImage(_vehicleImageFile!);
      }

      final Map<String, dynamic> dataToUpdate = {
        'fullname': _nameController.text
      };
      if (newProfileUrl != null) dataToUpdate['profile'] = newProfileUrl;

      if (widget.role == 0) {
        // บันทึกข้อมูลสำหรับ User
        dataToUpdate.addAll({
          'defaultAddress': _addressController.text,
          'secondAddress': _address2Controller.text,
        });
        if (_defaultMarkerPos != null) {
          dataToUpdate['defaultGPS'] = GeoPoint(
              _defaultMarkerPos!.latitude, _defaultMarkerPos!.longitude);
        }
        if (_secondMarkerPos != null) {
          dataToUpdate['secondGPS'] =
              GeoPoint(_secondMarkerPos!.latitude, _secondMarkerPos!.longitude);
        }
      } else if (widget.role == 1) {
        // บันทึกข้อมูลสำหรับ Rider (ไม่มีที่อยู่/GPS)
        dataToUpdate.addAll({
          'vehicle_no': _vehicleRegController.text,
        });
        if (newVehicleUrl != null) {
          dataToUpdate['vehicle_picture'] = newVehicleUrl;
        }
      }
      await db.collection('users').doc(_user!.uid).update(dataToUpdate);

      if (_passwordController.text.isNotEmpty) {
        await user.updatePassword(_passwordController.text);
      }

      Navigator.of(context).pop(); // ปิด Loading
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("บันทึกข้อมูลสำเร็จ!"),
        backgroundColor: Colors.green,
      ));
    } on FirebaseAuthException catch (e) {
      Navigator.of(context).pop(); // ปิด Loading ก่อนแสดง Dialog

      if (e.code == 'requires-recent-login') {
        final currentPassword = await _showReauthDialog();
        if (currentPassword == null || currentPassword.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("ยกเลิกการดำเนินการ")));
          return;
        }

        try {
          AuthCredential credential = EmailAuthProvider.credential(
              email: user.email!, password: currentPassword);
          await user.reauthenticateWithCredential(credential);
          await user.updatePassword(_passwordController.text);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("บันทึกข้อมูลและอัปเดตรหัสผ่านสำเร็จ!"),
            backgroundColor: Colors.green,
          ));
        } on FirebaseAuthException catch (reauthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("ยืนยันตัวตนไม่สำเร็จ: ${reauthError.message}")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("เกิดข้อผิดพลาด: ${e.message}")));
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาดไม่คาดคิด: $e")));
    }
  }

  // ... (โค้ดส่วนอื่น ๆ ที่ไม่เปลี่ยนแปลง) ...
  Future<String?> _showReauthDialog() async {
    final passwordController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("ยืนยันตัวตนอีกครั้ง"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  "เพื่อความปลอดภัย กรุณากรอกรหัสผ่านปัจจุบันของคุณเพื่อดำเนินการต่อ"),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'รหัสผ่านปัจจุบัน',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text("ยกเลิก"),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(passwordController.text),
              child: const Text("ยืนยัน"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openMapPicker({required int target}) async {
    LatLng initialPoint = target == 1
        ? (_defaultMarkerPos ?? const LatLng(16.240683, 103.254257))
        : (_secondMarkerPos ?? const LatLng(16.240683, 103.254257));

    LatLng? selectedPoint = await showDialog<LatLng>(
      context: context,
      builder: (context) => MapPickerModal(initialLatLng: initialPoint),
    );

    if (selectedPoint != null) {
      setState(() {
        if (target == 1) {
          _defaultMarkerPos = selectedPoint;
          _gpsController.text =
              "${selectedPoint.latitude.toStringAsFixed(6)}, ${selectedPoint.longitude.toStringAsFixed(6)}";
          _updateAddressFromCoordinates(selectedPoint, _addressController);
        } else {
          _secondMarkerPos = selectedPoint;
          _gps2Controller.text =
              "${selectedPoint.latitude.toStringAsFixed(6)}, ${selectedPoint.longitude.toStringAsFixed(6)}";
          _updateAddressFromCoordinates(selectedPoint, _address2Controller);
        }
      });
    }
  }

  Future<void> _updateAddressFromCoordinates(
      LatLng point, TextEditingController controller) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
          point.latitude, point.longitude,
          localeIdentifier: "th_TH");
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final addressLine =
            "${p.street}, ${p.subLocality}, ${p.locality}, ${p.subAdministrativeArea}, ${p.administrativeArea} ${p.postalCode}"
                .replaceAll(' ,', ',');
        controller.text = addressLine.trim();
      }
    } catch (e) {
      log("Reverse Geocoding Error: $e");
    }
  }

  Future<void> _pickImage({required bool isProfile}) async {
    final source = await _showImageSourceActionSheet();
    if (source == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: source, imageQuality: 70);

    if (image != null) {
      setState(() {
        if (isProfile) {
          _profileImageFile = File(image.path);
        } else {
          _vehicleImageFile = File(image.path);
        }
      });
    }
  }

  Future<ImageSource?> _showImageSourceActionSheet() async {
    return await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('ถ่ายรูป'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกจากคลังภาพ'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  //----------- BUILD METHOD & WIDGETS -----------//
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('แก้ไขข้อมูลส่วนตัว',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFFC70808),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<UserModel>(
        future: fetchUser(widget.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFC70808)));
          }
          if (snapshot.hasError) {
            return Center(child: Text("เกิดข้อผิดพลาด: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("ไม่พบข้อมูลผู้ใช้"));
          }

          _initializeData(snapshot.data!);

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildProfileSection(),
                  if (widget.role == 1) ...[
                    const SizedBox(height: 15),
                    const Text("รูปรถ",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54)),
                    const SizedBox(height: 8),
                    _buildVehicleImageSection(),
                  ],
                  const SizedBox(height: 20),
                  _buildCommonFields(),
                  if (widget.role == 0) _buildUserSpecificFields(),
                  if (widget.role == 1) _buildRiderSpecificFields(),
                  const SizedBox(height: 30),
                  _buildSaveButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileSection() {
    return InkWell(
      onTap: () => _pickImage(isProfile: true),
      child: CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: _profileImageFile != null
            ? FileImage(_profileImageFile!)
            : (_profileImageUrl.isNotEmpty
                ? NetworkImage(_profileImageUrl)
                : null) as ImageProvider?,
        child: _profileImageFile == null && _profileImageUrl.isEmpty
            ? Icon(Icons.person, size: 60, color: Colors.grey.shade400)
            : null,
      ),
    );
  }

  Widget _buildVehicleImageSection() {
    return InkWell(
      onTap: () => _pickImage(isProfile: false),
      child: Container(
        height: 150,
        width: 250,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
          image: _vehicleImageFile != null
              ? DecorationImage(
                  image: FileImage(_vehicleImageFile!), fit: BoxFit.cover)
              : (_vehicleImageUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(_vehicleImageUrl), fit: BoxFit.cover)
                  : null),
        ),
        child: _vehicleImageFile == null && _vehicleImageUrl.isEmpty
            ? Center(
                child: Icon(Icons.directions_car,
                    size: 60, color: Colors.grey.shade400))
            : null,
      ),
    );
  }

  Widget _buildCommonFields() {
    return Column(
      children: [
        _buildTextFieldWithLabel('ชื่อ-สกุล', _nameController),
        const SizedBox(height: 20),
        _buildTextFieldWithLabel('หมายเลขโทรศัพท์', _phoneController,
            isReadOnly: true),
        const SizedBox(height: 20),
        _buildTextFieldWithLabel('รหัสผ่านใหม่', _passwordController,
            isPassword: true),
        const SizedBox(height: 20),
        _buildTextFieldWithLabel('ยืนยันรหัสผ่านใหม่', _password2Controller,
            isPassword: true),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildUserSpecificFields() {
    return Column(
      children: [
        _buildTextFieldWithLabel('ที่อยู่หลัก', _addressController),
        const SizedBox(height: 20),
        _buildTextFieldWithLabel('พิกัด GPS หลัก', _gpsController,
            isReadOnly: true, onTap: () => _openMapPicker(target: 1)),
        const SizedBox(height: 30),
        _buildTextFieldWithLabel('ที่อยู่รอง', _address2Controller),
        const SizedBox(height: 20),
        _buildTextFieldWithLabel('พิกัด GPS รอง', _gps2Controller,
            isReadOnly: true, onTap: () => _openMapPicker(target: 2)),
      ],
    );
  }

  // --- ⭐️ แก้ไข: ฟอร์มสำหรับ Rider ---
  Widget _buildRiderSpecificFields() {
    return Column(
      children: [
        _buildTextFieldWithLabel('เลขทะเบียนรถ', _vehicleRegController),
        // ลบฟิลด์ที่อยู่และ GPS ออกจากส่วนนี้
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveProfile,
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC70808),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
        child: const Text('บันทึกข้อมูล',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTextFieldWithLabel(
    String label,
    TextEditingController controller, {
    VoidCallback? onTap,
    bool isReadOnly = false,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black54)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: isReadOnly,
          obscureText: isPassword,
          onTap: onTap,
          decoration: InputDecoration(
            filled: true,
            fillColor: isReadOnly ? Colors.grey.shade300 : Colors.grey.shade200,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}

// MapPickerModal (ไม่มีการเปลี่ยนแปลง)
class MapPickerModal extends StatefulWidget {
  final LatLng initialLatLng;
  const MapPickerModal({super.key, required this.initialLatLng});

  @override
  State<MapPickerModal> createState() => _MapPickerModalState();
}

class _MapPickerModalState extends State<MapPickerModal> {
  late LatLng _currentMarkerPos;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _currentMarkerPos = widget.initialLatLng;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("เลือกพิกัด"),
      contentPadding: const EdgeInsets.all(0),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentMarkerPos,
            initialZoom: 16,
            onTap: (tapPosition, point) {
              setState(() {
                _currentMarkerPos = point;
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=cb153d15cb4e41f59e25cfda6468f1a0',
              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(markers: [
              Marker(
                point: _currentMarkerPos,
                width: 80,
                height: 80,
                child:
                    const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("ยกเลิก"),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(_currentMarkerPos);
          },
          child: const Text("ยืนยันตำแหน่ง"),
        ),
      ],
    );
  }
}
