import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrganizationSetupDialog extends StatefulWidget {
  final String organizationId;
  final String organizationName;

  const OrganizationSetupDialog({
    Key? key,
    required this.organizationId,
    required this.organizationName,
  }) : super(key: key);

  @override
  _OrganizationSetupDialogState createState() =>
      _OrganizationSetupDialogState();
}

class _OrganizationSetupDialogState extends State<OrganizationSetupDialog> {
  bool? _inPerson;
  bool? _webMeeting;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.settings,
                    color: Theme.of(context).primaryColor,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Complete Organization Setup',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.organizationName,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please select your booking preferences to complete setup. You can change these later.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Appointment Type Selection (same as schedule dialog)
              Text(
                'Appointment Type',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      title: Text(
                        'Video Bookings',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      value: _webMeeting ?? false,
                      onChanged: (value) {
                        setState(() {
                          _webMeeting = value;
                        });
                      },
                      activeColor: Theme.of(context).primaryColor,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: Text(
                        'In-Person Bookings',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      value: _inPerson ?? false,
                      onChanged: (value) {
                        setState(() {
                          _inPerson = value;
                        });
                      },
                      activeColor: Theme.of(context).primaryColor,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You can select one or both options. Adopters will see your available options when scheduling.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              Navigator.of(context).pop(false);
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_inPerson == null && _webMeeting == null) ||
                              _isSaving
                          ? null
                          : () async {
                              await _savePreferences();
                            },
                      child: _isSaving
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Save & Complete Setup',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Theme.of(context).primaryColor,
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePreferences() async {
    if (_inPerson == null && _webMeeting == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one appointment type'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .update({
        'inPerson': _inPerson ?? false,
        'webMeeting': _webMeeting ?? false,
        'pendingSetup': false,
        'updatedAt': Timestamp.now(),
      });

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Organization setup completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving organization preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
