import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/appointment_service.dart';
import '../services/email_service.dart';
import '../config.dart';
import '../screens/globals.dart' as globals;

class ScheduleAppointmentDialog extends StatefulWidget {
  final String catName;
  final String organizationName;
  final String organizationEmail;
  final String? catImageUrl;
  final String? catId;
  final String? organizationId;

  const ScheduleAppointmentDialog({
    Key? key,
    required this.catName,
    required this.organizationName,
    required this.organizationEmail,
    this.catImageUrl,
    this.catId,
    this.organizationId,
  }) : super(key: key);

  @override
  _ScheduleAppointmentDialogState createState() =>
      _ScheduleAppointmentDialogState();
}

enum OrganizationState {
  loading,
  found,
  notFound,
  noOptions, // found but neither inPerson nor webMeeting enabled
}

class _ScheduleAppointmentDialogState extends State<ScheduleAppointmentDialog> {
  DateTime selectedDate = DateTime.now();
  String? selectedTimeSlot;

  // User info fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoadingUserData = true;
  bool _isSubmitting = false;
  String? _userId;
  bool _saveUserInfo = false; // Checkbox for saving user info locally

  // Organization data
  OrganizationState _organizationState = OrganizationState.loading;
  bool? _inPerson;
  bool? _webMeeting;
  String? _appointmentType; // 'video' or 'in-person'
  bool _isPendingSetup = false; // Track if organization is in pending setup

