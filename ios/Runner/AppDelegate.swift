import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        var apiKey = "MISSING_API_KEY"
        if let envPath = Bundle.main.path(forResource: "flutter_assets/.env", ofType: nil) {
            do {
                let envData = try String(contentsOfFile: envPath)
                let envLines = envData.split(whereSeparator: \.isNewline)
                for line in envLines {
                    let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
                    if parts.count == 2, parts[0] == "GOOGLE_MAPS_API_KEY" {
                        apiKey = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            } catch {}
        }
        GMSServices.provideAPIKey(apiKey)
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}

