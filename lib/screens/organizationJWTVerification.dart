import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/organization_verification_service.dart';
import '../models/organization.dart';
import '../services/portal_user_service.dart';
import 'errorPage.dart';

class OrganizationJWTVerificationScreen extends StatefulWidget {
  final String jwtToken;

  const OrganizationJWTVerificationScreen({
    Key? key,
    required this.jwtToken,
  }) : super(key: key);

  @override
  State<OrganizationJWTVerificationScreen> createState() =>
      _OrganizationJWTVerificationScreenState();
}

class _OrganizationJWTVerificationScreenState
    extends State<OrganizationJWTVerificationScreen> {
  bool _isVerifying = true;
  bool _isCompleting = false;
  Map<String, dynamic>? _verificationResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _verifyJWTToken();
  }

  Future<void> _verifyJWTToken() async {
    try {
      final result =
          await OrganizationVerificationService.verifyJWTToken(widget.jwtToken);

      if (result['valid'] == true) {
        setState(() {
          _verificationResult = result;
          _isVerifying = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Invalid token';
          _isVerifying = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Token verification failed: $e';
        _isVerifying = false;
      });
    }
  }

  Future<void> _completeVerification() async {
    if (_verificationResult == null) return;

    setState(() {
      _isCompleting = true;
    });

    try {
      // Get current user ID using portal user service
      final portalUserService = PortalUserService();
      final userId = await portalUserService.getUser();

      // Complete organization verification
      final success =
          await OrganizationVerificationService.completeVerification(
        orgId: _verificationResult!['orgId'],
        adminUserId: userId,
      );

      if (success) {
        Get.dialog(
          AlertDialog(
            title: const Text('Verification Complete!'),
            content: const Text(
              'Your organization has been successfully verified and set up. You can now manage your organization on Feline Finder.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Get.back();
                  // Navigate to organization dashboard or main app
                  Get.offAllNamed('/home');
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      } else {
        _showErrorDialog('Failed to complete verification. Please try again.');
      }
    } catch (e) {
      _showErrorDialog('Error completing verification: $e');
    } finally {
      setState(() {
        _isCompleting = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    Get.dialog(
      AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              Get.to(() => ErrorPage());
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isVerifying) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Verifying token...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Verification Failed'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Verification Failed',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Get.to(() => ErrorPage()),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final organization = _verificationResult!['organization'] as Organization;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Verification'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Icon(
              Icons.verified_user,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            const Text(
              'Verification Successful!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Organization: ${organization.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Email: ${organization.email}'),
                    const SizedBox(height: 8),
                    Text('Organization ID: ${organization.orgId}'),
                    const SizedBox(height: 8),
                    Text(
                        'Created: ${organization.createdAt.toString().split(' ')[0]}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Complete Setup',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Click the button below to complete your organization setup and become the administrator.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Once verified, you will have full administrative access to manage your organization.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCompleting ? null : _completeVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isCompleting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Complete Organization Setup',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
