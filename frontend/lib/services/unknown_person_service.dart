import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'api_config.dart';

class UnknownPersonService {
  static final String baseUrl =
      "${ApiConfig.baseUrl}/api/unknown";

  static Future<void> registerUnknownPerson({
    required String gender,
    required String age,
    required String height,
    required String weight,
    required String foundLocation,
    required String foundDate,
    required XFile image,
    required String campId,
  }) async {
    final uri = Uri.parse("$baseUrl/upload");

    final request = http.MultipartRequest("POST", uri);

    // Form fields
    request.fields["gender"] = gender;
    request.fields["age"] = age;
    request.fields["height"] = height;
    request.fields["weight"] = weight;
    request.fields["foundLocation"] = foundLocation;
    request.fields["foundDate"] = foundDate;
    request.fields["campId"] = campId;

    final bytes = await image.readAsBytes();
    final fileName = image.name.isNotEmpty ? image.name : 'photo.jpg';
    request.files.add(
      http.MultipartFile.fromBytes(
        "photo",
        bytes,
        filename: fileName,
      ),
    );

    final response = await request.send().timeout(
      const Duration(seconds: 20),
    );

    if (response.statusCode != 201) {
      final responseBody = await response.stream.bytesToString();
      throw Exception("Unknown person registration failed: $responseBody");
    }
  }
}
