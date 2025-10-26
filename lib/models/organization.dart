class Organization {
  final String orgId;
  final String verificationUuid;
  final String name;
  final String email;
  final DateTime createdAt;
  final bool isVerified;
  final String? adminUserId;
  final DateTime? verifiedAt;

  Organization({
    required this.orgId,
    required this.verificationUuid,
    required this.name,
    required this.email,
    required this.createdAt,
    this.isVerified = false,
    this.adminUserId,
    this.verifiedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'orgId': orgId,
      'verificationUuid': verificationUuid,
      'name': name,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
      'isVerified': isVerified,
      'adminUserId': adminUserId,
      'verifiedAt': verifiedAt?.toIso8601String(),
    };
  }

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      orgId: json['orgId'] ?? '',
      verificationUuid: json['verificationUuid'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      isVerified: json['isVerified'] ?? false,
      adminUserId: json['adminUserId'],
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.parse(json['verifiedAt'])
          : null,
    );
  }

  Organization copyWith({
    String? orgId,
    String? verificationUuid,
    String? name,
    String? email,
    DateTime? createdAt,
    bool? isVerified,
    String? adminUserId,
    DateTime? verifiedAt,
  }) {
    return Organization(
      orgId: orgId ?? this.orgId,
      verificationUuid: verificationUuid ?? this.verificationUuid,
      name: name ?? this.name,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      isVerified: isVerified ?? this.isVerified,
      adminUserId: adminUserId ?? this.adminUserId,
      verifiedAt: verifiedAt ?? this.verifiedAt,
    );
  }
}

class OrganizationVerificationRequest {
  final String orgId;
  final String? name;
  final String? email;

  OrganizationVerificationRequest({
    required this.orgId,
    this.name,
    this.email,
  });

  Map<String, dynamic> toJson() {
    return {
      'orgId': orgId,
      'name': name,
      'email': email,
    };
  }

  factory OrganizationVerificationRequest.fromJson(Map<String, dynamic> json) {
    return OrganizationVerificationRequest(
      orgId: json['orgId'] ?? '',
      name: json['name'],
      email: json['email'],
    );
  }
}
