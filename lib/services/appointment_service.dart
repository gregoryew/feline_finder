import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/appointment.dart';
import '../services/email_service.dart';

class AppointmentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName =
      'bookings'; // Changed from 'appointments' to 'bookings'

  /// Creates a new appointment (saved as booking)
  static Future<Appointment?> createAppointment({
    required String catId,
    required String catName,
    required String organizationId,
    required String organizationName,
    required String organizationEmail,
    required String userId,
    required String userName,
    required String userEmail,
    String? userPhone,
    required DateTime appointmentDate,
    required String timeSlot,
    String? notes,
    String? catImageUrl,
  }) async {
    try {
      // Parse timeSlot to get start and end times
      // timeSlot format is typically like "2:00 PM" or "14:00"
      final start = _parseDateTimeFromSlot(appointmentDate, timeSlot);
      final end = start
          .add(const Duration(minutes: 30)); // Default 30 minute appointment

      final bookingId = const Uuid().v4();

      // Convert catId to integer if possible
      final catIdInt = int.tryParse(catId) ?? 0;

      // Save to bookings collection using the new format
      final bookingData = {
        'userId': userId,
        'adopter': userName, // Changed from userName to adopter
        'catId': catIdInt, // catId as integer
        'cat': catName, // Changed from catName to cat
        'orgId':
            organizationId, // Changed from organizationId to orgId (as string)
        'start': Timestamp.fromDate(start),
        'end': Timestamp.fromDate(end),
        'endTimeZone': DateTime.now().timeZoneName,
        'groupId': 1,
        'status': 'pending',
        'appointmentType': 'in-person', // Default, can be updated
        'createdAt': Timestamp.now(),
        // Additional fields for backward compatibility
        'organizationName': organizationName,
        'organizationEmail': organizationEmail,
        'userEmail': userEmail,
        'userPhone': userPhone,
        'timeSlot': timeSlot,
        'notes': notes,
        'catImageUrl': catImageUrl,
      };

      await _firestore
          .collection(_collectionName)
          .doc(bookingId)
          .set(bookingData);

      // Create Appointment object for email sending (using old format for compatibility)
      final appointment = Appointment(
        id: bookingId,
        catId: catId,
        catName: catName,
        organizationId: organizationId,
        organizationName: organizationName,
        organizationEmail: organizationEmail,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        userPhone: userPhone,
        appointmentDate: appointmentDate,
        timeSlot: timeSlot,
        status: 'pending',
        createdAt: DateTime.now(),
        notes: notes,
        catImageUrl: catImageUrl,
      );

      // Send confirmation emails
      await _sendAppointmentEmails(appointment);

      return appointment;
    } catch (e) {
      print('Error creating appointment: $e');
      return null;
    }
  }

  /// Parse time slot string to DateTime
  static DateTime _parseDateTimeFromSlot(DateTime date, String timeSlot) {
    // Handle formats like "2:00 PM", "14:00", "2 PM", etc.
    final timeStr = timeSlot.trim().toUpperCase();
    final isPM = timeStr.contains('PM');
    final isAM = timeStr.contains('AM');

    // Extract hour and minute
    final timeMatch = RegExp(r'(\d{1,2}):?(\d{2})?').firstMatch(timeStr);
    if (timeMatch == null) {
      // Default to noon if parsing fails
      return DateTime(date.year, date.month, date.day, 12, 0);
    }

    var hour = int.parse(timeMatch.group(1) ?? '12');
    final minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;

    if (isPM && hour != 12) hour += 12;
    if (isAM && hour == 12) hour = 0;

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Get appointment by ID (from bookings collection)
  static Future<Appointment?> getAppointment(String appointmentId) async {
    try {
      final doc =
          await _firestore.collection(_collectionName).doc(appointmentId).get();

      if (doc.exists) {
        return _bookingToAppointment(doc);
      }
      return null;
    } catch (e) {
      print('Error getting appointment: $e');
      return null;
    }
  }

  /// Get all appointments for a user (from bookings collection)
  static Stream<List<Appointment>> getUserAppointments(String userId) {
    try {
      return _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .orderBy('start', descending: false)
          .snapshots()
          .map((snapshot) {
        print(
            '📋 getUserAppointments: Found ${snapshot.docs.length} bookings for user $userId');
        return snapshot.docs
            .map((doc) => _bookingToAppointment(doc))
            .where((appt) => appt != null)
            .cast<Appointment>()
            .toList();
      }).handleError((error) {
        print('❌ Error in getUserAppointments: $error');
        // If index error, try without orderBy
        if (error.toString().contains('index') ||
            error.toString().contains('requires an index')) {
          print('⚠️ Index missing, trying query without orderBy');
          return _firestore
              .collection(_collectionName)
              .where('userId', isEqualTo: userId)
              .snapshots()
              .map((snapshot) {
            final appointments = snapshot.docs
                .map((doc) => _bookingToAppointment(doc))
                .where((appt) => appt != null)
                .cast<Appointment>()
                .toList();
            // Sort manually
            appointments
                .sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));
            return appointments;
          });
        }
        return Stream.value(<Appointment>[]);
      });
    } catch (e) {
      print('❌ Exception in getUserAppointments: $e');
      return Stream.value(<Appointment>[]);
    }
  }

  /// Get all appointments for an organization (from bookings collection)
  static Stream<List<Appointment>> getOrganizationAppointments(
      String organizationId) {
    try {
      return _firestore
          .collection(_collectionName)
          .where('orgId', isEqualTo: organizationId)
          .orderBy('start', descending: false)
          .snapshots()
          .map((snapshot) {
        print(
            '📋 getOrganizationAppointments: Found ${snapshot.docs.length} bookings for org $organizationId');
        return snapshot.docs
            .map((doc) => _bookingToAppointment(doc))
            .where((appt) => appt != null)
            .cast<Appointment>()
            .toList();
      }).handleError((error) {
        print('❌ Error in getOrganizationAppointments: $error');
        // If index error, try without orderBy
        if (error.toString().contains('index') ||
            error.toString().contains('requires an index')) {
          print('⚠️ Index missing, trying query without orderBy');
          return _firestore
              .collection(_collectionName)
              .where('orgId', isEqualTo: organizationId)
              .snapshots()
              .map((snapshot) {
            final appointments = snapshot.docs
                .map((doc) => _bookingToAppointment(doc))
                .where((appt) => appt != null)
                .cast<Appointment>()
                .toList();
            // Sort manually
            appointments
                .sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));
            return appointments;
          });
        }
        return Stream.value(<Appointment>[]);
      });
    } catch (e) {
      print('❌ Exception in getOrganizationAppointments: $e');
      return Stream.value(<Appointment>[]);
    }
  }

  /// Convert booking document to Appointment object
  static Appointment? _bookingToAppointment(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;

      // Map booking fields to appointment fields
      final start = (data['start'] as Timestamp?)?.toDate() ?? DateTime.now();
      // Handle catId as both int (from bookings) and string (legacy)
      final catId = data['catId']?.toString() ?? '';
      final catName = data['cat'] ?? data['catName'] ?? '';
      final orgId = data['orgId'] ?? data['organizationId'] ?? '';
      final adopter = data['adopter'] ?? data['userName'] ?? '';
      final userEmail = data['userEmail'] ?? data['adopterEmail'] ?? '';

      // Format time slot from start time
      final timeSlot = _formatTimeSlot(start);

      return Appointment(
        id: doc.id,
        catId: catId,
        catName: catName,
        organizationId: orgId,
        organizationName: data['organizationName'] ?? '',
        organizationEmail: data['organizationEmail'] ?? '',
        userId: data['userId'] ?? '',
        userName: adopter,
        userEmail: userEmail,
        userPhone: data['userPhone'],
        appointmentDate: start,
        timeSlot: timeSlot,
        status: data['status'] ?? 'pending',
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        notes: data['notes'],
        catImageUrl: data['catImageUrl'],
      );
    } catch (e) {
      print('Error converting booking to appointment: $e');
      return null;
    }
  }

  /// Format DateTime to time slot string
  static String _formatTimeSlot(DateTime dateTime) {
    final hour = dateTime.hour == 0
        ? 12
        : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Update appointment status
  static Future<bool> updateAppointmentStatus(
      String appointmentId, String status) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(appointmentId)
          .update({'status': status});
      return true;
    } catch (e) {
      print('Error updating appointment status: $e');
      return false;
    }
  }

  /// Cancel appointment
  static Future<bool> cancelAppointment(String appointmentId) async {
    return await updateAppointmentStatus(appointmentId, 'cancelled');
  }

  /// Confirm appointment
  static Future<bool> confirmAppointment(String appointmentId) async {
    return await updateAppointmentStatus(appointmentId, 'confirmed');
  }

  /// Delete appointment
  static Future<bool> deleteAppointment(String appointmentId) async {
    try {
      await _firestore.collection(_collectionName).doc(appointmentId).delete();
      return true;
    } catch (e) {
      print('Error deleting appointment: $e');
      return false;
    }
  }

  /// Send appointment confirmation emails
  static Future<void> _sendAppointmentEmails(Appointment appointment) async {
    try {
      // Email to shelter
      await EmailService.sendEmail(
        toEmail: appointment.organizationEmail,
        subject: 'New Appointment Request for ${appointment.catName}',
        body: _createShelterEmailBody(appointment),
        fromName: 'Feline Finder',
        fromEmail: 'noreply@felinefinder.org',
      );

      // Email to user
      await EmailService.sendEmail(
        toEmail: appointment.userEmail,
        subject: 'Appointment Requested - ${appointment.catName}',
        body: _createUserEmailBody(appointment),
        fromName: 'Feline Finder',
        fromEmail: 'noreply@felinefinder.org',
      );
    } catch (e) {
      print('Error sending appointment emails: $e');
    }
  }

  /// Create email body for shelter
  static String _createShelterEmailBody(Appointment appointment) {
    final dateStr = appointment.appointmentDate.toString().split(' ')[0];
    final userPhoneText = appointment.userPhone != null
        ? '<p><strong>Phone:</strong> ${appointment.userPhone}</p>'
        : '';
    final notesText = appointment.notes != null
        ? '<p><strong>Notes:</strong> ${appointment.notes}</p>'
        : '';

    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; }
            .header { background: linear-gradient(135deg, #2196F3, #21CBF3); 
                     color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; background: #f9f9f9; }
            .info-box { background: #e3f2fd; padding: 15px; 
                       margin: 15px 0; border-left: 4px solid #2196F3; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🐱 New Appointment Request</h1>
        </div>
        <div class="content">
            <p>Hello ${appointment.organizationName},</p>
            
            <p>You have received a new appointment request for <strong>${appointment.catName}</strong>.</p>
            
            <div class="info-box">
                <h3>📅 Appointment Details</h3>
                <p><strong>Date:</strong> $dateStr</p>
                <p><strong>Time:</strong> ${appointment.timeSlot}</p>
            </div>
            
            <div class="info-box">
                <h3>👤 Visitor Information</h3>
                <p><strong>Name:</strong> ${appointment.userName}</p>
                <p><strong>Email:</strong> ${appointment.userEmail}</p>
                $userPhoneText
                $notesText
            </div>
            
            <p>Please review this request and contact the visitor to confirm availability.</p>
            
            <p>Best regards,<br>Feline Finder Team</p>
        </div>
    </body>
    </html>
    ''';
  }

  /// Create email body for user
  static String _createUserEmailBody(Appointment appointment) {
    final dateStr = appointment.appointmentDate.toString().split(' ')[0];

    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; }
            .header { background: linear-gradient(135deg, #2196F3, #21CBF3); 
                     color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; background: #f9f9f9; }
            .info-box { background: #e8f5e9; padding: 15px; 
                       margin: 15px 0; border-left: 4px solid #4CAF50; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🐱 Appointment Request Confirmed</h1>
        </div>
        <div class="content">
            <p>Hello ${appointment.userName},</p>
            
            <p>Your appointment request has been submitted successfully!</p>
            
            <div class="info-box">
                <h3>📅 Appointment Details</h3>
                <p><strong>Cat:</strong> ${appointment.catName}</p>
                <p><strong>Organization:</strong> ${appointment.organizationName}</p>
                <p><strong>Date:</strong> $dateStr</p>
                <p><strong>Time:</strong> ${appointment.timeSlot}</p>
            </div>
            
            <p>The organization will review your request and contact you at ${appointment.userEmail} to confirm the appointment.</p>
            
            <p>Thank you for using Feline Finder! 🐾</p>
            
            <p>Best regards,<br>Feline Finder Team</p>
        </div>
    </body>
    </html>
    ''';
  }
}
