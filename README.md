# Kostify - Smart Boarding Management System

Kostify adalah aplikasi Flutter untuk manajemen kos berbasis role (admin dan tenant), dengan penyimpanan lokal SQLite, integrasi API eksternal, dan fitur pembayaran online. Aplikasi ini dirancang untuk memudahkan pengelolaan data tenant, pembayaran, pengumuman, dan layanan kos secara terintegrasi.

---

## 📋 Ringkasan Fitur

### Fitur Autentikasi & Keamanan

- ✅ Login dengan username dan password
- ✅ Autentikasi biometrik (fingerprint/face ID) menggunakan `local_auth`
- ✅ Penyimpanan kredensial aman menggunakan `flutter_secure_storage`
- ✅ Enkripsi password menggunakan bcrypt

### Fitur Admin

- ✅ **Manajemen Tenant**: CRUD tenant, aktivasi/nonaktif akun, ubah detail profil
- ✅ **Upload Foto Tenant**: Kompresi gambar otomatis
- ✅ **OCR KTP**: Ekstraksi data dari kartu identitas menggunakan Google ML Kit
- ✅ **Dashboard Admin**: Ringkasan statistik tenant dan pembayaran
- ✅ **Broadcast Pengumuman**: Kirim pengumuman ke semua tenant dengan tracking penerimaan

### Fitur Tenant

- ✅ **Dashboard Tenant**: Lihat info kamar, sewa, dan status pembayaran
- ✅ **Inbox Broadcast**: Terima dan baca pengumuman dari admin
- ✅ **Notifikasi Lokal**: Push notification untuk pengumuman baru
- ✅ **Pembayaran Online**: Integrasi Midtrans Snap (sandbox mode)
  - Checkout pembayaran sewa kos
  - Pengecekan status transaksi
  - Riwayat pembayaran
- ✅ **Peta Lokasi Kos**: Tampilkan lokasi kos di peta
- ✅ **Tools Utility**:
  - Konverter mata uang real-time (ExchangeRate-API)
  - Penampil zona waktu berbagai negara
- ✅ **Fitur Mini Game**: Flappy Bird dengan kontrol tap dan gyroscope sensor
- ✅ **Change Password**: Ubah password akun

### Fitur Chat & Support

- ✅ **AI Chat Assistant**: Integrasi Google Gemini untuk Q&A
- ✅ **Admin Chat Interface**: Admin dapat berkomunikasi dengan tenant (preparatory)
- ✅ **Saran & Kesan**: Feedback dari tenant ke admin

### Fitur Emergency & Monitoring

- ✅ **Emergency Alert**: Deteksi shake sensor untuk trigger alert
- ✅ **Telegram Integration**: Kirim alert emergency ke Telegram
- ✅ **Emergency Logs**: Riwayat alert yang dikirim

### Fitur Umum

- ✅ **Offline Support**: Sync data ketika online
- ✅ **Connectivity Monitor**: Deteksi status koneksi internet
- ✅ **Multi-role Interface**: UI berbeda untuk admin dan tenant

---

## 🗺️ Maps Integration

Aplikasi menggunakan **flutter_map** dengan OpenStreetMap (bukan Google Maps) untuk fitur peta lokasi kos.

| Aspek             | Detail                                          |
| ----------------- | ----------------------------------------------- |
| **Library**       | `flutter_map: ^8.3.0`                           |
| **Tile Provider** | OpenStreetMap (OSM)                             |
| **Geocoding**     | `geocoding: ^3.0.0` & `latlong2: ^0.9.0`        |
| **GPS Tracking**  | `geolocator: ^12.0.0`                           |
| **Fitur**         | Tampilkan lokasi kos, marker custom, zoom & pan |

**Keuntungan OpenStreetMap**:

- Tidak perlu API key Google Maps yang berbayar
- Open source dan community-driven
- Cukup akurat untuk kebutuhan lokasi lokal

---

## 📁 Struktur Folder

```
kostify_full/
├── lib/
│   ├── main.dart                    # Entry point aplikasi
│   ├── controllers/                 # State management
│   │   ├── auth_controller.dart      # Autentikasi & login
│   │   └── tenant_controller.dart    # Manajemen data tenant
│   ├── models/                      # Data models
│   │   ├── broadcast_model.dart      # Model pesan broadcast
│   │   ├── emergency_log_model.dart  # Model alert emergency
│   │   ├── payment_model.dart        # Model pembayaran
│   │   └── user_model.dart           # Model user/tenant
│   ├── services/                    # Business logic & API
│   │   ├── api_service.dart          # HTTP client & API calls
│   │   ├── chat_context_service.dart # Context management untuk chat
│   │   ├── connectivity_service.dart # Monitor koneksi internet
│   │   ├── database_helper.dart      # SQLite operations
│   │   ├── notification_service.dart # Push notifications lokal
│   │   └── sensor_service.dart       # Shake sensor untuk emergency
│   ├── utils/                       # Utilities & constants
│   │   ├── constants.dart            # API keys, hardcoded values
│   │   └── validators.dart           # Input validation
│   ├── views/                       # UI Screens
│   │   ├── admin/                    # Admin screens
│   │   │   ├── add_tenant_screen.dart
│   │   │   ├── admin_broadcast_screen.dart
│   │   │   ├── admin_chat_screen.dart
│   │   │   ├── admin_dashboard_screen.dart
│   │   │   ├── ktp_camera_capture_screen.dart
│   │   │   ├── tenant_detail_screen.dart
│   │   │   └── tenant_list_screen.dart
│   │   ├── auth/                     # Authentication screens
│   │   │   └── login_screen.dart
│   │   ├── shared/                   # Shared screens
│   │   │   └── saran_kesan_screen.dart
│   │   └── tenant/                   # Tenant screens
│   │       ├── change_password_screen.dart
│   │       ├── flappy_bird_screen.dart
│   │       ├── tenant_broadcast_screen.dart
│   │       ├── tenant_dashboard_screen.dart
│   │       ├── tenant_map_screen.dart
│   │       └── tools_screen.dart
│   └── widgets/                     # Reusable UI components (jika ada)
├── assets/                          # Static assets
│   ├── fonts/                        # Font files (Poppins)
│   ├── icons/                        # Icon assets
│   └── images/                       # Image assets
├── android/                         # Android native code
├── ios/                             # iOS native code
├── pubspec.yaml                     # Dependencies & configuration
├── analysis_options.yaml            # Linter rules
├── .env                             # Environment variables (jangan commit!)
├── .env.example                     # Template environment variables
└── README.md                        # File ini
```

