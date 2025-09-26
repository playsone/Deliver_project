import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

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

  // Controllers สำหรับการจัดการข้อมูลในฟอร์ม
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController(); // ช่องที่อยู่หลัก (กรอกเอง)
  final _address2Controller = TextEditingController();
  final _gpsController = TextEditingController(); // ช่องพิกัด GPS (อ่านอย่างเดียว)
  final _vehicleRegController = TextEditingController();

  final LatLng _defaultLocation = const LatLng(13.7367, 100.5231);

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
        } else {
          _vehicleImage = pickedFile;
        }
      });
    }
  }

  /// 3. ฟังก์ชันดึงตำแหน่ง GPS ปัจจุบัน (สำหรับปุ่ม "พิกัด GPS")
  Future<void> _getCurrentGPS() async {
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

      // อัปเดต Controller เฉพาะพิกัด GPS เท่านั้น (ตามความต้องการของท่าน)
      setState(() {
        _gpsController.text =
            "${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}";
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error getting location: $e")),
        );
      }
    }
  }

  /// 5. Modal สำหรับเลือกพิกัดบนแผนที่ (Geocoding & Map Tap)
  Future<void> _openMapPicker() async {
    final currentGpsText = _gpsController.text;
    LatLng startPos = _defaultLocation;

    // พยายามดึงพิกัดปัจจุบันจากช่อง GPS มาเป็นค่าเริ่มต้น
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

    // ส่งค่าที่อยู่หลัก (ที่ผู้ใช้พิมพ์ไว้) ไปเป็น initialAddress สำหรับการค้นหาเริ่มต้นใน Modal
    final String initialAddress = _addressController.text;

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
        // อัปเดตแค่ช่องพิกัด GPS เท่านั้น (ตามความต้องการของท่าน)
        _gpsController.text =
            "${result.latitude.toStringAsFixed(6)}, ${result.longitude.toStringAsFixed(6)}";
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
              crossFadeState:
                  _isRider ? CrossFadeState.showSecond : CrossFadeState.showFirst,
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
          // ช่องที่อยู่ (กรอกเอง)
          _buildTextField('ที่อยู่หลัก', controller: _addressController),
          const SizedBox(height: 20),
          _buildTextField('ที่อยู่ 2 (ไม่บังคับ)', controller: _address2Controller),
          const SizedBox(height: 20),
          // ช่องพิกัด GPS (อ่านอย่างเดียว แตะเพื่อเปิดแผนที่ หรือดึงตำแหน่งปัจจุบัน)
          _buildTextFieldWithIcon(
            'พิกัด GPS (แตะที่ช่องเพื่อเลือกบนแผนที่)',
            Icons.my_location, // Icon สำหรับดึงตำแหน่งปัจจุบัน
            controller: _gpsController,
            onIconTap: _getCurrentGPS, // แตะ Icon: ดึง GPS ปัจจุบัน
            onFieldTap: _openMapPicker, // แตะ Field: เปิด Map Picker
            readOnly: true, // ช่องนี้เป็นแบบอ่านอย่างเดียว
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
    VoidCallback? onIconTap,
    VoidCallback? onFieldTap, // เพิ่มสำหรับการแตะที่ช่อง
    bool readOnly = false, // เพิ่มสำหรับการควบคุมการอ่านอย่างเดียว
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly, // ใช้พารามิเตอร์ใหม่
      onTap: onFieldTap, // ผูก onTap กับ onFieldTap
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
          onPressed: () {
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
              hintText: 'พิมพ์ชื่อสถานที่หรือที่อยู่ เช่น "มหาวิทยาลัยมหาสารคาม"',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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