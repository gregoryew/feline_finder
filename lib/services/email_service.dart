import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class EmailService {
  static const String _baseUrl = AppConfig.emailServiceUrl;
  static const String _postmarkApiUrl = AppConfig.postmarkApiUrl;

  /// Helper to strip HTML tags for text version
  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Send email using Postmark API directly
  static Future<bool> _sendViaPostmark({
    required String toEmail,
    required String subject,
    required String body,
    String? fromName,
    String? fromEmail,
    Map<String, String>? envMap,
  }) async {
    try {
      // Try to get token from config (--dart-define or system env)
      String? serverToken = AppConfig.postmarkServerToken;

      // If not found and envMap provided, try getting from .env file
      if ((serverToken == null || serverToken.isEmpty) && envMap != null) {
        serverToken = AppConfig.postmarkServerTokenFromEnv(envMap);
      }

      if (serverToken == null || serverToken.isEmpty) {
        print('⚠️ Postmark server token not configured.');
        print(
            '⚠️ Set it via: flutter run --dart-define=POSTMARK_SERVER_TOKEN=your-token');
        print('⚠️ Or add POSTMARK_SERVER_TOKEN=your-token to .env file');
        print(
            '⚠️ Or set system environment variable: export POSTMARK_SERVER_TOKEN=your-token');
        return false;
      }

      final response = await http.post(
        Uri.parse('$_postmarkApiUrl/email'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Postmark-Server-Token': serverToken,
        },
        body: jsonEncode({
          'From': fromEmail ?? 'noreply@felinefinder.org',
          'To': toEmail,
          'Subject': subject,
          'HtmlBody': body,
          'TextBody': _stripHtml(body),
          'MessageStream': 'outbound',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Postmark email sent: ${data['MessageID']}');
        return true;
      }

      print('❌ Postmark API error: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      print('❌ Error sending email via Postmark: $e');
      return false;
    }
  }

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

  /// Send general email through backend service or Postmark API directly
  static Future<bool> sendEmail({
    required String toEmail,
    required String subject,
    required String body,
    String? fromName,
    String? fromEmail,
    Map<String, String>? envMap,
  }) async {
    // Try Postmark API first if token is configured
    String? token = AppConfig.postmarkServerToken;
    print(
        '📧 Checking Postmark token: ${token != null && token.isNotEmpty ? "Found (from define/env)" : "Not found"}');

    if ((token == null || token.isEmpty) && envMap != null) {
      token = AppConfig.postmarkServerTokenFromEnv(envMap);
      print(
          '📧 Checking Postmark token from .env: ${token != null && token.isNotEmpty ? "Found" : "Not found"}');
      if (envMap.containsKey('POSTMARK_SERVER_TOKEN')) {
        print(
            '📧 .env contains POSTMARK_SERVER_TOKEN: ${envMap['POSTMARK_SERVER_TOKEN']?.substring(0, 8)}...');
      } else {
        print('📧 .env does NOT contain POSTMARK_SERVER_TOKEN');
      }
    }

    if (token != null && token.isNotEmpty) {
      print('✅ Using Postmark API directly');
      return await _sendViaPostmark(
        toEmail: toEmail,
        subject: subject,
        body: body,
        fromName: fromName,
        fromEmail: fromEmail,
        envMap: envMap,
      );
    }

    // Fall back to custom email service
    print(
        '⚠️ Postmark token not found, falling back to email service: $_baseUrl');
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
