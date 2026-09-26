/// App-wide constants for Rovlo.
class AppConstants {
  AppConstants._();

  static const String appName = 'Rovlo';
  static const String tagline = 'Wander more. Worry less.';

  /// Background video shown on the Welcome screen.
  /// Drop an .mp4 at this path to enable the video; otherwise an animated
  /// gradient fallback is shown automatically.
  static const String welcomeVideoAsset = 'assets/videos/welcome.mp4';
  static const String signInVideoAsset = 'assets/videos/signinvideo.mp4';

  /// Phone-number OTP verification. There is no SMS provider wired up yet, so
  /// the code step is OFF: the number is simply saved on the profile (unverified)
  /// and sign-in security comes from Google / Apple. Set to true only after
  /// connecting an SMS service (see SUPABASE_SETUP.md §9) — the fake demo code
  /// must never ship in a public release.
  static const bool phoneOtpEnabled = false;

  /// Rovlo+ checkout. The current checkout is a simulation (no real payment), so
  /// paid plans are OFF: the Rovlo Plus page shows Plus / Advanced blurred with
  /// "Coming soon". Turn on only after integrating Google Play Billing /
  /// Razorpay / Stripe *and* setting the tier from a server webhook (the
  /// database already refuses client-side tier changes).
  static const bool paymentsEnabled = false;

  /// Terms & Conditions / Privacy links surfaced on the Welcome screen.
  static const String termsUrl = 'https://rovlo.app/terms';
  static const String privacyUrl = 'https://rovlo.app/privacy';

  // Gender options offered during profile setup.
  static const List<String> genderOptions = <String>[
    'Female',
    'Male',
    'Non-binary',
    'Prefer not to say',
  ];

  // Travel interests offered during profile setup.
  static const List<String> travelInterests = <String>[
    'Beaches',
    'Mountains',
    'City breaks',
    'Road trips',
    'Backpacking',
    'Luxury stays',
    'Food & wine',
    'Culture & history',
    'Adventure sports',
    'Wildlife & nature',
    'Nightlife',
    'Wellness & spa',
    'Solo travel',
    'Family friendly',
    'Photography',
  ];
}
