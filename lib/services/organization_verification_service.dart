import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../config.dart';
import '../models/organization.dart';
import '../models/shelter.dart';
import '../services/email_service.dart';

class OrganizationVerificationService {
  static const String _rescueGroupsApiUrl =
      'https://api.rescuegroups.org/v5/public';
  static const String _apiKey = AppConfig.rescueGroupsApiKey;

  /// Validates if an OrgID exists in RescueGroups API
  static Future<Map<String, dynamic>> validateOrgId(String orgId) async {
    try {
      final url = '$_rescueGroupsApiUrl/orgs/$orgId';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final shelter = Shelter.fromJson(data);

        if (shelter.data != null && shelter.data!.isNotEmpty) {
          final orgData = shelter.data![0].attributes;
          return {
            'exists': true,
            'name': orgData?.name ?? '',
            'email': orgData?.email ?? '',
            'data': orgData,
          };
        } else {
          return {'exists': false, 'error': 'Organization not found'};
        }
      } else if (response.statusCode == 404) {
        return {'exists': false, 'error': 'Organization not found'};
      } else {
        return {'exists': false, 'error': 'API error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'exists': false, 'error': 'Network error: $e'};
    }
  }

  /// Creates organization document in Firestore with verification UUID
  static Future<String> createOrganizationDocument({
    required String orgId,
    required String name,
    required String email,
  }) async {
    try {
      final verificationUuid = const Uuid().v4();

      final organization = Organization(
        orgId: orgId,
        verificationUuid: verificationUuid,
        name: name,
        email: email,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .set(organization.toJson());

      return verificationUuid;
    } catch (e) {
      throw Exception('Failed to create organization document: $e');
    }
  }

  /// Generates JWT token with OrgID and UUID
  static String generateJWT({
    required String orgId,
    required String verificationUuid,
  }) {
    final now = DateTime.now();
    final expiration = now.add(const Duration(days: 1));

    final payload = {
      'orgId': orgId,
      'verificationUuid': verificationUuid,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': expiration.millisecondsSinceEpoch ~/ 1000,
    };

    // For now, using a simple base64 encoding
    // In production, you should use a proper JWT library with secret key
    final header = base64Url
        .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
    final payloadEncoded = base64Url.encode(utf8.encode(jsonEncode(payload)));
    final signature = base64Url.encode(utf8.encode('signature_placeholder'));

    return '$header.$payloadEncoded.$signature';
  }

  /// Sends verification email to organization
  static Future<bool> sendVerificationEmail({
    required String orgId,
    required String verificationUuid,
    required String email,
    required String name,
  }) async {
    try {
      final jwt = generateJWT(
        orgId: orgId,
        verificationUuid: verificationUuid,
      );

      // Get the web app URL from config
      final webAppUrl = AppConfig.emailServiceUrl.replaceAll('/api', '');
      final verificationUrl = '$webAppUrl/verify-organization?token=$jwt';

      final subject = 'Feline Finder - Organization Verification';
      final body = '''
        <html>
        <body>
          <h2>Welcome to Feline Finder!</h2>
          <p>Hello $name,</p>
          <p>You have been invited to set up your organization on Feline Finder.</p>
          <p>Please click the link below to complete your organization verification:</p>
          <p><a href="$verificationUrl" style="background-color: #4CAF50; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">Verify Organization</a></p>
          <p>This link will expire in 24 hours.</p>
          <p>If you did not request this verification, please ignore this email.</p>
          <br>
          <p>Best regards,<br>The Feline Finder Team</p>
        </body>
        </html>
      ''';

      return await EmailService.sendEmail(
        toEmail: email,
        subject: subject,
        body: body,
        fromName: 'Feline Finder',
      );
    } catch (e) {
      print('Error sending verification email: $e');
      return false;
    }
  }

  /// Verifies JWT token and checks UUID against organization document
  static Future<Map<String, dynamic>> verifyJWTToken(String token) async {
    try {
      // Decode JWT payload
      final parts = token.split('.');
      if (parts.length != 3) {
        return {'valid': false, 'error': 'Invalid token format'};
      }

      final payload = jsonDecode(utf8.decode(base64Url.decode(parts[1])));
      final orgId = payload['orgId'];
      final verificationUuid = payload['verificationUuid'];
      final exp = payload['exp'];

      // Check expiration
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now > exp) {
        return {'valid': false, 'error': 'Token expired'};
      }

      // Get organization document from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .get();

      if (!doc.exists) {
        return {'valid': false, 'error': 'Organization not found'};
      }

      final orgData = doc.data()!;
      final storedUuid = orgData['verificationUuid'];

      // Verify UUID matches
      if (verificationUuid != storedUuid) {
        return {'valid': false, 'error': 'Invalid verification UUID'};
      }

      return {
        'valid': true,
        'orgId': orgId,
        'verificationUuid': verificationUuid,
        'organization': Organization.fromJson(orgData),
      };
    } catch (e) {
      return {'valid': false, 'error': 'Token verification failed: $e'};
    }
  }

  /// Completes organization verification
  static Future<bool> completeVerification({
    required String orgId,
    required String adminUserId,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .update({
        'isVerified': true,
        'adminUserId': adminUserId,
        'verifiedAt': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error completing verification: $e');
      return false;
    }
  }
}
