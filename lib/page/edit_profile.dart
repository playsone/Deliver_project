import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart'; // สำหรับ Geocoding

class EditProfilePage extends StatefulWidget {
  final String uid;
  const EditProfilePage({super.key, required this.uid});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final db = FirebaseFirestore.instance;
  late final String _profileImageUrl;
  final LatLng _defaultLocation = const LatLng(13.7563, 100.5018);
  LatLng _currentMarkerPos = const LatLng(13.7563, 100.5018);
  final _nameController = TextEditingController(text: 'สมชาย รักชาติ');
  final _phoneController = TextEditingController(text: '081-234-5678');
  final _addressController =
      TextEditingController(text: 'ตึกใบหยก 2, กรุงเทพมหานคร');
  final _gpsController = TextEditingController(text: '13.7563, 100.5018');
  final MapController _mapController = MapController();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _gpsController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// 1. ฟังก์ชันค้นหาพิกัดจากชื่อสถานที่ (Geocoding)
  Future<void> _geocodeAddress() async {
    final address = _addressController.text;
    if (address.isEmpty) return;

    try {
      // ใช้ Geocoding package เพื่อแปลงที่อยู่เป็นพิกัด
      List<Location> locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        final newLat = locations.first.latitude;
        final newLng = locations.first.longitude;
        final newPos = LatLng(newLat, newLng);

        setState(() {
          _currentMarkerPos = newPos;
          _gpsController.text =
              "${newLat.toStringAsFixed(6)}, ${newLng.toStringAsFixed(6)}";
        });

        // เลื่อน Map ไปยังพิกัดที่พบ
        _mapController.move(newPos, 15.0);
      } else {
        // แสดงข้อความเมื่อไม่พบที่อยู่
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ไม่พบสถานที่ตามที่อยู่ กรุณาลองใหม่อีกครั้ง'),
            ),
          );
        }
      }
    } catch (e) {
      // Handle error, e.g., network issue or service error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการค้นหาพิกัด: $e'),
          ),
        );
      }
    }
  }

  /// 2. ฟังก์ชันอัปเดตพิกัดเมื่อผู้ใช้แตะบนแผนที่ (Reverse Geocoding)
  void _onMapTap(TapPosition tapPosition, LatLng point) async {
    setState(() {
      _currentMarkerPos = point;
      _gpsController.text =
          "${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}";
    });

    try {
      // ใช้ Reverse Geocoding เพื่อหาชื่อสถานที่จากพิกัด
      List<Placemark> placemarks =
          await placemarkFromCoordinates(point.latitude, point.longitude);

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        // สร้างที่อยู่ที่อ่านง่าย
        final addressLine =
            "${placemark.subThoroughfare} ${placemark.thoroughfare}, "
            "${placemark.subLocality}, ${placemark.locality}, "
            "${placemark.administrativeArea}";

        _addressController.text = addressLine.trim();
      }
    } catch (e) {
      // Reverse Geocoding error
      debugPrint("Reverse Geocoding Error: $e");
    }
  }

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
        // ใช้ shape เดียวกันกับ Header
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
            const SizedBox(
              height: 10,
            ),
            _buildProfileSection(),
            _buildFormSection(),
            _buildMapSection(), // เพิ่มส่วนแผนที่
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  getUserProfile() async {
    try {
      var userData = await db
          .collection('users')
          .where('uid', isEqualTo: widget.uid)
          .get();
      var query = userData.docs.first.data();
      _profileImageUrl = query['profile'];
    } on FirebaseException catch (e) {
      log(e.toString());
    }
  }

  Widget _buildProfileSection() {
    return Transform.translate(
      offset: const Offset(0, 10), // Move the profile image up
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: NetworkImage(_profileImageUrl),
            child: Align(
              alignment: Alignment.bottomRight,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 10),
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
          _buildTextFieldWithLabel(
              'ชื่อ-สกุล', _nameController, TextInputType.name),
          const SizedBox(height: 20),
          _buildTextFieldWithLabel(
              'หมายเลขโทรศัพท์', _phoneController, TextInputType.phone),
          const SizedBox(height: 20),
          _buildTextFieldWithLabel(
            'ที่อยู่หรือสถานที่พิกัด',
            _addressController,
            TextInputType.text,
            suffixIcon: Icons.search,
            onIconTap: _geocodeAddress,
          ),
          const SizedBox(height: 20),
          _buildTextFieldWithLabel(
            'พิกัด GPS (Lat, Lng)',
            _gpsController,
            TextInputType.text,
            isReadOnly: true,
          ),
          const SizedBox(height: 40),
          _buildSaveButton(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  /// 3. สร้างส่วนแผนที่
  Widget _buildMapSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'เลือกพิกัดบนแผนที่ (แตะเพื่อกำหนดจุด)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFC70808), width: 2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _defaultLocation,
                  initialZoom: 15.0,
                  onTap: _onMapTap, // กำหนดฟังก์ชันเมื่อมีการแตะบนแผนที่
                ),
                children: [
                  // Tile Layer (OpenStreetMap)
                  TileLayer(
                    urlTemplate:
                        'https://tile.thunderforest.com/transport/{z}/{x}/{y}.png?apikey=cb153d15cb4e41f59e25cfda6468f1a0',
                    userAgentPackageName: "com.example.app",
                  ),
                  // Marker Layer for the selected location
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentMarkerPos,
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
        ],
      ),
    );
  }

  /// 4. ปรับปรุง TextField ให้รองรับ Controller และ Icon Action
  Widget _buildTextFieldWithLabel(
    String label,
    TextEditingController controller,
    TextInputType keyboardType, {
    IconData? suffixIcon,
    VoidCallback? onIconTap,
    bool isReadOnly = false,
  }) {
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
          controller: controller,
          keyboardType: keyboardType,
          readOnly: isReadOnly,
          decoration: InputDecoration(
            hintText: label,
            hintStyle: const TextStyle(color: Colors.black38),
            fillColor: Colors.grey.shade200,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            suffixIcon: suffixIcon != null
                ? IconButton(
                    icon: Icon(suffixIcon, color: const Color(0xFFC70808)),
                    onPressed: onIconTap, // ผูกฟังก์ชันค้นหาพิกัด
                  )
                : null,
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
          // เพิ่ม Logic บันทึกข้อมูลที่นี่
          debugPrint('Saving Name: ${_nameController.text}');
          debugPrint('Saving GPS: ${_gpsController.text}');
          // แสดงข้อความแจ้งเตือนเมื่อบันทึกสำเร็จ
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('บันทึกข้อมูลส่วนตัวเรียบร้อยแล้ว'),
              backgroundColor: Colors.green,
            ),
          );
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
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // แก้ isSelected เป็นค่าคงที่สำหรับแสดงผลเท่านั้น
          _NavItem(icon: Icons.home, label: 'หน้าแรก', isSelected: false),
          _NavItem(
              icon: Icons.history,
              label: 'ประวัติการส่งสินค้า',
              isSelected: false),
          _NavItem(icon: Icons.logout, label: 'ออกจากระบบ', isSelected: true),
        ],
      ),
    );
  }
}

// Widget แยกสำหรับ Nav Item เพื่อให้โค้ดสะอาดขึ้น
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
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
