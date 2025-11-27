# P3 Mulo GPS Tracker

This Flutter application is a GPS tracking client designed to send location data to the Mulo backend service. It supports web, Android, and iOS platforms, with a complete authentication and location tracking flow.

## Prerequisites
Before you begin, ensure you have the following installed:
- [Flutter SDK](httpss://flutter.dev/docs/get-started/install)
- [Android Studio](httpss://developer.android.com/studio) (for Android development)
- [Xcode](httpss://developer.apple.com/xcode/) (for iOS development on macOS)
- An IDE such as [Visual Studio Code](httpss://code.visualstudio.com/) with the Flutter extension.

## Project Setup

1.  **Install dependencies:**
```bash
    flutter pub get
```

2.  **Configure Local Development Environment:**
    This project uses a local configuration file to manage the IP address of your backend server during development. This allows each developer to use their own local IP without creating version control conflicts.

    - In the `lib/config/` directory, locate the `dev_config.dart.example` file.
    - **Copy/Paste** this file and name it `dev_config.dart`.
    - **Open** `dev_config.dart` and replace the placeholder IP address with your computer's local network IP.

    The `dev_config.dart` file is listed in `.gitignore` and will not be committed.

## Running the Application
Make sure your MuloApp backend server is running before launching the app.

### Running on Web (Chrome)
For web development, the app will connect to `localhost:8080`.
The --web-port flag ensures a consistent origin for CORS
```bash
flutter run -d chrome --web-port 1918
```

### Running on Android
**Android Emulator:**
- Launch an Android emulator from Android Studio.
- In `lib/config/environment.dart`, ensure the Android configuration is set to use the emulator's special loopback address.
  ```dart
  // In lib/config/environment.dart
  // ...
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    // Use this for the standard Android emulator
    return 'http://10.0.2.2:8080';
  }
  // ...
  ```
- Run the app:
```bash
    flutter run -d <emulator-id> --web-port 1918
```

**Physical Android Device:**
- Connect your Android device to your computer via USB and enable developer mode and USB debugging.
- Ensure your phone and computer are on the **same Wi-Fi network**.
- Make sure your `lib/config/dev_config.dart` file is correctly set up with your computer's IP address.
- Run the app, selecting your device by its ID:
```bash
    flutter run -d <your-device-id> --web-port 1918
```

### Running on iOS (macOS only)

**iOS Simulator:**
- Open the simulator from Xcode: `open -a Simulator`
- The app will connect to `localhost:8080` from the simulator.
- Run the app:
```bash
    flutter run -d <simulator-id> --web-port 1918
```

**Physical iOS Device:**
- Connect your iPhone to your Mac via USB.
- Ensure your phone and computer are on the **same Wi-Fi network**.
- Make sure your `lib/config/dev_config.dart` file is correctly set up with your computer's IP address.
- Run the app:
```bash
    flutter run -d <your-device-id> --web-port 1918
```

## Building for Production
When you are ready to deploy, you can create a release build. In release mode, the app will automatically connect to the production backend URL (`https://www.mulo.dk`).

**Build an Android App Bundle (AAB):**
```bash
    flutter build appbundle
```

**Build an iOS App (IPA):**
```bash
    flutter build ipa
```

**Build for Web:**
```bash
    flutter build web
```
The output will be in the `build/` directory.



## Author

Magnus Zimmer <magnuszimmer11@gmail.com>