  // Sample available time slots that change based on date
  // TODO: Fetch interval from organization collection step 5
  int appointmentIntervalMinutes = 30; // Default to 30 minutes

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadOrganizationData();
  }

  /// Get user UUID from existing system (FelineFinderServer)
  Future<String> _getUserUuid() async {
    try {
      // Use the existing FelineFinderServer to get UUID
      final server = globals.FelineFinderServer.instance;
      return await server.getUser();
    } catch (e) {
      print('Error getting user UUID: $e');
      // Fallback: try to get from Firebase Auth or create new
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        return user.uid;
      }
      // If no Firebase Auth, create a temporary UUID
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadOrganizationData() async {
    if (widget.organizationId == null || widget.organizationId!.isEmpty) {
      setState(() {
        // No orgId - show both options (pending setup)
        _organizationState = OrganizationState.found;
        _inPerson = true;
        _webMeeting = true;
        _appointmentType = 'video'; // Default to video
        _isPendingSetup = true;
      });
      return;
    }

    try {
      final orgDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .get();

      if (!orgDoc.exists) {
        setState(() {
          // Organization doesn't exist - show both options (pending setup)
          _organizationState = OrganizationState.found;
          _inPerson = true;
          _webMeeting = true;
          _appointmentType = 'video'; // Default to video
          _isPendingSetup = true;
        });
        return;
      }

      final data = orgDoc.data()!;
      // Treat null or missing pendingSetup as true (not set up yet)
      final pendingSetup = data['pendingSetup'] ?? true;

      setState(() {
        _isPendingSetup = pendingSetup;

        if (pendingSetup) {
          // Organization exists but pending setup - show both options without checking other fields
          _organizationState = OrganizationState.found;
          _inPerson = true;
          _webMeeting = true;
          _appointmentType = 'video'; // Default to video
        } else {
          // Normal flow - check organization's configured options
          final inPerson = data['inPerson'] ?? false;
          final webMeeting = data['webMeeting'] ?? false;

          _inPerson = inPerson;
          _webMeeting = webMeeting;

          if (inPerson && webMeeting) {
            _organizationState = OrganizationState.found;
            // Default to video if both available
            _appointmentType = 'video';
          } else if (inPerson || webMeeting) {
            _organizationState = OrganizationState.found;
            // Set default based on what's available
            _appointmentType = webMeeting ? 'video' : 'in-person';
          } else {
            // If no options configured, treat as pending setup (first contact)
            _organizationState = OrganizationState.found;
            _inPerson = true;
            _webMeeting = true;
            _appointmentType = 'video';
            _isPendingSetup = true;
          }
        }
      });
    } catch (e) {
      print('Error loading organization data: $e');
      setState(() {
        // On error, assume pending setup and show both options
        _organizationState = OrganizationState.found;
        _inPerson = true;
        _webMeeting = true;
        _appointmentType = 'video';
        _isPendingSetup = true;
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      // Get UUID from existing system
      _userId = await _getUserUuid();

      // Load saved user info from SharedPreferences using UUID
      final prefs = await SharedPreferences.getInstance();
      final uuidKey = 'user_info_$_userId';

      final savedName = prefs.getString('${uuidKey}_name');
      final savedEmail = prefs.getString('${uuidKey}_email');
      final savedPhone = prefs.getString('${uuidKey}_phone');
      final shouldSave = prefs.getBool('${uuidKey}_save') ?? false;

      setState(() {
        if (savedName != null && savedName.isNotEmpty) {
          _nameController.text = savedName;
        }
        if (savedEmail != null && savedEmail.isNotEmpty) {
          _emailController.text = savedEmail;
        }
        if (savedPhone != null && savedPhone.isNotEmpty) {
          _phoneController.text = savedPhone;
        }
        _saveUserInfo = shouldSave;
        _isLoadingUserData = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoadingUserData = false;
      });
    }
  }

  Future<void> _saveUserData() async {
    if (_userId != null && _saveUserInfo) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final uuidKey = 'user_info_$_userId';

        // Save user info locally with UUID
        await prefs.setString('${uuidKey}_name', _nameController.text.trim());
        await prefs.setString('${uuidKey}_email', _emailController.text.trim());
        await prefs.setString('${uuidKey}_phone', _phoneController.text.trim());
        await prefs.setBool('${uuidKey}_save', _saveUserInfo);

        print('✅ Saved user info locally for UUID: $_userId');
      } catch (e) {
        print('Error saving user data locally: $e');
      }
    } else if (_userId != null && !_saveUserInfo) {
      // If user unchecked save, remove saved data
      try {
        final prefs = await SharedPreferences.getInstance();
        final uuidKey = 'user_info_$_userId';

        await prefs.remove('${uuidKey}_name');
        await prefs.remove('${uuidKey}_email');
        await prefs.remove('${uuidKey}_phone');
        await prefs.setBool('${uuidKey}_save', false);
      } catch (e) {
        print('Error removing saved user data: $e');
      }
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  List<Map<String, String>> getAvailableTimeSlots() {
    // For demo purposes, show different times based on day of week
    final dayOfWeek = selectedDate.weekday;

    List<String> startTimes;
    if (dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) {
      // Weekend hours
      startTimes = [
        '10:00 AM',
        '11:00 AM',
        '12:00 PM',
        '1:00 PM',
        '2:00 PM',
        '3:00 PM',
      ];
    } else {
      // Weekday hours
      startTimes = [
        '9:00 AM',
        '10:00 AM',
        '11:00 AM',
        '12:00 PM',
        '1:00 PM',
        '2:00 PM',
        '3:00 PM',
        '4:00 PM',
        '5:00 PM',
      ];
    }

    // Convert to list with end times
    return startTimes.map((start) {
      final startTime = _parseTime(start);
      final endTime =
          startTime.add(Duration(minutes: appointmentIntervalMinutes));
      return {
        'start': start,
        'end': _formatTime(endTime),
      };
    }).toList();
  }

  DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final isPM = parts[1] == 'PM';

    if (isPM && hour != 12) hour += 12;
    if (!isPM && hour == 12) hour = 0;

    return DateTime(2000, 1, 1, hour, minute);
  }

  String _formatTime(DateTime time) {
    final hour =
        time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _buildAppointmentTypeSelection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Do you prefer',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: Text(
                    'Video',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  value: 'video',
                  groupValue: _appointmentType,
                  onChanged: (value) {
                    setState(() {
                      _appointmentType = value;
                    });
                  },
                  activeColor: Theme.of(context).primaryColor,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: Text(
                    'In Person',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  value: 'in-person',
                  groupValue: _appointmentType,
                  onChanged: (value) {
                    setState(() {
                      _appointmentType = value;
                    });
                  },
                  activeColor: Theme.of(context).primaryColor,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleOptionMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
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
              message,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Removed _buildNoOptionsError - organizations without options are now treated as pending setup
  // and show the suggestion flow UI instead

  Widget _buildSuggestionFlowUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.celebration,
                    color: Colors.green[700],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You are the first person to contact this shelter.',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[800],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'If you are interested in setting up an appointment, please suggest a date and time below and we will send an email to the shelter saying there is someone who is interested in meeting ${widget.catName}.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please provide your name and email address to schedule. The adopter will be sent a notification when the shelter signs up.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Date Picker for suggestion
        Text(
          'Select Date',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(selectedDate),
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Time Slots for suggestion (no availability checking)
        Text(
          'Suggested Time',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: getAvailableTimeSlots().length,
          itemBuilder: (context, index) {
            final timeSlot = getAvailableTimeSlots()[index];
            final startTime = timeSlot['start']!;
            final endTime = timeSlot['end']!;
            final timeDisplay = '$startTime - $endTime';
            final isSelected = selectedTimeSlot == startTime;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  setState(() {
                    selectedTimeSlot = startTime;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        timeDisplay,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (isSelected) ...[
                        const Spacer(),
                        Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 22,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Parse time slot string and create start DateTime
  DateTime _parseStartDateTime(String timeSlot) {
    final parts = timeSlot.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final isPM = parts[1] == 'PM';

    if (isPM && hour != 12) hour += 12;
    if (!isPM && hour == 12) hour = 0;

    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      hour,
      minute,
    );
  }

  /// Parse time slot and create end DateTime (start + appointmentIntervalMinutes)
  DateTime _parseEndDateTime(String timeSlot) {
    final start = _parseStartDateTime(timeSlot);
    return start.add(Duration(minutes: appointmentIntervalMinutes));
  }

  /// Create regular appointment
  Future<void> _createRegularAppointment() async {
    // Check authentication
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      throw Exception('User must be authenticated to create an appointment');
    }
    print(
        '🔐 User authenticated: ${authUser.uid} (anonymous: ${authUser.isAnonymous})');

    // Ensure userId is loaded
    if (_userId == null || _userId!.isEmpty) {
      print('⏳ userId not loaded yet, fetching...');
      _userId = await _getUserUuid();
      if (_userId == null || _userId!.isEmpty) {
        throw Exception('Unable to get user ID');
      }
    }

    // Save user data locally if checkbox is checked
    await _saveUserData();

    // Validate time slot is selected
    if (selectedTimeSlot == null || selectedTimeSlot!.isEmpty) {
      throw Exception('Please select a time slot');
    }

    try {
      final appointment = await AppointmentService.createAppointment(
        catId: widget.catId ?? '',
        catName: widget.catName,
        organizationId: widget.organizationId ?? '',
        organizationName: widget.organizationName,
        organizationEmail: widget.organizationEmail,
        userId: _userId!,
        userName: _nameController.text.trim(),
        userEmail: _emailController.text.trim(),
        userPhone: _phoneController.text.trim(),
        appointmentDate: selectedDate,
        timeSlot: selectedTimeSlot!,
        catImageUrl: widget.catImageUrl,
      );

      if (appointment != null) {
        // Show success confirmation
        if (context.mounted) {
          Navigator.of(context).pop();
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                'Appointment Requested',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Your appointment to meet ${widget.catName} on ${DateFormat('MMMM d').format(selectedDate)} at $selectedTimeSlot has been requested.\n\nConfirmation emails have been sent to you and ${widget.organizationName}.',
                style: GoogleFonts.poppins(),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'OK',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception('Failed to create appointment');
      }
    } on FirebaseException catch (e) {
      print('❌ Firestore error: ${e.code} - ${e.message}');
      String errorMessage = 'Failed to create appointment';
      if (e.code == 'permission-denied') {
        errorMessage =
            'Permission denied. Please ensure you are signed in and try again.';
        print('🔐 Security rules violation - user may not be authenticated');
        print(
            '   Current auth user: ${FirebaseAuth.instance.currentUser?.uid ?? "null"}');
      } else {
        errorMessage = 'Error: ${e.message ?? e.code}';
      }

      // Show error to user
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog if any
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Error',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            content: Text(
              errorMessage,
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      rethrow;
    } catch (e) {
      print('❌ Unexpected error creating appointment: $e');
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog if any
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Error',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            content: Text(
              'Failed to create appointment: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      rethrow;
    }
  }

  /// Create suggestion (pending-setup booking)
  Future<void> _createSuggestion() async {
    if (widget.organizationId == null || widget.organizationId!.isEmpty) {
      throw Exception('Organization ID is required');
    }

    // Check authentication
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      throw Exception('User must be authenticated to create a booking');
    }
    print(
        '🔐 User authenticated: ${authUser.uid} (anonymous: ${authUser.isAnonymous})');

    // Ensure userId is loaded
    if (_userId == null || _userId!.isEmpty) {
      print('⏳ userId not loaded yet, fetching...');
      _userId = await _getUserUuid();
      if (_userId == null || _userId!.isEmpty) {
        throw Exception('Unable to get user ID');
      }
    }

    // Validate required fields
    final adopterName = _nameController.text.trim();
    if (adopterName.isEmpty) {
      throw Exception('Adopter name is required');
    }

    // Save user data locally if checkbox is checked
    await _saveUserData();

    // Validate time slot is selected
    if (selectedTimeSlot == null || selectedTimeSlot!.isEmpty) {
      throw Exception('Please select a time slot');
    }

    final shelterId = widget.organizationId!;
    final start = _parseStartDateTime(selectedTimeSlot!);
    final end = _parseEndDateTime(selectedTimeSlot!);

    // Create booking in bookings collection
    // Use orgId (as string) to match org portal naming convention
    final bookingData = {
      'userId': _userId ?? '',
      'adopter': adopterName, // Changed from adopterName to adopter (string)
      'catId': widget.catId != null && widget.catId!.isNotEmpty
          ? int.tryParse(widget.catId!) ?? 0
          : 0, // catId as integer
      'cat': widget.catName.isNotEmpty
          ? widget.catName
          : '', // Changed from catName to cat
      'orgId': shelterId, // orgId as string (already String)
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
      'endTimeZone': DateTime.now().timeZoneName, // Add endTimeZone
      'groupId': 1, // Add groupId
      'status':
          'Pending-shelter-setup', // Status when organization is in pending setup
      'appointmentType':
          _appointmentType ?? 'video', // Save selected appointment type
      'createdAt': Timestamp.now(),
    };

    // Debug: Check authentication state
    final currentAuthUser = FirebaseAuth.instance.currentUser;
    print('🔐 Auth check before booking creation:');
    print('   User: ${currentAuthUser?.uid ?? "null"}');
    print('   Anonymous: ${currentAuthUser?.isAnonymous ?? "null"}');
    print('   Email: ${currentAuthUser?.email ?? "null"}');

    // Debug: Verify required fields
    final requiredFields = [
      'userId',
      'adopter',
      'catId',
      'cat',
      'orgId',
      'start',
      'end',
      'status',
      'createdAt'
    ];
    final hasAllFields =
        requiredFields.every((field) => bookingData.containsKey(field));
    print('📋 Field check:');
    print('   Has all required fields: $hasAllFields');
    print(
        '   Missing fields: ${requiredFields.where((f) => !bookingData.containsKey(f)).toList()}');
    print('   Booking data keys: ${bookingData.keys.toList()}');

    print('📝 Creating booking with data:');
    print('   userId: ${bookingData['userId']}');
    print('   adopter: ${bookingData['adopter']}');
    print(
        '   catId: ${bookingData['catId']} (type: ${bookingData['catId'].runtimeType})');
    print('   cat: ${bookingData['cat']}');
    print('   orgId: ${bookingData['orgId']}');
    print('   status: ${bookingData['status']}');
    print('   start: ${bookingData['start']}');
    print('   end: ${bookingData['end']}');
    print('   createdAt: ${bookingData['createdAt']}');

    try {
      final bookingRef = await FirebaseFirestore.instance
          .collection('bookings')
          .add(bookingData);

      print('✅ Created booking: ${bookingRef.id}');

      // Create simple organization document if it doesn't exist
      final orgRef =
          FirebaseFirestore.instance.collection('organizations').doc(shelterId);

      // Check if organization already exists
      final orgDoc = await orgRef.get();

      await orgRef.set({
        'orgId': shelterId,
        'name': widget.organizationName,
        'email': widget.organizationEmail,
        'createdAt': Timestamp.now(),
        // Set pendingSetup to true if this is a new organization
        'pendingSetup':
            orgDoc.exists ? (orgDoc.data()?['pendingSetup'] ?? true) : true,
      }, SetOptions(merge: true));

      print('✅ Created/updated organization: $shelterId');

      // Send email to shelter (currently always gregoryew@gmail.com)
      try {
        final emailBody = _createSuggestionEmailBody();
        print('📧 Attempting to send suggestion email...');

        // Load .env file if available (using existing system)
        Map<String, String>? envMap;
        try {
          final server = globals.FelineFinderServer.instance;
          envMap = await server.parseStringToMap();
        } catch (e) {
          print('⚠️ Could not load .env file: $e');
        }

        final emailSent = await EmailService.sendEmail(
          toEmail: 'gregoryew@gmail.com', // For now, always send here
          subject:
              '${_nameController.text.trim()} wants to see ${widget.catName}',
          body: emailBody,
          fromName: 'Feline Finder Live',
          fromEmail: 'noreply@felinefinder.org',
          envMap: envMap,
        );

        if (emailSent) {
          print('✅ Sent suggestion email successfully');
        } else {
          print(
              '⚠️ Failed to send suggestion email (check email service URL in config.dart)');
          print('⚠️ Email service URL: ${AppConfig.emailServiceUrl}');
          print(
              '⚠️ Booking was created successfully, but email notification failed');
          // Continue anyway - booking is created, email failure is non-critical
        }
      } catch (e) {
        print('❌ Error sending suggestion email: $e');
        print(
            '❌ Make sure email service is deployed and URL is configured in config.dart');
        // Continue anyway - booking is created, email failure is non-critical
      }

      // Show success confirmation
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Suggestion Sent',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Your suggestion to meet ${widget.catName} on ${DateFormat('MMMM d').format(selectedDate)} at $selectedTimeSlot has been sent to the shelter.\n\nYou will be notified when the shelter sets up their account and assigns a volunteer.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'OK',
                style: GoogleFonts.poppins(
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ),
      );
    } on FirebaseException catch (e) {
      print('❌ Firestore error: ${e.code} - ${e.message}');
      String errorMessage = 'Failed to create booking';
      if (e.code == 'permission-denied') {
        errorMessage =
            'Permission denied. Please ensure you are signed in and try again.';
        print('🔐 Security rules violation - user may not be authenticated');
        print(
            '   Current auth user: ${FirebaseAuth.instance.currentUser?.uid ?? "null"}');
      } else if (e.code == 'failed-precondition') {
        errorMessage =
            'Failed precondition. Required fields may be missing or invalid.';
        print('📋 Check that all required booking fields are present:');
        print(
            '   Required: userId, adopter, catId, cat, orgId, start, end, status, createdAt');
      } else {
        errorMessage = 'Error: ${e.message ?? e.code}';
      }

      // Show error to user
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog if any
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Error',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            content: Text(
              errorMessage,
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      rethrow;
    } catch (e) {
      print('❌ Unexpected error creating booking: $e');
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog if any
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Error',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            content: Text(
              'Failed to create booking: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      rethrow;
    }
  }

  /// Create email body for suggestion
  String _createSuggestionEmailBody() {
    final portalUrl = 'https://feline-finder-org-portal.web.app';
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(selectedDate);
    final timeStr = selectedTimeSlot ?? 'Not specified';

    // Determine appointment type text - always show the adopter's preference
    String appointmentTypeText = '';
    final selectedType = _appointmentType == 'video' ? 'Video' : 'In Person';

    if (_isPendingSetup || (_inPerson == true && _webMeeting == true)) {
      appointmentTypeText = '''
                <p><strong>Preferred Appointment Type:</strong> $selectedType</p>
                <p><strong>Available Options:</strong> This adopter can choose between Video meetings or In Person appointments. When you set up your account, you can configure which types of appointments you'd like to offer.</p>
            ''';
    } else if (_webMeeting == true) {
      appointmentTypeText = '<p><strong>Appointment Type:</strong> Video</p>';
    } else if (_inPerson == true) {
      appointmentTypeText =
          '<p><strong>Appointment Type:</strong> In Person</p>';
    }

    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .header { background: linear-gradient(135deg, #2196F3, #21CBF3); 
                     color: white; padding: 30px 20px; text-align: center; }
            .content { padding: 30px 20px; background: #f9f9f9; max-width: 600px; margin: 0 auto; }
            .info-box { background: #e3f2fd; padding: 20px; 
                       margin: 20px 0; border-left: 4px solid #2196F3; border-radius: 4px; }
            .cta-button { display: inline-block; padding: 15px 30px; 
                         background: #2196F3; color: white; text-decoration: none; 
                         border-radius: 5px; font-weight: bold; margin: 20px 0; }
            .cta-button:hover { background: #1976D2; }
            .link { color: #2196F3; text-decoration: underline; }
            .footer { margin-top: 30px; padding-top: 20px; 
                     border-top: 1px solid #ddd; font-size: 12px; color: #666; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🐱 Someone Wants to Meet ${widget.catName}</h1>
        </div>
        <div class="content">
            <p><strong>${_nameController.text.trim()}</strong> is interested in meeting <strong>${widget.catName}</strong> from your shelter.</p>
            
            <div class="info-box">
                <h3>📅 Suggested Date & Time</h3>
                <p><strong>Date:</strong> $dateStr</p>
                <p><strong>Time:</strong> $timeStr</p>
                $appointmentTypeText
            </div>

            <h2>What is Feline Finder Live?</h2>
            <p>Feline Finder Live is a free, open-source platform that connects adopters with shelters like yours. Your role is simple: set up your account once (about 10 minutes), and your cats become directly bookable through Feline Finder.</p>

            <h3>Key Benefits:</h3>
            <ul>
                <li><strong>Free and Open Source</strong> - No cost to you</li>
                <li><strong>Easy Setup</strong> - Your cats are already listed on Rescue Groups, so we can import them automatically</li>
                <li><strong>Uses Tools You Already Have</strong> - Works with Google Calendar and email</li>
                <li><strong>Saves Time</strong> - Automates scheduling, so you can focus on showing cats to adopters</li>
            </ul>

            <p>Since you already use Rescue Groups, your cats are already listed there. This integration will streamline your scheduling process and help you spend more time with adopters instead of managing appointments manually.</p>

            <div style="text-align: center; margin: 30px 0;">
                <a href="$portalUrl" class="cta-button">Get Started (About 10 Minutes)</a>
                <p style="margin-top: 10px;">
                    <a href="$portalUrl" class="link">Or click here to visit the portal</a>
                </p>
            </div>

            <p>All you need to do is click the button above and complete a quick onboarding process. Once you're set up, adopters like ${_nameController.text.trim()} will be able to book appointments directly, and you'll receive notifications that integrate with your existing workflow.</p>

            <div class="footer">
                <p>This email was sent because someone expressed interest in meeting one of your cats through Feline Finder Live. If you have questions, please contact us.</p>
                <p><strong>Feline Finder Live Team</strong></p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        selectedTimeSlot = null; // Reset time slot when date changes
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableSlots = getAvailableTimeSlots();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        padding: const EdgeInsets.all(24),
        child: _isLoadingUserData
            ? Center(
                child: CircularProgressIndicator(),
              )
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          // Cat photo
                          if (widget.catImageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                widget.catImageUrl!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.pets,
                                      color: Colors.grey[600],
                                      size: 30,
                                    ),
                                  );
                                },
                              ),
                            )
                          else
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.pets,
                                color: Theme.of(context).primaryColor,
                                size: 30,
                              ),
                            ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Schedule Appointment',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'to meet ${widget.catName}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  'at ${widget.organizationName}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[600],
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

                      // User Information Section
                      Text(
                        'Your Information',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Required to schedule an appointment',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          hintText: 'Enter your full name',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                        style: GoogleFonts.poppins(fontSize: 15),
                      ),
                      const SizedBox(height: 12),

                      // Email Field (always required)
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email address',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          // Email is always required
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!_isValidEmail(value.trim())) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                        style: GoogleFonts.poppins(fontSize: 15),
                      ),
                      const SizedBox(height: 12),

                      // Phone Field (Optional)
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone (Optional)',
                          hintText: 'Enter your phone number',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        style: GoogleFonts.poppins(fontSize: 15),
                      ),
                      const SizedBox(height: 16),

                      // Save user info checkbox
                      CheckboxListTile(
                        title: Text(
                          'Save my information for future appointments',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Your name and email will be pre-filled next time',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        value: _saveUserInfo,
                        onChanged: (value) {
                          setState(() {
                            _saveUserInfo = value ?? false;
                          });
                        },
                        activeColor: Theme.of(context).primaryColor,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Organization State UI
                      if (_organizationState == OrganizationState.loading)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_organizationState == OrganizationState.notFound)
                        _buildSuggestionFlowUI()
                      else if (_organizationState ==
                          OrganizationState.found) ...[
                        // Show suggestion message if pending setup
                        if (_isPendingSetup) ...[
                          // When pending setup, show the full suggestion flow UI which includes
                          // date picker and time slots - don't show them again below
                          _buildSuggestionFlowUI(),
                        ] else ...[
                          // Regular flow: show appointment type selection
                          if (_inPerson == true && _webMeeting == true)
                            _buildAppointmentTypeSelection()
                          else if (_webMeeting == true && _inPerson == false)
                            _buildSingleOptionMessage(
                                'Shelter Only Does Video Bookings')
                          else if (_inPerson == true && _webMeeting == false)
                            _buildSingleOptionMessage(
                                'Shelter Only Does In Person Bookings'),
                          const SizedBox(height: 16),
                        ],
                      ],
                      // Note: OrganizationState.noOptions is no longer used -
                      // organizations without options are treated as pending setup

                      // Date Picker and Time Slots (only show if NOT pending setup)
                      // When pending setup, they're already included in _buildSuggestionFlowUI()
                      if (_organizationState == OrganizationState.found &&
                          !_isPendingSetup &&
                          (_inPerson == true || _webMeeting == true)) ...[
                        const Divider(),
                        const SizedBox(height: 16),
                        // Date Picker
                        Text(
                          'Select Date',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => _selectDate(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_month,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    DateFormat('EEEE, MMMM d, yyyy')
                                        .format(selectedDate),
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.grey[600],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Available Time Slots
                        Text(
                          'Available Time Slots',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: availableSlots.length,
                          itemBuilder: (context, index) {
                            final timeSlot = availableSlots[index];
                            final startTime = timeSlot['start']!;
                            final endTime = timeSlot['end']!;
                            final timeDisplay = '$startTime - $endTime';
                            final isSelected = selectedTimeSlot == startTime;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    selectedTimeSlot = startTime;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey[300]!,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        color: isSelected
                                            ? Colors.white
                                            : Theme.of(context).primaryColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        timeDisplay,
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const Spacer(),
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(
                                  color: Colors.grey[400]!,
                                ),
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
                              onPressed: ((_organizationState ==
                                              OrganizationState.notFound ||
                                          _isPendingSetup)
                                      ? (selectedTimeSlot == null ||
                                          _isSubmitting)
                                      : (_organizationState !=
                                              OrganizationState.found ||
                                          (_inPerson != true &&
                                              _webMeeting != true) ||
                                          selectedTimeSlot == null ||
                                          _isSubmitting))
                                  ? null
                                  : () async {
                                      // Validate form
                                      if (!_formKey.currentState!.validate()) {
                                        return;
                                      }

                                      setState(() {
                                        _isSubmitting = true;
                                      });

                                      try {
                                        // Handle different flows
                                        if (_organizationState ==
                                                OrganizationState.notFound ||
                                            _isPendingSetup) {
                                          // Suggestion flow (no org or pending setup)
                                          await _createSuggestion();
                                        } else if (_organizationState ==
                                            OrganizationState.found) {
                                          // Regular appointment flow
                                          await _createRegularAppointment();
                                        }
                                      } catch (e) {
                                        // Show error
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text(
                                              'Error',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            content: Text(
                                              'Failed to ${(_organizationState == OrganizationState.notFound || _isPendingSetup) ? "suggest" : "create"} appointment. Please try again.\n\nError: $e',
                                              style: GoogleFonts.poppins(),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                                child: Text(
                                                  'OK',
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      } finally {
                                        setState(() {
                                          _isSubmitting = false;
                                        });
                                      }
                                    },
                              child: _isSubmitting
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : Text(
                                      (_organizationState ==
                                                  OrganizationState.notFound ||
                                              _isPendingSetup)
                                          ? 'Suggest'
                                          : 'Schedule',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
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
      ),
    );
  }
}
