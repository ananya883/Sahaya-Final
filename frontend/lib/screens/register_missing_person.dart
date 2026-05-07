import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/missing_person_service.dart';

class RegisterMissingPerson extends StatefulWidget {
  const RegisterMissingPerson({super.key});

  @override
  State<RegisterMissingPerson> createState() => _RegisterMissingPersonState();
}

class _RegisterMissingPersonState extends State<RegisterMissingPerson> {
  final _formKey = GlobalKey<FormState>();

  final nameCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  final genderCtrl = TextEditingController();
  final heightCtrl = TextEditingController();
  final weightCtrl = TextEditingController();
  final birthmarkCtrl = TextEditingController();
  final lastSeenLocationCtrl = TextEditingController();

  DateTime? lastSeenDate;
  XFile? image;
  bool loading = false;

  final Color primaryBlue = Colors.blueAccent;

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => image = picked);
    }
  }

  Future<void> pickDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => lastSeenDate = date);
    }
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate() ||
        image == null ||
        lastSeenDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill all fields & select image")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString("userId");

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in. Please login first.")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await MissingPersonService.registerMissingPerson(
        name: nameCtrl.text,
        age: ageCtrl.text,
        gender: genderCtrl.text,
        height: heightCtrl.text,
        weight: weightCtrl.text,
        birthmark: birthmarkCtrl.text,
        lastSeenLocation: lastSeenLocationCtrl.text,
        lastSeenDate: lastSeenDate!.toIso8601String(),
        image: image!,
        registeredBy: userId,
      );

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing person registered successfully")),
      );
      
      // Clear form and navigate back
      nameCtrl.clear();
      ageCtrl.clear();
      genderCtrl.clear();
      heightCtrl.clear();
      weightCtrl.clear();
      birthmarkCtrl.clear();
      lastSeenLocationCtrl.clear();
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Register Missing Person"),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              textField(nameCtrl, "Name", Icons.person),
              textField(ageCtrl, "Age", Icons.cake, number: true),
              textField(genderCtrl, "Gender", Icons.people),
              textField(heightCtrl, "Height", Icons.height),
              textField(weightCtrl, "Weight", Icons.monitor_weight),
              textField(birthmarkCtrl, "Birthmark", Icons.visibility),
              textField(
                  lastSeenLocationCtrl, "Last Seen Location", Icons.location_on),

              const SizedBox(height: 12),

              // Date Picker
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryBlue,
                  side: BorderSide(color: primaryBlue),
                ),
                onPressed: pickDate,
                icon: const Icon(Icons.date_range),
                label: Text(
                  lastSeenDate == null
                      ? "Select Last Seen Date"
                      : lastSeenDate!
                      .toLocal()
                      .toString()
                      .split(" ")[0],
                ),
              ),

              const SizedBox(height: 12),

              // Image Picker
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryBlue,
                  side: BorderSide(color: primaryBlue),
                ),
                onPressed: pickImage,
                icon: const Icon(Icons.image),
                label: Text(
                    image == null ? "Pick Image" : "Image Selected ✔"),
              ),

              const SizedBox(height: 24),

              // Submit Button
              loading
                  ? CircularProgressIndicator(color: primaryBlue)
                  : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: submit,
                  child: const Text(
                    "Submit",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget textField(TextEditingController ctrl, String label, IconData icon,
      {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        validator: (v) => v!.isEmpty ? "Required" : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryBlue),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryBlue),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryBlue, width: 2),
          ),
        ),
      ),
    );
  }
}
