import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'api_config.dart';

class MissingPersonService {
  static final String baseUrl =
      "${ApiConfig.baseUrl}/api/missing";

  static Future<void> registerMissingPerson({
    required String name,
    required String age,
    required String gender,
    required String height,
    required String weight,
    required String birthmark,
    required String lastSeenLocation,
    required String lastSeenDate,
    required XFile image,
    required String registeredBy,
  }) async {
    final uri = Uri.parse("$baseUrl/register");
    final request = http.MultipartRequest("POST", uri);

    request.fields.addAll({
      "name": name,
      "age": age,
      "gender": gender,
      "height": height,
      "weight": weight,
      "birthmark": birthmark,
      "lastSeenLocation": lastSeenLocation,
      "lastSeenDate": lastSeenDate,
      "registeredBy": registeredBy,
    });

    final bytes = await image.readAsBytes();
    final fileName = image.name.isNotEmpty ? image.name : 'photo.jpg';
    request.files.add(
      http.MultipartFile.fromBytes("photo", bytes, filename: fileName),
    );

    final response = await request.send().timeout(
      const Duration(seconds: 20),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = await response.stream.bytesToString();
      throw Exception("Missing person registration failed: $body");
    }
    
    // Read response body for success (or discard if not needed)
    await response.stream.bytesToString();
  }
}
