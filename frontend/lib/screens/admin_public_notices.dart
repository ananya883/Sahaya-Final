import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';

class AdminPublicNotices extends StatefulWidget {
  const AdminPublicNotices({super.key});

  @override
  State<AdminPublicNotices> createState() => _AdminPublicNoticesState();
}

class _AdminPublicNoticesState extends State<AdminPublicNotices> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true); // Required to get bytes on web
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  Future<void> _uploadNotice() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isUploading = true);
    
    try {
      var request = http.MultipartRequest("POST", Uri.parse(ApiConfig.publicNotices));
      request.fields['title'] = _titleCtrl.text.trim();
      request.fields['message'] = _messageCtrl.text.trim();

      if (_selectedFile != null) {
        if (kIsWeb && _selectedFile!.bytes != null) {
          // Flutter Web workflow
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              _selectedFile!.bytes!,
              filename: _selectedFile!.name,
            ),
          );
        } else if (_selectedFile!.path != null) {
          // Mobile / Desktop workflow
          request.files.add(
            await http.MultipartFile.fromPath(
              'file',
              _selectedFile!.path!,
              filename: _selectedFile!.name,
            ),
          );
        }
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notice Broadcasted Successfully!')),
          );
          _titleCtrl.clear();
          _messageCtrl.clear();
          setState(() {
            _selectedFile = null;
          });
        }
      } else {
        throw Exception(responseData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error broadcasting notice: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Broadcast Notice'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
            ]
          ),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Post a New Public Notice',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This message will be visible to all generic users in the platform.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notice Title',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _messageCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Message Body',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedFile == null
                            ? 'No file selected (Optional)'
                            : 'Selected: ${_selectedFile!.name}',
                        style: TextStyle(
                            color: _selectedFile == null ? Colors.grey : Colors.blue.shade700,
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isUploading ? null : _pickFile,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Attach File'),
                    )
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _uploadNotice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: _isUploading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Send Broadcast', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
