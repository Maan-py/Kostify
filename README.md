# 🏠 Kostify — Smart Boarding Management System

Flutter app untuk manajemen kos berbasis MVC. Dikembangkan untuk mata kuliah TPM.

---

## 📁 Struktur Folder

```
lib/
├── main.dart                    # Entry point, routes, splash screen
├── controllers/
│   └── auth_controller.dart     # Login, biometric, session
├── models/
│   ├── user_model.dart
│   ├── payment_model.dart
│   └── emergency_log_model.dart
├── services/
│   ├── database_helper.dart     # SQLite CRUD
│   ├── api_service.dart         # Gemini, Telegram, ExchangeRate
│   └── sensor_service.dart      # Accelerometer & Gyroscope
├── utils/
│   ├── constants.dart           # API keys, warna, konfigurasi
│   └── validators.dart          # Input validation & sanitasi
└── views/
    ├── auth/
    │   └── login_screen.dart
    ├── admin/
    │   ├── admin_dashboard_screen.dart
    │   ├── tenant_list_screen.dart
    │   ├── add_tenant_screen.dart
    │   └── admin_chat_screen.dart
    ├── tenant/
    │   ├── tenant_dashboard_screen.dart
    │   ├── tools_screen.dart
    │   ├── tenant_map_screen.dart
    │   └── flappy_bird_screen.dart
    └── shared/
        └── saran_kesan_screen.dart
```

---

## ⚙️ Setup Sebelum Jalankan

### 1. Isi API Keys di `lib/utils/constants.dart`

```dart
static const String GEMINI_API_KEY = 'ISI_API_KEY_GEMINI_KAMU';
static const String EXCHANGE_RATE_API_KEY = 'ISI_API_KEY_EXCHANGERATE';
static const String TELEGRAM_BOT_TOKEN = 'ISI_TOKEN_BOT_TELEGRAM';
static const String TELEGRAM_CHAT_ID = 'ISI_CHAT_ID_ADMIN';
static const String GOOGLE_MAPS_API_KEY = 'ISI_API_KEY_GOOGLE_MAPS';
```

Cara dapat API key:
- **Gemini**: https://aistudio.google.com/app/apikey
- **ExchangeRate**: https://exchangerate-api.com (gratis 1500 req/bulan)
- **Telegram Bot**: Chat @BotFather di Telegram → /newbot
- **Google Maps**: https://console.cloud.google.com → Enable Maps SDK for Android/iOS

### 2. Setup Google Maps API Key

**Android** — `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="ISI_API_KEY_GOOGLE_MAPS"/>
```

**iOS** — `ios/Runner/AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("ISI_API_KEY_GOOGLE_MAPS")
```

### 3. Sesuaikan Info Kos

Di `lib/utils/constants.dart`, ubah:
```dart
static const String KOS_NAME = 'Nama Kos Kamu';
static const String KOS_ADDRESS = 'Alamat Kos Lengkap';
static const double KOS_LATITUDE = -7.005145; // koordinat kos
static const double KOS_LONGITUDE = 110.438125;
```

### 4. Sesuaikan Saran & Kesan

Di `lib/views/shared/saran_kesan_screen.dart`:
```dart
static const _dosen = 'Nama Dosen Pengampu TPM';
```

### 5. Font Poppins

Unduh font Poppins dari https://fonts.google.com/specimen/Poppins
Simpan di `assets/fonts/`:
- `Poppins-Regular.ttf`
- `Poppins-Medium.ttf`
- `Poppins-SemiBold.ttf`
- `Poppins-Bold.ttf`

### 6. Install Dependencies

```bash
flutter pub get
```

### 7. Android Permissions

Di `android/app/src/main/AndroidManifest.xml`, tambahkan:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-permission android:name="android.permission.USE_FINGERPRINT"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.HIGH_SAMPLING_RATE_SENSORS"/>
```

### 8. Android minSdkVersion

Di `android/app/build.gradle`:
```gradle
minSdkVersion 23  // Wajib untuk biometric & local_auth
```

---

## 🔐 Akun Default

| Role  | Username | Password  |
|-------|----------|-----------|
| Admin | `admin`  | `admin123` |

> Password admin tersimpan dalam bentuk SHA-256 hash di database.

---

## 📱 Fitur Lengkap

| Fitur | Status | Keterangan |
|-------|--------|-----------|
| Login + Biometric | ✅ | SHA-256 + Secure Storage session |
| OCR KTP | ✅ | Google ML Kit, auto-fill form |
| Manajemen Penghuni | ✅ | CRUD, filter, search, toggle status |
| Nomor Kamar | ✅ | Hanya admin yang bisa ubah |
| Dashboard Statistik | ✅ | Pendapatan, kamar terisi/kosong |
| AI Chat (Gemini) | ✅ | Admin & tenant, konteks kos |
| Emergency Shake | ✅ | Accelerometer, cooldown 5 detik |
| Telegram Notif | ✅ | Bot API, simpan log offline |
| Peta Lokasi Kos | ✅ | Google Maps + navigasi |
| Konversi Mata Uang | ✅ | 6 mata uang, ExchangeRate API |
| Konversi Waktu | ✅ | WIB, WITA, WIT, London |
| Flappy Bird | ✅ | Dual mode: tap + gyroscope |
| Foto Profil | ✅ | Upload dari kamera/galeri, compress |
| Saran & Kesan TPM | ✅ | Form textarea, validasi lengkap |
| Error Handling | ✅ | Anti SQL injection, paste anomali |

---

## 🧪 Test Anomali (Dosen)

Semua TextField sudah dilindungi:
- **Max panjang**: tiap field ada batas karakter (paste artikel → otomatis dipotong)
- **SQL Injection**: pattern `'`, `--`, `;`, `UNION`, `SELECT` dll diblokir
- **XSS**: HTML tags & script difilter
- **Spasi pada username**: diblokir lewat `FilteringTextInputFormatter`
- **Digit only**: NIK & harga sewa hanya terima angka

---

## 📞 Cara Test Telegram Bot

1. Buat bot baru via @BotFather: `/newbot`
2. Catat token bot
3. Kirim pesan ke bot kamu (supaya chat ID bisa dibaca)
4. Buka: `https://api.telegram.org/bot{TOKEN}/getUpdates`
5. Ambil nilai `chat.id` dari response
6. Isi `TELEGRAM_CHAT_ID` dengan nilai tersebut
