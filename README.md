# Rovlo 🌍

A beautifully animated Flutter travel app — video-backed welcome screen,
phone + Google/Apple onboarding, a full profile-setup flow, a constant
themeable design system with dark/light mode, and an admin panel for managing
users.

> Built to match the flow in the Rovlo Stitch design. The exact Stitch mockups
> are behind Google auth and couldn't be read directly, so screens follow the
> written spec with a cohesive travel-app visual language you can fine-tune
> against the Stitch frames.

---

## ✨ What's inside

| Area | Details |
|------|---------|
| **Welcome** | Looping background video (`assets/videos/welcome.mp4`) with an animated-gradient fallback, centred **Rovlo** wordmark, **Create Account** + **Sign In**, and Terms & Conditions. |
| **Create Account** | Phone number → OTP verify → Google/Apple → **Name** → **Gender** → **Travel preferences** → Home. |
| **Sign In** | Straight to the Google/Apple authentication screen → Home. |
| **Theme** | One constant design system (`lib/core/theme`) with **dark / light / system** modes, chosen in **Settings** and persisted. |
| **Home** | Explore feed (search + category chips + destination cards), Saved, and Profile tabs. |
| **Admin panel** | User roster, live stats, search, block/unblock, delete, and JSON export — restricted by admin email. |
| **Animations** | Custom page transitions, `flutter_animate` entrances, animated gradient background, and micro-interactions throughout. |
| **Platform** | iOS-first friendly (Cupertino-safe widgets, portrait lock, Apple sign-in button on Apple platforms) and Android-ready. |

---

## 🚀 Getting started

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(3.19+) installed.

```bash
# 1. Generate the native platform folders (android/ ios/ web/ …).
#    This does NOT touch lib/ or pubspec.yaml.
flutter create .

# 2. Fetch packages
flutter pub get

# 3. Run it
flutter run            # add -d ios / -d android / -d chrome to pick a device
```

That's it — the app runs immediately in **demo mode** with no backend.

### Demo-mode shortcuts
- **OTP code:** `123456`
- **Google / Apple:** simulated sign-in that returns a realistic account.
- Users, sessions and theme choice persist locally via `shared_preferences`.

---

## 👑 Admin access

Admin rights are controlled in **one place** —
`lib/core/constants/app_constants.dart`:

```dart
static const List<String> adminEmails = <String>[
  'hellorovlo2026@gmail.com',   // ← change / add admin emails here
];
```

Any account whose email matches gets an **Admin panel** entry under
**Profile → Admin**. Because demo Google/Apple sign-in returns a random email,
the easiest way to test the panel is to point one of your local accounts at an
admin email (or temporarily add that random email to the list).

> Tell me the exact admin email you want and I'll set it as the default.

---

## 🎬 Background video

Place a looping, muted, portrait `welcome.mp4` in `assets/videos/`
(see `assets/videos/README.md`). Without it, the animated gradient background
is used automatically.

---

## 🔌 Connecting real authentication (Firebase)

The app talks to a single `AuthService` (`lib/services/auth_service.dart`),
so wiring real auth is isolated:

1. Add `firebase_core`, `firebase_auth`, `google_sign_in`,
   `sign_in_with_apple` to `pubspec.yaml`.
2. Run `flutterfire configure` and uncomment the `Firebase.initializeApp(...)`
   call in `lib/main.dart`.
3. Replace the bodies of `signInWithGoogle`, `signInWithApple`,
   `requestPhoneOtp` and `verifyPhoneOtp` with the real SDK calls — the
   signatures already match, so nothing else in the app changes.
4. Swap `UserRepository` (`lib/services/user_repository.dart`) from
   `shared_preferences` to Firestore for a shared, admin-visible user list.

### iOS notes
- Apple sign-in: enable the **Sign in with Apple** capability in Xcode.
- Add camera/notification usage strings to `ios/Runner/Info.plist` only if you
  add those features. Video playback needs no special permission.

---

## 🗂 Project structure

```
lib/
├── main.dart                 # entry — providers + bootstrap
├── app.dart                  # MaterialApp, theme wiring, routing
├── core/
│   ├── constants/            # app constants + ADMIN EMAILS
│   ├── routing/              # named routes + shared page transition
│   ├── theme/                # colours, ThemeData, ThemeProvider
│   └── widgets/              # reusable UI (video bg, gradient bg, buttons…)
├── models/                   # AppUser, Destination
├── services/                 # AuthService, UserRepository
├── providers/                # AuthProvider (session + onboarding state)
└── features/
    ├── welcome/              # Welcome screen
    ├── auth/                 # phone, social, name, gender, travel steps
    ├── home/                 # explore / saved / profile tabs
    ├── settings/             # dark/light appearance
    └── admin/                # admin panel
```

---

## 🧪 Tests

```bash
flutter test
```

A smoke test verifies the Welcome screen renders its wordmark and CTAs.
