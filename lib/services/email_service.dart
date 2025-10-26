import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class EmailService {
  static const String _baseUrl = AppConfig.emailServiceUrl;

  /// Send cat inquiry email through the backend service
  static Future<bool> sendCatInquiry({
    required String shelterEmail,
    required String catName,
    required String userEmail,
    required String userName,
    String? userPhone,
    String? message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/send-cat-inquiry'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'shelterEmail': shelterEmail,
          'catName': catName,
          'userName': userName,
          'userEmail': userEmail,
          'userPhone': userPhone,
          'message': message ??
              'I am interested in adopting this cat from Feline Finder app.',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }

      print('Email service error: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      print('Error sending email: $e');
      return false;
    }
  }

  /// Send general email through the backend service
  static Future<bool> sendEmail({
    required String toEmail,
    required String subject,
    required String body,
    String? fromName,
    String? fromEmail,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/send-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': toEmail,
          'subject': subject,
          'body': body,
          'fromName': fromName,
          'fromEmail': fromEmail,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }

      print('Email service error: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      print('Error sending email: $e');
      return false;
    }
  }

  /// Check if email service is available
  static Future<bool> isServiceAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Email service health check failed: $e');
      return false;
    }
  }
}
