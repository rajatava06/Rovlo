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

Admins are stored in the database, not in the app: add an email to the
`admin_emails` table (and to `support_agents` for the support inbox) — see
`Rovlo-Backend/SUPABASE_SETUP.md`. Anyone who signs in with that Google account
gets **Profile → Admin Panel**. No app update is needed.

## ⚙️ Configuration

Two git-ignored files hold your values (nothing secret is in the source):

1. `assets/config/app_config.json` — copy `app_config.example.json` and fill in
   the Supabase URL + publishable key, Google Web client id and (optional)
   MapTiler key. It is bundled into the app, so plain `flutter run` and release
   builds work.
2. `.env` — copy `.env.example`; only needed for the Firebase push values, or
   to override the above via `--dart-define-from-file=.env`.
