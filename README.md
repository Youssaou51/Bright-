# Bright Future Foundation Flutter App

This project is a mobile and web application for the **Bright Future Foundation (BFF)** built with Flutter. It uses Supabase for authentication and data storage. Users can post updates, comment, manage tasks and view the foundation fund through the dashboard.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.7 or later)
- A Supabase account with project credentials
- Optional environment variables `SUPABASE_URL` and `SUPABASE_ANON_KEY` to provide your Supabase details

## Getting Started

Fetch the dependencies:

```bash
flutter pub get
```

### Running the app

Run on Android:

```bash
flutter run -d android
```

Run on iOS (requires macOS):

```bash
flutter run -d ios
```

Run on the web (Chrome):

```bash
flutter run -d chrome
```

## Environment Variables

The app expects Supabase credentials. You can set them as environment variables or edit the values in `lib/main.dart`:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

The initialization currently resides in `lib/main.dart`:

```dart
await Supabase.initialize(
  url: 'https://lupyveilvgzkolbeimlg.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx1cHl2ZWlsdmd6a29sYmVpbWxnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MjQ3OTc2MiwiZXhwIjoyMDU4MDU1NzYyfQ.v581oYh0hMCO7daGEZW_pcAgq32vpT3vQ5U445A0nek',
);
```

Replace these values with your own credentials or configure the environment variables accordingly.
