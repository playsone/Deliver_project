import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/get_navigation.dart';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final ImagePicker _picker = ImagePicker();
  bool _isRider = false;
  XFile? _profileImage;
  XFile? _vehicleImage;
  File? _profileImagePath;
  File? _vehicleImagePath;
  String _profileImageUrl = '';
  String _vehicleImageUrl = '';

  // Controllers สำหรับการจัดการข้อมูลในฟอร์ม
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController =
      TextEditingController(); // ช่องที่อยู่หลัก (กรอกเอง)
  final _address2Controller =
      TextEditingController(); // ช่องที่อยู่ 2 (กรอกเอง)
  final _gpsController = TextEditingController(); // ช่องพิกัด GPS หลัก
  final _gps2Controller =
      TextEditingController(); // *** เพิ่ม: ช่องพิกัด GPS 2 ***
  final _vehicleRegController = TextEditingController();

  final LatLng _defaultLocation = const LatLng(16.243785, 103.251383);

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
    _gps2Controller.dispose(); // *** เพิ่ม: Dispose Controller ใหม่ ***
    _vehicleRegController.dispose();
    super.dispose();
  }

  phoneToEmail(String phone) {
    return "${phone.trim()}@e.com";
  }

  register() async {
    log("get in reg");
    if (!_formKey.currentState!.validate()) {
      log("Get to it");
      return Get.defaultDialog(
        title: "ข้อมูลไม่ถูกต้อง",
        titleStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.redAccent,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.warning_amber_rounded,
                size: 60, color: Colors.redAccent),
            SizedBox(height: 10),
            Text(
              "โปรดตรวจสอบข้อมูลอีกครั้ง",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
        textConfirm: "ตกลง",
        confirmTextColor: Colors.white,
        buttonColor: Colors.redAccent,
        radius: 20,
        barrierDismissible: false,

        // ทำพื้นหลัง dialog โปร่งแสง
        backgroundColor: Colors.white.withOpacity(0.9),

        onConfirm: () {
          Get.back();
        },
      );
    }
    log("here 0");
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: _phoneController.text.trim())
        .get();

    if (query.docs.isNotEmpty) {
      return Get.defaultDialog(
        title: "ข้อมูลไม่ถูกต้อง",
        titleStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.redAccent,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.warning_amber_rounded,
                size: 60, color: Colors.redAccent),
            SizedBox(height: 10),
            Text(
              "มีผู้ใช้เบอร์นี้แล้ว ไปใช้เบอร์อื่นเหอะ",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
        textConfirm: "ตกลง",
        confirmTextColor: Colors.white,
        buttonColor: Colors.redAccent,
        radius: 20,
        barrierDismissible: false,

        // ทำพื้นหลัง dialog โปร่งแสง
        backgroundColor: Colors.white.withOpacity(0.9),

        onConfirm: () {
          Get.back();
        },
      );
    }

    log("it here 1");
    var email = phoneToEmail(_phoneController.text.trim());
    var password = _passwordController.text.trim();

    // var result = await FirebaseAuth.instance
    //     .createUserWithEmailAndPassword(email: email, password: password);
    // String uid = result.user!.uid;
    await uploadImageProfile();
    var user = <String, dynamic>{
      "profile": _profileImageUrl,
      "fullname": _fullNameController.text.trim(),
      "phone": _phoneController.text,
    };

    log("$_isRider");
    if (_isRider == false) {
      log("get in u");
      var member = <String, dynamic>{};
      if (_gpsController.text.isNotEmpty && _gpsController.text.contains(",")) {
        var geoPoints = _gpsController.text.split(',');
        double lat = double.parse(geoPoints[0]);
        double lng = double.parse(geoPoints[1]);
        member = {
          "defaultAddress": _addressController.text.trim(),
          "defaultGPS": GeoPoint(lat, lng),
        };
      }

      if (_address2Controller.text.isNotEmpty) {
        var geoPoints = _gps2Controller.text.split(',');
        double lat = double.parse(geoPoints[0]);
        double lng = double.parse(geoPoints[1]);
        var secAddress = {
          "secondAddress": _address2Controller.text.trim(),
          "secondGPS": GeoPoint(lat, lng),
        };
        member = {...member, ...secAddress};
      }

      user = {...user, ...member};
    } else {
      log("get in r");
      await uploadImageVehiclePicture();
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      var rider = <String, dynamic>{
        "vehicle_no": _vehicleRegController.text,
        "vehicle_picture": _vehicleImageUrl,
        "gps": GeoPoint(pos.latitude, pos.longitude)
      };

      user = {...user, ...rider};
    }
  }

