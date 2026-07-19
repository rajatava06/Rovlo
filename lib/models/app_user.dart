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
    this.bio,
    this.isBlocked = false,
    this.profileComplete = false,
    this.dob,
    this.homeBase,
    this.isVerified = false,
    this.subscriptionTier = 'free',
    this.emergencyContacts = const [],
    this.profilePhotos = const <String>[],
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
  final String? bio;
  final bool isBlocked;
  final bool profileComplete;
  final String? dob;
  final String? homeBase;
  final bool isVerified;
  final String subscriptionTier;
  final List<Map<String, String>> emergencyContacts;
  final List<String> profilePhotos;

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

  /// Returns user's profile pictures. If profilePhotos is empty but photoUrl is present,
  /// returns a list containing photoUrl to maintain backward compatibility.
  List<String> get effectivePhotos {
    if (profilePhotos.isNotEmpty) return profilePhotos;
    if (photoUrl != null && photoUrl!.isNotEmpty) return [photoUrl!];
    return const [];
  }

  /// Calculates profile completion percentage (0.0 to 1.0).
  double get profileCompletionPercent {
    int filled = 0;
    const total = 9;
    if (name != null && name!.trim().isNotEmpty) filled++;
    if (bio != null && bio!.trim().isNotEmpty) filled++;
    if (effectivePhotos.isNotEmpty) filled++;
    if (dob != null && dob!.isNotEmpty) filled++;
    if (homeBase != null && homeBase!.isNotEmpty) filled++;
    if (gender != null && gender!.isNotEmpty) filled++;
    if (travelInterests.isNotEmpty) filled++;
    if (isVerified) filled++;
    if (emergencyContacts.isNotEmpty) filled++;
    return filled / total;
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? phoneNumber,
    String? gender,
    AuthMethod? authMethod,
    List<String>? travelInterests,
    String? photoUrl,
    String? bio,
    bool? isBlocked,
    bool? profileComplete,
    String? dob,
    String? homeBase,
    bool? isVerified,
    String? subscriptionTier,
    List<Map<String, String>>? emergencyContacts,
    List<String>? profilePhotos,
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
      bio: bio ?? this.bio,
      isBlocked: isBlocked ?? this.isBlocked,
      profileComplete: profileComplete ?? this.profileComplete,
      dob: dob ?? this.dob,
      homeBase: homeBase ?? this.homeBase,
      isVerified: isVerified ?? this.isVerified,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      profilePhotos: profilePhotos ?? this.profilePhotos,
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
        'bio': bio,
        'isBlocked': isBlocked,
        'profileComplete': profileComplete,
        'dob': dob,
        'homeBase': homeBase,
        'isVerified': isVerified,
        'subscriptionTier': subscriptionTier,
        'emergencyContacts': emergencyContacts,
        'profilePhotos': profilePhotos,
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
        bio: map['bio'] as String?,
        isBlocked: map['isBlocked'] as bool? ?? false,
        profileComplete: map['profileComplete'] as bool? ?? false,
        dob: map['dob'] as String?,
        homeBase: map['homeBase'] as String?,
        isVerified: map['isVerified'] as bool? ?? false,
        subscriptionTier: map['subscriptionTier'] as String? ?? 'free',
        emergencyContacts: (map['emergencyContacts'] as List<dynamic>? ?? const [])
            .map((e) => Map<String, String>.from(e as Map))
            .toList(),
        profilePhotos: (map['profilePhotos'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => e.toString())
            .toList(),
      );

  String toJson() => jsonEncode(toMap());
  factory AppUser.fromJson(String source) =>
      AppUser.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
