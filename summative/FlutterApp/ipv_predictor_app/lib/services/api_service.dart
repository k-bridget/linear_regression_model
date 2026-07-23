import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  // Base URL of the deployed FastAPI service (Swagger docs at /docs).
  // TODO: replace with your actual Render URL once Task 2 is deployed.
  // For local testing:
  //   - Android emulator -> http://10.0.2.2:8000
  //   - iOS simulator / web -> http://localhost:8000
  static const String baseUrl = 'https://ipv-attitude-api.onrender.com';

  static Future<Map<String, dynamic>> predictAttitude({
    required String country,
    required String gender,
    required String demographicsQuestion,
    required String demographicsResponse,
    required String question,
    required int surveyYear,
  }) async {
    final uri = Uri.parse('$baseUrl/predict');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'country': country,
              'gender': gender,
              'demographics_question': demographicsQuestion,
              'demographics_response': demographicsResponse,
              'question': question,
              'survey_year': surveyYear,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      String detailMessage = 'Request failed (${response.statusCode}).';
      try {
        final decoded = jsonDecode(response.body);
        final detail = decoded['detail'];
        if (detail is String) {
          detailMessage = detail;
        } else if (detail is List && detail.isNotEmpty) {
          detailMessage = detail
              .map(
                (e) => e is Map && e['msg'] != null
                    ? e['msg'].toString()
                    : e.toString(),
              )
              .join('\n');
        }
      } catch (_) {}
      throw ApiException(detailMessage);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }
}