////////////////////////////////////////////////////////////////////////////////////////////////////////
  /// 1. ฟังก์ชันแสดง Modal ให้ผู้ใช้เลือกว่าจะใช้ Camera หรือ Gallery
  Future<void> _selectImageSource(bool isProfile) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'เลือกแหล่งที่มาของรูปภาพ',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC70808)),
                ),
              ),
              ListTile(
                leading:
                    const Icon(Icons.photo_library, color: Color(0xFFC70808)),
                title: const Text('เลือกจากแกลเลอรี'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(isProfile, ImageSource.gallery);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.photo_camera, color: Color(0xFFC70808)),
                title: const Text('ถ่ายรูปด้วยกล้อง'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(isProfile, ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  /// 2. ฟังก์ชันจริงสำหรับการเลือกรูปภาพ โดยรับ ImageSource เข้ามา
  Future<void> _pickImage(bool isProfile, ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        if (isProfile) {
          _profileImage = pickedFile;
          _profileImagePath = File(pickedFile.path);
        } else {
          _vehicleImage = pickedFile;
          _vehicleImagePath = File(pickedFile.path);
        }
      });
    }
  }

  Future<void> uploadImageProfile() async {
    if (_profileImagePath == null || !await _profileImagePath!.exists()) {
      Get.snackbar("System", "โปรดเลือกรูปโปรไฟล์");
      return;
    }
    try {
      final cloudinary = CloudinaryPublic(
        'dnutmbomv', // 👉 เอาจาก Cloudinary Dashboard
        'delivery888', // 👉 Upload preset ที่สร้าง
        cache: false,
      );

      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          _profileImagePath!.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      setState(() {
        _profileImageUrl = response.secureUrl;
      });
      log("✅ Vehicle image uploaded: ${response.secureUrl}");
    } catch (e) {
      log("❌ Vehicle image upload error: $e");
    }
  }

  Future<void> uploadImageVehiclePicture() async {
    if (_vehicleImagePath == null) {
      Get.snackbar("System", "โปรดเลือกรูปยานพาหนะ");
      return;
    }

    try {
      final cloudinary = CloudinaryPublic(
        'dnutmbomv', // 👉 เอาจาก Cloudinary Dashboard
        'delivery888', // 👉 Upload preset ที่สร้าง
        cache: false,
      );

      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          _vehicleImagePath!.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      setState(() {
        _vehicleImageUrl = response.secureUrl;
      });
      log("✅ Vehicle image uploaded: ${response.secureUrl}");
    } catch (e) {
      log("❌ Vehicle image upload error: $e");
    }
  }

  /// 3. ฟังก์ชันดึงตำแหน่ง GPS ปัจจุบัน (สำหรับปุ่ม "พิกัด GPS")
  // *** แก้ไข: รับ targetGpsController เพื่ออัปเดตช่องที่ถูกต้อง ***
  Future<void> _getCurrentGPS(TextEditingController targetGpsController) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('กรุณาเปิด Location Service')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('ไม่ได้รับอนุญาตให้เข้าถึง Location')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions ถูกปฏิเสธถาวร.'),
            ),
          );
        }
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // อัปเดต Controller ที่ถูกส่งเข้ามา
      if (mounted) {
        setState(() {
          targetGpsController.text =
              "${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}";
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error getting location: $e")),
        );
      }
    }
  }

  /// 5. Modal สำหรับเลือกพิกัดบนแผนที่ (Geocoding & Map Tap)
  // *** แก้ไข: รับ targetGpsController และ sourceAddressController เพื่อจัดการข้อมูลที่อยู่/พิกัดแยกกัน ***
  Future<void> _openMapPicker(
    TextEditingController targetGpsController,
    TextEditingController sourceAddressController,
  ) async {
    final currentGpsText = targetGpsController.text;
    LatLng startPos = _defaultLocation;

    // พยายามดึงพิกัดปัจจุบันจากช่อง GPS ที่ต้องการมาเป็นค่าเริ่มต้น
    if (currentGpsText.isNotEmpty) {
      try {
        final parts = currentGpsText
            .split(',')
            .map((s) => double.parse(s.trim()))
            .toList();
        if (parts.length == 2) {
          startPos = LatLng(parts[0], parts[1]);
        }
      } catch (_) {
        // ใช้ค่าเริ่มต้น ถ้า parse ไม่ได้
      }
    }

    // ส่งค่าที่อยู่หลัก/ที่อยู่ 2 (ที่ผู้ใช้พิมพ์ไว้) ไปเป็น initialAddress สำหรับการค้นหาเริ่มต้นใน Modal
    final String initialAddress = sourceAddressController.text;

    final LatLng? result = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) {
        return MapPickerModal(
          initialLocation: startPos,
          initialAddress: initialAddress,
        );
      },
    );

    // อัปเดต Controller เมื่อผู้ใช้เลือกพิกัดแล้วกด Save
    if (result != null) {
      setState(() {
        // อัปเดตช่องพิกัด GPS ที่ส่งเข้ามา
        targetGpsController.text =
            "${result.latitude.toStringAsFixed(6)}, ${result.longitude.toStringAsFixed(6)}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDE9E9), // Background color
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
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
        const Padding(
          padding: EdgeInsets.only(top: 10, bottom: 20),
          child: Center(
            child: Text(
              'สมัครสมาชิก',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC70808), // ใช้สีหลักของธีม
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
            // Clear vehicle image when switching back to user
            if (!_isRider) {
              _vehicleImage = null;
              _vehicleRegController.clear();
            }
          });
          // log("${_addressController.text}  ${_gpsController}");
          // var a = _gpsController.text.split(',');
          // log("lat${a[0]} lng${a[1].trim()}");
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
      onTap: () => _selectImageSource(true), // isProfile = true
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              shape: BoxShape.circle,
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
      onTap: () => _selectImageSource(false), // isProfile = false
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              shape: BoxShape.circle,
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
          _buildTextField('ชื่อ-สกุล', controller: _fullNameController,
              validator: (val) {
            if (val!.isEmpty && _isRider == false) {
              return "กรุณากรอกชื่อขสกุล";
            }
            return null;
          }),
          const SizedBox(height: 20),

          _buildTextField('เบอร์โทรศัพท์',
              controller: _phoneController,
              keyboardType: TextInputType.phone, validator: (val) {
            if ((val!.length != 10 || val.isEmpty) && _isRider == false) {
              return "กรุณากรอกเลขเบอร์โทร 10 หลัก";
            }
            return null;
          }),
          const SizedBox(height: 20),
          _buildTextField('รหัสผ่าน',
              controller: _passwordController,
              isPassword: true, validator: (val) {
            if ((val!.length < 6 || val.isEmpty) && _isRider == false) {
              return "กรุณากรอกรหัสผ่านอย่างน้อย 6 ตัว";
            }
            return null;
          }),
          const SizedBox(height: 20),
          _buildTextField('รหัสผ่านอีกครั้ง',
              controller: _confirmPasswordController,
              isPassword: true, validator: (val) {
            if ((val!.length < 6 || val.isEmpty) && _isRider == false) {
              return "กรุณากรอกรหัสผ่านอย่างน้อย 6 ตัว";
            }
            if ((val != _passwordController.text) && _isRider == false) {
              return "รหัสผ่านไม่ตรงกัน";
            }
            return null;
          }),
          const SizedBox(height: 20),

          // 1. ที่อยู่หลัก
          _buildTextField('ที่อยู่หลัก', controller: _addressController,
              validator: (val) {
            if (val!.isEmpty && _isRider == false) {
              return "กรุณากรอกที่อยู่หลัก";
            }
            return null;
          }),
          const SizedBox(height: 20),

          // 1.1 ช่องพิกัด GPS สำหรับที่อยู่หลัก
          _buildTextFieldWithIcon(
              'พิกัด GPS หลัก (แตะที่ช่องเพื่อเลือกบนแผนที่)',
              Icons.my_location,
              controller: _gpsController,
              // *** ส่ง controller ที่ถูกต้อง: _gpsController สำหรับพิกัด, _addressController สำหรับที่อยู่ค้นหา ***
              onIconTap: () => _getCurrentGPS(_gpsController),
              onFieldTap: () =>
                  _openMapPicker(_gpsController, _addressController),
              readOnly: true,
              validator: (val) {
                if (val!.isEmpty && _isRider == false) {
                  return 'กรุณาเลือกพิกัดหลัก';
                }
                return null;
              }),
          const SizedBox(height: 20),

          // 2. ที่อยู่ 2
          _buildTextField('ที่อยู่ 2 (ไม่บังคับ)',
              controller: _address2Controller, validator: (val) {
            if (_gps2Controller.text.isNotEmpty &&
                _address2Controller.text.isEmpty &&
                _isRider == false) {
              return "กรุณากรอกที่อยู่ลำดับที่ 2";
            }
            return null;
          }),
          const SizedBox(height: 20),

          // 2.1 ช่องพิกัด GPS สำหรับที่อยู่ 2
          _buildTextFieldWithIcon(
              'พิกัด GPS 2 (แตะที่ช่องเพื่อเลือกบนแผนที่)', Icons.my_location,
              controller: _gps2Controller,
              // *** ส่ง controller ที่ถูกต้อง: _gps2Controller สำหรับพิกัด, _address2Controller สำหรับที่อยู่ค้นหา ***
              onIconTap: () => _getCurrentGPS(_gps2Controller),
              onFieldTap: () =>
                  _openMapPicker(_gps2Controller, _address2Controller),
              readOnly: true,
              validator: (val) {
                if (_address2Controller.text.isNotEmpty &&
                    _gps2Controller.text.isEmpty &&
                    _isRider == false) {
                  return "กรุณากรอกพิกัดที่อยู่ลำดับที่ 2";
                }
                return null;
              }),
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
          _buildTextField('เบอร์โทรศัพท์',
              controller: _phoneController,
              keyboardType: TextInputType.phone, validator: (val) {
            if ((val!.length != 10 || val.isEmpty) && _isRider == true) {
              return "กรุณากรอกเลขเบอร์โทร 10 หลัก";
            }
            return null;
          }),
          const SizedBox(height: 20),
          _buildTextField('รหัสผ่าน',
              controller: _passwordController,
              isPassword: true, validator: (val) {
            if ((val!.length < 6 || val.isEmpty) && _isRider == true) {
              return "กรุณากรอกรหัสผ่านอย่างน้อย 6 ตัว";
            }
            return null;
          }),
          const SizedBox(height: 20),
          _buildTextField('รหัสผ่านอีกครั้ง',
              controller: _confirmPasswordController,
              isPassword: true, validator: (val) {
            if ((val!.length < 6 || val.isEmpty) && _isRider == true) {
              return "กรุณากรอกรหัสผ่านอย่างน้อย 6 ตัว";
            }
            if (val != _passwordController.text) {
              return "รหัสผ่านไม่ตรงกัน";
            }
            return null;
          }),
          const SizedBox(height: 20),
          _buildTextField('ทะเบียนรถ', controller: _vehicleRegController,
              validator: (val) {
            if (val!.isEmpty && _isRider == true) {
              return "กรุณากรอกหมายเลขทะเบียนยานพาหะนะ";
            }
          }),
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      validator: validator,
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
    VoidCallback? onIconTap,
    VoidCallback? onFieldTap, // เพิ่มสำหรับการแตะที่ช่อง
    bool readOnly = false, // เพิ่มสำหรับการควบคุมการอ่านอย่างเดียว
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly, // ใช้พารามิเตอร์ใหม่
      onTap: onFieldTap, // ผูก onTap กับ onFieldTap
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: Icon(icon, color: Colors.black54),
          onPressed: onIconTap,
        ),
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
          onPressed: () async {
            log("click");
            await register();
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

// Custom Clipper for the red background shape
class CustomClipperRed extends CustomClipper<ui.Path> {
  @override
  ui.Path getClip(Size size) {
    var path = ui.Path();
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
  bool shouldReclip(CustomClipper<ui.Path> oldClipper) {
    return false;
  }
}

// ******************************************************************
// Widget ใหม่: MapPickerModal สำหรับค้นหาและเลือกพิกัด
// ******************************************************************
class MapPickerModal extends StatefulWidget {
  final LatLng initialLocation;
  final String initialAddress;

  const MapPickerModal({
    super.key,
    required this.initialLocation,
    required this.initialAddress,
  });

  @override
  State<MapPickerModal> createState() => _MapPickerModalState();
}

class _MapPickerModalState extends State<MapPickerModal> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  LatLng? _selectedPos;

  // *** API KEY ที่ท่านระบุ ***
  static const String thunderforestApiKey = 'cb153d15cb4e41f59e25cfda6468f1a0';
  static const String thunderforestUrl =
      'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=$thunderforestApiKey';

  @override
  void initState() {
    super.initState();
    _selectedPos = widget.initialLocation;
    // ใช้ initialAddress จาก RegisterPage เป็นค่าเริ่มต้นในการค้นหา
    _searchController.text = widget.initialAddress;
  }

  // 4.1 ฟังก์ชัน Geocoding (ค้นหาชื่อสถานที่)
  Future<void> _geocodeAddress() async {
    final address = _searchController.text;
    if (address.isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        final newLat = locations.first.latitude;
        final newLng = locations.first.longitude;
        final newPos = LatLng(newLat, newLng);

        setState(() {
          _selectedPos = newPos;
        });

        // เลื่อน Map ไปยังพิกัดที่พบ
        _mapController.move(newPos, 16.0);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ไม่พบสถานที่ตามที่อยู่ กรุณาลองใหม่อีกครั้ง'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการค้นหาพิกัด: $e'),
          ),
        );
      }
    }
  }

  // 4.2 ฟังก์ชัน Reverse Geocoding (แตะบนแผนที่)
  void _onMapTap(TapPosition tapPosition, LatLng point) async {
    setState(() {
      _selectedPos = point;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
          point.latitude, point.longitude,
          localeIdentifier: 'th');

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final addressLine = "${placemark.thoroughfare}, "
            "${placemark.subLocality}, ${placemark.locality}, "
            "${placemark.administrativeArea}, ${placemark.country}";

        // อัปเดตช่องค้นหาด้วยที่อยู่ใหม่
        _searchController.text = addressLine.replaceAll(', ,', ',').trim();
      }
    } catch (e) {
      debugPrint("Reverse Geocoding Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'ค้นหาและเลือกพิกัดที่อยู่',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFC70808),
            ),
          ),
          const SizedBox(height: 15),
          // 4.3 Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText:
                  'พิมพ์ชื่อสถานที่หรือที่อยู่ เช่น "มหาวิทยาลัยมหาสารคาม"',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: Color(0xFFC70808)),
                onPressed: _geocodeAddress, // ผูกกับฟังก์ชันค้นหา
              ),
            ),
            onSubmitted: (_) => _geocodeAddress(),
          ),
          const SizedBox(height: 15),
          // 4.4 Map Widget
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: widget.initialLocation,
                  initialZoom: 14.0,
                  onTap: _onMapTap, // ผูกกับฟังก์ชันแตะแผนที่
                ),
                children: [
                  // *** แก้ไข: ใช้ Thunderforest URL ที่ท่านระบุพร้อม API Key ***
                  TileLayer(
                    urlTemplate: thunderforestUrl,
                    userAgentPackageName: "com.example.app",
                  ),
                  if (_selectedPos != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedPos!,
                          width: 80,
                          height: 80,
                          child: const Icon(
                            Icons.location_on,
                            color: Color(0xFFC70808),
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          // 4.5 Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_selectedPos != null) {
                  // ส่ง LatLng กลับไปยังหน้า RegisterPage
                  Navigator.pop(context, _selectedPos);
                } else {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'ยืนยันพิกัดนี้',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
