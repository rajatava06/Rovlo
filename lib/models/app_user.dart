import 'dart:convert';

/// Authentication provider used to create / sign into an account.
enum AuthMethod { google, apple, phone }

/// A Rovlo user account + profile.
class AppUser {
  const AppUser({
    required this.id,
    required this.createdAt,
    this.name,
    this.email,
    this.phoneNumber,
    this.gender,
    this.authMethod = AuthMethod.phone,
    this.travelInterests = const <String>[],
    this.photoUrl,
    this.isBlocked = false,
    this.profileComplete = false,
  });

  final String id;
  final DateTime createdAt;
  final String? name;
  final String? email;
  final String? phoneNumber;
  final String? gender;
  final AuthMethod authMethod;
  final List<String> travelInterests;
  final String? photoUrl;
  final bool isBlocked;
  final bool profileComplete;

  bool get isAdmin => false; // resolved via AppConstants.isAdminEmail(email)

  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    if (email != null && email!.isNotEmpty) return email!.split('@').first;
    if (phoneNumber != null && phoneNumber!.isNotEmpty) return phoneNumber!;
    return 'Traveller';
  }

  String get initials {
    final source = displayName.trim();
    if (source.isEmpty) return 'R';
    final parts =
        source.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'R';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? phoneNumber,
    String? gender,
    AuthMethod? authMethod,
    List<String>? travelInterests,
    String? photoUrl,
    bool? isBlocked,
    bool? profileComplete,
  }) {
    return AppUser(
      id: id,
      createdAt: createdAt,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      gender: gender ?? this.gender,
      authMethod: authMethod ?? this.authMethod,
      travelInterests: travelInterests ?? this.travelInterests,
      photoUrl: photoUrl ?? this.photoUrl,
      isBlocked: isBlocked ?? this.isBlocked,
      profileComplete: profileComplete ?? this.profileComplete,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'name': name,
        'email': email,
        'phoneNumber': phoneNumber,
        'gender': gender,
        'authMethod': authMethod.name,
        'travelInterests': travelInterests,
        'photoUrl': photoUrl,
        'isBlocked': isBlocked,
        'profileComplete': profileComplete,
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] as String,
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
        name: map['name'] as String?,
        email: map['email'] as String?,
        phoneNumber: map['phoneNumber'] as String?,
        gender: map['gender'] as String?,
        authMethod: AuthMethod.values.firstWhere(
          (m) => m.name == map['authMethod'],
          orElse: () => AuthMethod.phone,
        ),
        travelInterests:
            (map['travelInterests'] as List<dynamic>? ?? const <dynamic>[])
                .map((e) => e.toString())
                .toList(),
        photoUrl: map['photoUrl'] as String?,
        isBlocked: map['isBlocked'] as bool? ?? false,
        profileComplete: map['profileComplete'] as bool? ?? false,
      );

  String toJson() => jsonEncode(toMap());
  factory AppUser.fromJson(String source) =>
      AppUser.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
