import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/appointment.dart';
import '../services/email_service.dart';

class AppointmentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'appointments';

  /// Creates a new appointment
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
      final appointmentId = const Uuid().v4();
      final appointment = Appointment(
        id: appointmentId,
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

      // Save to Firestore
      await _firestore
          .collection(_collectionName)
          .doc(appointmentId)
          .set(appointment.toJson());

      // Send confirmation emails
      await _sendAppointmentEmails(appointment);

      return appointment;
    } catch (e) {
      print('Error creating appointment: $e');
      return null;
    }
  }

  /// Get appointment by ID
  static Future<Appointment?> getAppointment(String appointmentId) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(appointmentId)
          .get();

      if (doc.exists) {
        return Appointment.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting appointment: $e');
      return null;
    }
  }

  /// Get all appointments for a user
  static Stream<List<Appointment>> getUserAppointments(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('appointmentDate', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Appointment.fromFirestore(doc))
          .toList();
    });
  }

  /// Get all appointments for an organization
  static Stream<List<Appointment>> getOrganizationAppointments(
      String organizationId) {
    return _firestore
        .collection(_collectionName)
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('appointmentDate', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Appointment.fromFirestore(doc))
          .toList();
    });
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
      await _firestore
          .collection(_collectionName)
          .doc(appointmentId)
          .delete();
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
        fromEmail: 'noreply@felinefinder.app',
      );

      // Email to user
      await EmailService.sendEmail(
        toEmail: appointment.userEmail,
        subject: 'Appointment Requested - ${appointment.catName}',
        body: _createUserEmailBody(appointment),
        fromName: 'Feline Finder',
        fromEmail: 'noreply@felinefinder.app',
      });
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
    final notesText =
        appointment.notes != null ? '<p><strong>Notes:</strong> ${appointment.notes}</p>' : '';

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