---

## 🚀 Setup & Instalasi

### 1. Prasyarat

- **Flutter SDK**: Versi 3.0.0 atau lebih tinggi
- **Dart**: Versi 3.0.0 atau lebih tinggi
- **Android Studio** atau **Xcode** untuk build native code
- **Emulator Android** / **iPhone Simulator** atau device fisik
- **Git** (untuk version control)

Verifikasi instalasi:

```bash
flutter --version
dart --version
```

### 2. Clone Repository

```bash
git clone <repository-url>
cd kostify_full
```

### 3. Instal Dependencies

```bash
flutter pub get
```

### 4. Setup Environment Variables (.env)

Project menggunakan `flutter_dotenv` untuk manajemen kredensial. Langkah-langkah:

#### a. Buat file `.env` di root project

```bash
copy .env.example .env
```

atau manual:

```bash
# Windows
copy NUL .env

# Linux/Mac
touch .env
```

#### b. Isi variabel-variabel berikut di `.env`:

```env
# Google Maps API (tidak wajib jika pakai OpenStreetMap)
GOOGLE_MAPS_API_KEY=YOUR_GOOGLE_MAPS_KEY

# Google Gemini API (untuk AI chat assistant)
GOOGLE_GEMINI_API_KEY=YOUR_GEMINI_API_KEY

# Exchange Rate API (untuk konverter mata uang)
EXCHANGE_RATE_API_KEY=YOUR_EXCHANGERATE_API_KEY

# Telegram (untuk emergency alert)
TELEGRAM_BOT_TOKEN=YOUR_TELEGRAM_BOT_TOKEN
TELEGRAM_CHAT_ID=YOUR_TELEGRAM_CHAT_ID

# Midtrans Payment Gateway (sandbox mode)
MIDTRANS_SERVER_KEY=YOUR_MIDTRANS_SERVER_KEY
MIDTRANS_CLIENT_KEY=YOUR_MIDTRANS_CLIENT_KEY

# Admin Bootstrap Password (opsional, default: admin123)
ADMIN_BOOTSTRAP_PASSWORD=your_secure_password
```

#### c. Dapatkan API Keys

| Service       | URL                                                         | Catatan                      |
| ------------- | ----------------------------------------------------------- | ---------------------------- |
| Google Gemini | [AI Studio](https://aistudio.google.com/app/apikey)         | Gratis dengan Google account |
| Exchange Rate | [exchangerate-api.com](https://www.exchangerate-api.com)    | Gratis untuk 1,500 req/bulan |
| Telegram Bot  | [BotFather](https://t.me/botfather) di Telegram             | Kirim `/newbot` ke BotFather |
| Midtrans      | [Sandbox Dashboard](https://dashboard.sandbox.midtrans.com) | Akun sandbox gratis          |

### 5. Build & Run

#### Run di emulator/device Android:

```bash
flutter run
```

#### Run di iOS:

```bash
cd ios
pod install
cd ..
flutter run -d <ios-device-id>
```

#### Build APK (Android):

```bash
flutter build apk --release
```

#### Build AAB (Play Store):

```bash
flutter build appbundle --release
```

---

## 🔐 Kredensial Default

Saat pertama kali menjalankan aplikasi, database diinisialisasi dengan akun admin default:

| Field        | Value                                                     |
| ------------ | --------------------------------------------------------- |
| **Username** | `admin`                                                   |
| **Password** | `admin123` |
| **Role**     | `admin`                                                   |
| **Status**   | Aktif                                                     |

⚠️ **PENTING**: Ubah password admin segera setelah pertama login untuk keamanan!

---

## 🔑 Kos Information (Hardcoded)

Berikut informasi kos yang saat ini di-hardcode dalam `lib/utils/constants.dart`:

```dart
static const String KOS_NAME = 'Kos Bela Negara';
static const String KOS_ADDRESS = 'Jl. Babarsari No. 2, Tambakbayan, ...';
static const double KOS_LATITUDE = -7.782289529024553;
static const double KOS_LONGITUDE = 110.41590797374627;
```

📝 _Catatan: Informasi ini bisa diubah ke database/admin panel di release mendatang._

---

## 📝 License

Proyek ini adalah tugas kuliah semester 6. Silakan gunakan untuk keperluan akademik.

---

## 👨‍💻 Developer Notes

- Dokumentasi API eksternal bisa dilihat di service files
- Untuk develop, gunakan `flutter run --dart-define` untuk override env vars
- Database schema bisa diupgrade di `_onUpgrade()` method
- Unit tests belum diimplementasi (TODO)

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
