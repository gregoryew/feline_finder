import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  final String id;
  final String catId;
  final String catName;
  final String organizationId;
  final String organizationName;
  final String organizationEmail;
  final String userId;
  final String userName;
  final String userEmail;
  final String? userPhone;
  final DateTime appointmentDate;
  final String timeSlot;
  final String status; // 'pending', 'confirmed', 'cancelled'
  final DateTime createdAt;
  final String? notes;
  final String? catImageUrl;

  Appointment({
    required this.id,
    required this.catId,
    required this.catName,
    required this.organizationId,
    required this.organizationName,
    required this.organizationEmail,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.userPhone,
    required this.appointmentDate,
    required this.timeSlot,
    this.status = 'pending',
    required this.createdAt,
    this.notes,
    this.catImageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'catId': catId,
      'catName': catName,
      'organizationId': organizationId,
      'organizationName': organizationName,
      'organizationEmail': organizationEmail,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'appointmentDate': appointmentDate.toIso8601String(),
      'timeSlot': timeSlot,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'notes': notes,
      'catImageUrl': catImageUrl,
    };
  }

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] ?? '',
      catId: json['catId'] ?? '',
      catName: json['catName'] ?? '',
      organizationId: json['organizationId'] ?? '',
      organizationName: json['organizationName'] ?? '',
      organizationEmail: json['organizationEmail'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userEmail: json['userEmail'] ?? '',
      userPhone: json['userPhone'],
      appointmentDate: DateTime.parse(json['appointmentDate']),
      timeSlot: json['timeSlot'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['createdAt']),
      notes: json['notes'],
      catImageUrl: json['catImageUrl'],
    );
  }

  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Appointment.fromJson(data);
  }

  Appointment copyWith({
    String? id,
    String? catId,
    String? catName,
    String? organizationId,
    String? organizationName,
    String? organizationEmail,
    String? userId,
    String? userName,
    String? userEmail,
    String? userPhone,
    DateTime? appointmentDate,
    String? timeSlot,
    String? status,
    DateTime? createdAt,
    String? notes,
    String? catImageUrl,
  }) {
    return Appointment(
      id: id ?? this.id,
      catId: catId ?? this.catId,
      catName: catName ?? this.catName,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      organizationEmail: organizationEmail ?? this.organizationEmail,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPhone: userPhone ?? this.userPhone,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      timeSlot: timeSlot ?? this.timeSlot,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      catImageUrl: catImageUrl ?? this.catImageUrl,
    );
  }
}

