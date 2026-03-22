import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

// Web-only import
// ignore: avoid_web_libraries_in_flutter
// import 'dart:html' as html;

class SosPage extends StatefulWidget {
  const SosPage({Key? key}) : super(key: key);

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  final List<String> emergencyTypes = ['Medical', 'Fire', 'Rescue', 'Other'];
  final List<String> disasterTypes = ['Flood', 'Earthquake', 'Landslide', 'Cyclone', ];

  String? selectedEmergency;
  String? selectedDisaster;

  // Mobile
  XFile? pickedFile;

  // Web
  Uint8List? webImageData;
  // html.VideoElement? _webVideo;
  // html.CanvasElement? _webCanvas;

  Position? currentPosition;
  bool locating = false;
  bool sending = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _determinePosition();
    // if (kIsWeb) _initWebCamera();
  }

  // ---------------- Web Camera Preview ----------------
  // void _initWebCamera() {
  //   _webVideo = html.VideoElement()
  //     ..autoplay = true
  //     ..width = 300
  //     ..height = 200;

  //   html.window.navigator.mediaDevices?.getUserMedia({'video': true}).then((stream) {
  //     _webVideo!.srcObject = stream;
  //   });

  //   setState(() {});
  // }

  // void _captureWebImage() {
  //   if (_webVideo == null) return;

  //   _webCanvas ??= html.CanvasElement(
  //     width: _webVideo!.videoWidth,
  //     height: _webVideo!.videoHeight,
  //   );

  //   final ctx = _webCanvas!.context2D;
  //   ctx.drawImage(_webVideo!, 0, 0);

  //   final dataUrl = _webCanvas!.toDataUrl('image/png');
  //   final bytes = base64Decode(dataUrl.split(',')[1]);

  //   setState(() {
  //     webImageData = bytes;
  //   });
  // }

  // ---------------- Web File Upload ----------------
  // void _pickWebImageFile() {
  //   final html.FileUploadInputElement uploadInput = html.FileUploadInputElement()..accept = 'image/*';
  //   uploadInput.click();

  //   uploadInput.onChange.listen((event) {
  //     final files = uploadInput.files;
  //     if (files != null && files.isNotEmpty) {
  //       final reader = html.FileReader();
  //       reader.readAsArrayBuffer(files[0]);
  //       reader.onLoadEnd.listen((event) {
  //         setState(() {
  //           webImageData = Uint8List.fromList(reader.result as List<int>);
  //         });
  //       });
  //     }
  //   });
  // }

  // ---------------- Pick Image (Mobile) ----------------
  Future<void> _pickImage({required bool fromCamera}) async {
    if (kIsWeb) return;
    final source = fromCamera ? ImageSource.camera : ImageSource.gallery;
    final XFile? file = await _picker.pickImage(source: source, imageQuality: 70);
    if (file != null) setState(() => pickedFile = file);
  }

  // ---------------- Location (Fast 2-step strategy for SOS) ----------------
  Future<void> _determinePosition() async {
    setState(() => locating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      // STEP 1: Instantly use the last known position (cached — zero wait time)
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          currentPosition = lastKnown;
          locating = false; // show location immediately
        });
      }

      // STEP 2: Silently get a fresh accurate position in the background
      // Uses 'low' accuracy first which is much faster than 'best'
      final fresh = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
      if (mounted) {
        setState(() => currentPosition = fresh);
      }
    } catch (e) {
      debugPrint('Location error: $e');
      // Still might have lastKnown — that's OK
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  // ---------------- Send SOS ----------------
  Future<void> _sendSos() async {
    if (selectedEmergency == null) {
      _showSnackBar('Please select an emergency type');
      return;
    }

    // If still locating and no position yet, try one quick attempt
    if (currentPosition == null && locating) {
      _showSnackBar('Getting your location... please wait a second', success: true);
      await Future.delayed(const Duration(seconds: 2));
    }

    setState(() => sending = true);
    try {
      final response = await ApiService.sendSos(
        emergencyType: selectedEmergency!,
        disasterType: selectedDisaster == null || selectedDisaster == 'None' ? '' : selectedDisaster!,
        latitude: currentPosition?.latitude.toString(),
        longitude: currentPosition?.longitude.toString(),
        imageFile: pickedFile,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _resetForm();
        _showSnackBar(
          currentPosition != null
              ? 'SOS Sent with your location ✅'
              : 'SOS Sent (location unavailable)',
          success: true,
        );
      } else {
        _showSnackBar('Failed to send SOS (${response.statusCode})');
      }
    } catch (e) {
      _showSnackBar('Network error: $e');
    } finally {
      setState(() => sending = false);
    }
  }

  void _resetForm() {
    setState(() {
      selectedEmergency = null;
      selectedDisaster = null;
      pickedFile = null;
      webImageData = null;
    });
  }

  void _showSnackBar(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: success ? Colors.green : Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMERGENCY REPORT'),
        backgroundColor: Colors.white,
        leading: BackButton(color: Colors.black87),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // ----------- GPS Status Banner -----------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: currentPosition != null
                    ? Colors.green.shade50
                    : (locating ? Colors.orange.shade50 : Colors.red.shade50),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: currentPosition != null
                      ? Colors.green
                      : (locating ? Colors.orange : Colors.red),
                ),
              ),
              child: Row(
                children: [
                  if (locating && currentPosition == null)
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                    )
                  else
                    Icon(
                      currentPosition != null ? Icons.location_on : Icons.location_off,
                      size: 18,
                      color: currentPosition != null ? Colors.green : Colors.red,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentPosition != null
                          ? 'Location captured: ${currentPosition!.latitude.toStringAsFixed(5)}, ${currentPosition!.longitude.toStringAsFixed(5)}'
                          : (locating ? 'Getting your location...' : 'Location unavailable'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: currentPosition != null
                            ? Colors.green.shade800
                            : (locating ? Colors.orange.shade800 : Colors.red.shade800),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            DropdownButton<String>(
              value: selectedEmergency,
              hint: const Text('Select emergency type'),
              isExpanded: true,
              items: emergencyTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => selectedEmergency = v),
            ),
            const SizedBox(height: 12),
            DropdownButton<String>(
              value: selectedDisaster,
              hint: const Text('Select related disaster (optional)'),
              isExpanded: true,
              items: ['None', ...disasterTypes].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => selectedDisaster = v),
            ),
            const SizedBox(height: 16),

            // ---------------- Image selection ----------------
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                      onPressed: () => _pickImage(fromCamera: true),
                      child: const Text('Open Camera')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                      onPressed: () => _pickImage(fromCamera: false),
                      child: const Text('Gallery')),
                ),
              ],
            ),

            const SizedBox(height: 12),
            if (pickedFile != null)
              Image.file(File(pickedFile!.path), height: 100, width: 100, fit: BoxFit.cover),

            const SizedBox(height: 20),

            // ---------------- TRIGGER SOS Button ----------------
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: sending ? null : _sendSos,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: sending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.warning_rounded, size: 24),
                label: Text(
                  sending ? 'Sending...' : 'TRIGGER SOS',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
