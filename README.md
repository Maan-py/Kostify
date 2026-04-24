# Kostify

Kostify adalah aplikasi Flutter untuk manajemen kos berbasis role (admin dan tenant), dengan penyimpanan lokal SQLite, integrasi API eksternal, dan fitur pembayaran online.

## Ringkasan Fitur

- Autentikasi login + biometric (local_auth, secure storage).
- Manajemen tenant (CRUD, aktivasi/nonaktif, detail profil, upload foto).
- OCR KTP untuk bantu input data tenant.
- Dashboard admin dan tenant.
- Pembayaran kos dengan Midtrans Snap (sandbox) + pengecekan status transaksi.
- Broadcast pengumuman admin ke tenant + inbox broadcast tenant.
- Notifikasi lokal untuk pengumuman.
- Emergency alert berbasis shake sensor + kirim alert ke Telegram.
- AI chat assistant (Google Gemini).
- Peta lokasi kos (Google Maps), tools kurs dan zona waktu.
- Mini game Flappy Bird (tap dan gyroscope).

## Struktur Folder

```text
lib/
|- main.dart
|- controllers/
|  |- auth_controller.dart
|  |- tenant_controller.dart
|- models/
|  |- broadcast_model.dart
|  |- emergency_log_model.dart
|  |- payment_model.dart
|  |- user_model.dart
|- services/
|  |- api_service.dart
|  |- connectivity_service.dart
|  |- database_helper.dart
|  |- notification_service.dart
|  |- sensor_service.dart
|- utils/
|  |- constants.dart
|  |- validators.dart
|- views/
|  |- admin/
|  |  |- add_tenant_screen.dart
|  |  |- admin_broadcast_screen.dart
|  |  |- admin_chat_screen.dart
|  |  |- admin_dashboard_screen.dart
|  |  |- ktp_camera_capture_screen.dart
|  |  |- tenant_detail_screen.dart
|  |  |- tenant_list_screen.dart
|  |- auth/
|  |  |- login_screen.dart
|  |- shared/
|  |  |- saran_kesan_screen.dart
|  |- tenant/
|     |- flappy_bird_screen.dart
|     |- tenant_broadcast_screen.dart
|     |- tenant_dashboard_screen.dart
|     |- tenant_map_screen.dart
|     |- tools_screen.dart
```

## Setup Aplikasi

### 1. Prasyarat

- Flutter SDK sesuai `pubspec.yaml` (Dart `>=3.0.0 <4.0.0`).
- Android Studio / Xcode (jika build iOS).
- Perangkat/emulator Android atau iOS.

### 2. Install dependency

```bash
flutter pub get
```

### 3. Setup file env

Project ini sudah menggunakan `flutter_dotenv` dan membaca kredensial dari file `.env`.

Langkah:

1. Salin file contoh:

```bash
copy .env.example .env
```

2. Lengkapi semua variabel berikut di `.env`:

```env
GOOGLE_MAPS_API_KEY=YOUR_GOOGLE_MAPS_KEY
GOOGLE_GEMINI_API_KEY=YOUR_GEMINI_KEY
EXCHANGE_RATE_API_KEY=YOUR_EXCHANGERATE_KEY
TELEGRAM_BOT_TOKEN=YOUR_TELEGRAM_BOT_TOKEN
TELEGRAM_CHAT_ID=YOUR_TELEGRAM_CHAT_ID
MIDTRANS_SERVER_KEY=YOUR_MIDTRANS_SERVER_KEY
MIDTRANS_CLIENT_KEY=YOUR_MIDTRANS_CLIENT_KEY
```

Catatan:

- `GOOGLE_MAPS_API_KEY` dan `GOOGLE_GEMINI_API_KEY` termasuk kredensial inti.
- `MIDTRANS_*` wajib jika ingin fitur pembayaran online aktif.
- `TELEGRAM_*` wajib jika ingin emergency alert terkirim ke Telegram.
- `.env` sudah masuk `.gitignore`, jangan commit kredensial asli.

### 4. Setup Google Maps

- Android: key diambil otomatis dari `.env` lewat `android/app/build.gradle` dan disuntikkan ke `AndroidManifest.xml` via manifest placeholder.
- iOS: key dibaca dari `.env` di `ios/Runner/AppDelegate.swift` lalu dipassing ke `GMSServices.provideAPIKey`.

### 5. Jalankan aplikasi

```bash
flutter run
```

Jika ingin build release Android:

```bash
flutter build apk --release
```

## Kredensial Default

Akun admin default:

- Username: `admin`
- Password: `admin123`

Password disimpan dalam bentuk SHA-256 hash di database lokal SQLite.

## Catatan Konfigurasi

- Info kos default (nama, alamat, koordinat) masih ada di `lib/utils/constants.dart`.
- API key tidak lagi di-hardcode dalam source, tetapi dibaca dari `.env`.
- Broadcast saat ini menggunakan SQLite lokal + local notification (bukan push notification server).

## Cara Ambil Credential API

- Google Gemini: https://aistudio.google.com/app/apikey
- Google Maps: aktifkan Maps SDK for Android/iOS di Google Cloud Console
- ExchangeRate API: https://www.exchangerate-api.com
- Telegram Bot Token: buat bot lewat `@BotFather` (`/newbot`)
- Telegram Chat ID: kirim pesan ke bot lalu cek `https://api.telegram.org/bot<TOKEN>/getUpdates`
- Midtrans Sandbox Keys: https://dashboard.sandbox.midtrans.com/settings/config
