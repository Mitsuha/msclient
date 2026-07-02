class UserProfile {
  const UserProfile({
    required this.id,
    required this.phone,
    required this.email,
    required this.nickname,
    required this.priceRatio,
    required this.inviteCode,
    required this.alipayAccount,
    required this.alipayName,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String phone;
  final String email;
  final String nickname;
  final num priceRatio;
  final String inviteCode;
  final String alipayAccount;
  final String alipayName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayAccount => email.isNotEmpty ? email : phone;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: _int(json['id']),
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      priceRatio: json['price_ratio'] is num ? json['price_ratio'] as num : 1,
      inviteCode: json['invite_code']?.toString() ?? '',
      alipayAccount: json['alipay_account']?.toString() ?? '',
      alipayName: json['alipay_name']?.toString() ?? '',
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'email': email,
      'nickname': nickname,
      'price_ratio': priceRatio,
      'invite_code': inviteCode,
      'alipay_account': alipayAccount,
      'alipay_name': alipayName,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class LoginResult {
  const LoginResult({required this.token, required this.user});

  final String token;
  final UserProfile user;

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      token: json['token']?.toString() ?? '',
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _date(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}
