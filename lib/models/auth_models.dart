class AuthToken {
  const AuthToken({required this.accessToken, required this.expiresIn});

  final String accessToken;
  final int expiresIn;

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    return AuthToken(
      accessToken: json['access_token'] as String? ?? '',
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 0,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    this.phone,
    this.iin,
    this.organizationId,
    this.managerId,
    this.organizationMode,
  });

  final String id;
  final String username;
  final String fullName;
  final String email;
  final String role;
  final String? phone;
  final String? iin;
  final String? organizationId;
  final String? managerId;
  final String? organizationMode;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      username: json['username'] as String? ?? '',
      fullName: json['full_username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      phone: json['phone'] as String?,
      iin: json['iin'] as String?,
      organizationId: json['organization_id']?.toString(),
      managerId: json['manager_id']?.toString(),
      organizationMode: json['organization_mode'] as String?,
    );
  }
}
