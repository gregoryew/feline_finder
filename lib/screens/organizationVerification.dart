import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/organization_verification_service.dart';
import 'organizationSetupConfirmation.dart';
import 'errorPage.dart';

class OrganizationVerificationScreen extends StatefulWidget {
  final String orgId;

  const OrganizationVerificationScreen({
    Key? key,
    required this.orgId,
  }) : super(key: key);

  @override
  State<OrganizationVerificationScreen> createState() =>
      _OrganizationVerificationScreenState();
}

class _OrganizationVerificationScreenState
    extends State<OrganizationVerificationScreen> {
  bool _isLoading = true;
  bool _isValidating = false;
  Map<String, dynamic>? _orgData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _validateOrgId();
  }

  Future<void> _validateOrgId() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result =
          await OrganizationVerificationService.validateOrgId(widget.orgId);

      if (result['exists'] == true) {
        setState(() {
          _orgData = result;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Organization not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to validate organization: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _proceedToSetup() async {
    if (_orgData == null) return;

    setState(() {
      _isValidating = true;
    });

    try {
      // Create organization document
      final verificationUuid =
          await OrganizationVerificationService.createOrganizationDocument(
        orgId: widget.orgId,
        name: _orgData!['name'] ?? '',
        email: _orgData!['email'] ?? '',
      );

      // Send verification email
      final emailSent =
          await OrganizationVerificationService.sendVerificationEmail(
        orgId: widget.orgId,
        verificationUuid: verificationUuid,
        email: _orgData!['email'] ?? '',
        name: _orgData!['name'] ?? '',
      );

      if (emailSent) {
        Get.to(() => OrganizationSetupConfirmationScreen(
              orgId: widget.orgId,
              orgName: _orgData!['name'] ?? '',
              orgEmail: _orgData!['email'] ?? '',
            ));
      } else {
        _showErrorDialog(
            'Failed to send verification email. Please try again.');
      }
    } catch (e) {
      _showErrorDialog('Failed to create organization: $e');
    } finally {
      setState(() {
        _isValidating = false;
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
              Get.to(() => const ErrorPage());
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Validating organization...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Organization Verification'),
          iconTheme: const IconThemeData(color: Colors.white),
          foregroundColor: Colors.white,
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
                  'Organization Not Found',
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
                  onPressed: () => Get.to(() => const ErrorPage()),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization Verification'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Organization Found!',
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
                      'Organization ID: ${widget.orgId}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Name: ${_orgData!['name']}'),
                    const SizedBox(height: 4),
                    Text('Email: ${_orgData!['email']}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Setup Confirmation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Will you be the person setting up this organization on Feline Finder?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isValidating
                        ? null
                        : () {
                            Get.dialog(
                              AlertDialog(
                                title: const Text('Please Forward Email'),
                                content: const Text(
                                  'Please forward this email to the person who will be setting up the organization.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Get.back(),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                    child: const Text('No'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isValidating ? null : _proceedToSetup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: _isValidating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Yes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
