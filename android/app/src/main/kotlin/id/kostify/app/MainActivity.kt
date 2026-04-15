package id.kostify.app

import io.flutter.embedding.android.FlutterFragmentActivity

// Menggunakan FlutterFragmentActivity (bukan FlutterActivity)
// supaya local_auth (biometric) bisa bekerja dengan benar di Android
class MainActivity : FlutterFragmentActivity()
