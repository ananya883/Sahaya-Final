import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'package:path/path.dart';

class ApiService {

  // ---------------- USER AUTH ----------------
  static Future<http.Response> loginUser(String email, String password) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/auth/login");
    return await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    ).timeout(const Duration(seconds: 10));
  }

  static Future<http.Response> registerUser({
    required String name,
    required String gender,
    required String dob,
    required String mobile,
    required String email,
    required String address,
    required String houseNo,
    required List<String> roles,
    String? password,
    // Guardian
    String? guardianName,
    String? guardianRelation,
    String? guardianMobile,
    String? guardianEmail,
    String? guardianAddress,
    // Volunteer
    List<String>? skills,
    bool? trainingAttended,
    String? serviceLocation,
    String? certifications,
    String? availability,
    List<String>? previousExperience,
    // Donor
    List<String>? itemsOfInterest,
    String? organizationName,
    String? taxId,
    String? donationType,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/auth/register");
    return await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "Name": name,
        "gender": gender,
        "dob": dob,
        "mobile": mobile,
        "email": email,
        "address": address,
        "houseNo": houseNo,
        "roles": roles,
        "password": password,
        "guardianName": guardianName,
        "guardianRelation": guardianRelation,
        "guardianMobile": guardianMobile,
        "guardianEmail": guardianEmail,
        "guardianAddress": guardianAddress,
        "skills": skills,
        "trainingAttended": trainingAttended,
        "serviceLocation": serviceLocation,
        "certifications": certifications,
        "availability": availability,
        "previousExperience": previousExperience,
        "itemsOfInterest": itemsOfInterest,
        "organizationName": organizationName,
        "taxId": taxId,
        "donationType": donationType,
      }),
    );
  }

  static Future<http.Response> sendOtp(String email) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/auth/send-verification-otp");
    return await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );
  }

  static Future<http.Response> verifyOtp(String email, String otp) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/auth/verify-email-otp");
    return await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "otp": otp}),
    );
  }

  static Future<http.Response> forgotPassword(String email) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/user/forgot-password");
    return await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );
  }

  // ---------------- VOLUNTEER ----------------
  static Future<http.StreamedResponse> registerVolunteer({
    required String name,
    required String email,
    required String password,
    required String mobile,
    required String gender,
    required String dob,
    required String address,
    required String houseNo,
    required List<String> skills,
    required bool trainingAttended,
    required String serviceLocation,
    File? govtIdFile,
    File? certificateFile,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/volunteer/register");
    final request = http.MultipartRequest("POST", url);

    request.fields["Name"] = name;
    request.fields["email"] = email;
    request.fields["password"] = password;
    request.fields["mobile"] = mobile;
    request.fields["gender"] = gender;
    request.fields["dob"] = dob;
    request.fields["address"] = address;
    request.fields["houseNo"] = houseNo;
    request.fields["skills"] = jsonEncode(skills);
    request.fields["trainingAttended"] = trainingAttended.toString();
    request.fields["serviceLocation"] = serviceLocation;

    if (govtIdFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
        "govtId",
        govtIdFile.path,
        filename: basename(govtIdFile.path),
      ));
    }

    if (certificateFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
        "certificate",
        certificateFile.path,
        filename: basename(certificateFile.path),
      ));
    }

    return await request.send();
  }

  // ---------------- SOS ----------------
  static Future<http.Response> sendSos({
    required String emergencyType,
    required String disasterType,
    String? latitude,
    String? longitude,
    XFile? imageFile,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/sos/");
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    
    if (imageFile == null) {
      return await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "emergency_type": emergencyType,
          "disaster_type": disasterType,
          "latitude": latitude,
          "longitude": longitude,
          "userId": userId,
        }),
      );
    } else {
      final request = http.MultipartRequest("POST", url);
      request.fields["emergency_type"] = emergencyType;
      request.fields["disaster_type"]  = disasterType;
      if (latitude  != null) request.fields["latitude"]  = latitude;
      if (longitude != null) request.fields["longitude"] = longitude;
      if (userId    != null) request.fields["userId"]    = userId;

      request.files.add(await http.MultipartFile.fromPath(
        "image",
        imageFile.path,
        filename: basename(imageFile.path),
      ));

      final streamedResponse = await request.send();
      return await http.Response.fromStream(streamedResponse);
    }
  }

  // ---------------- GET CAMP REQUESTS ----------------
  static Future<List<dynamic>> getCampRequests() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.campRequests))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed to load camp requests");
      }
    } catch (e) {
      throw Exception("Server error: $e");
    }
  }

  // ---------------- DONATE ITEM ----------------
  static Future<void> donateItem(String requestId, int qty, String donorName) async {
    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/api/donor/donate-item"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "requestId": requestId,
          "donateQty": qty,
          "donorName": donorName,
        }),
      );
      if (response.statusCode != 200) {
        throw Exception("Donation failed");
      }
    } catch (e) {
      throw Exception("Server error: $e");
    }
  }

  // ---------------- GET ALL CAMPS ----------------
  static Future<List<dynamic>> getCamps() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.camps))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed to load camps");
      }
    } catch (e) {
      throw Exception("Server error: $e");
    }
  }

  // ---------------- DONATE MONEY ----------------
  static Future<http.Response> donateMoney({
    required String donorId,
    required String campId,
    required String amount,
  }) async {
    final url = Uri.parse(ApiConfig.donorDonateDirect);
    return await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "donorId": donorId,
        "campId": campId,
        "amount": amount,
      }),
    );
  }

  // ---------------- UPGRADE TO VOLUNTEER ----------------
  static Future<http.Response> upgradeToVolunteer({
    required String userId,
    required List<String> skills,
    required String serviceLocation,
  }) async {
    final url = Uri.parse(ApiConfig.volunteerUpgrade);
    return await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "userId": userId,
        "skills": skills,
        "serviceLocation": serviceLocation,
      }),
    );
  }

  // ---------------- RAZORPAY ----------------
  static Future<http.Response> createRazorpayOrder(String amount) async {
    final url = Uri.parse(ApiConfig.createRazorpayOrder);
    return await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"amount": amount}),
    );
  }

  static Future<http.Response> verifyRazorpayPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    required String donorId,
    required String campId,
    required String amount,
  }) async {
    final url = Uri.parse(ApiConfig.verifyRazorpayPayment);
    return await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "razorpay_order_id": orderId,
        "razorpay_payment_id": paymentId,
        "razorpay_signature": signature,
        "donorId": donorId,
        "campId": campId,
        "amount": amount,
      }),
    );
  }

  // ---------------- VOLUNTEER SOS ----------------
  static Future<List<dynamic>> getVolunteerSos() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.volunteerSos))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed to load volunteer SOS requests");
      }
    } catch (e) {
      throw Exception("Server error: $e");
    }
  }

  // ---------------- DONOR HISTORY ----------------
  static Future<Map<String, dynamic>> getDonationHistory(String donorId, String donorName) async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.donorHistory(donorId, donorName)))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed to load donation history");
      }
    } catch (e) {
      throw Exception("Server error: $e");
    }
  }

  static Future<http.Response> acceptSos(String sosId, String volunteerId) async {
    final url = Uri.parse(ApiConfig.volunteerAcceptSos(sosId));
    return await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({ "volunteerId": volunteerId }),
    );
  }

  static Future<http.Response> resolveSos(String sosId, {File? actionImage}) async {
    final url = Uri.parse(ApiConfig.volunteerResolveSos(sosId));
    
    if (actionImage == null) {
      return await http.post(
        url,
        headers: {"Content-Type": "application/json"},
      );
    } else {
      final request = http.MultipartRequest("POST", url);
      request.files.add(await http.MultipartFile.fromPath(
        "actionImage",
        actionImage.path,
        filename: basename(actionImage.path),
      ));
      
      final streamedResponse = await request.send();
      return await http.Response.fromStream(streamedResponse);
    }
  }

  static Future<http.Response> adminExpireSos(String sosId) async {
    final url = Uri.parse(ApiConfig.adminExpireSos(sosId));
    return await http.post(
      url,
      headers: {"Content-Type": "application/json"},
    );
  }

  static Future<http.Response> adminUnexpireSos(String sosId) async {
    final url = Uri.parse(ApiConfig.adminUnexpireSos(sosId));
    return await http.post(
      url,
      headers: {"Content-Type": "application/json"},
    );
  }
}
