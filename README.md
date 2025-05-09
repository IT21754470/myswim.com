# myswim.com

# Swimming App

A Flutter application for swimming enthusiasts.

## Prerequisites

Before you begin, ensure you have the following installed:

Flutter 3.29.3 • channel stable • https://github.com/flutter/flutter.git
Framework • revision ea121f8859 (4 weeks ago) • 2025-04-11 19:10:07 +0000
Engine • revision cf56914b32
Tools • Dart 3.7.2 • DevTools 2.42.3
## Getting Started

Follow these steps to get the project running on your local machine:

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/swimming_app.git
cd swimming_app
```

# 2. Install Flutter Dependencies
flutter pub get

3. Set Up Android Development Environment
Install Android SDK Components

Open Android Studio
Go to Tools > SDK Manager
Select the "SDK Tools" tab
Check the following items:

Android SDK Build-Tools
Android SDK Command-line Tools
Android Emulator
Android SDK Platform-Tools
NDK (Side by side) - IMPORTANT!
CMake


Click "Apply" and wait for installation to complete

Accept Android Licenses
bashflutter doctor --android-licenses
Accept all the licenses when prompted.
4. Fix Gradle Files (If Needed)
If you encounter errors related to build.gradle.kts, make sure to:

In android/app/build.gradle.kts - If you need to specify NDK version, use:
kotlinndkVersion = "25.1.8937393"  // Note the equals sign which is required in Kotlin DSL

In android/build.gradle.kts - Make sure there's only one subprojects block:
kotlinsubprojects {
    // All subproject configurations here
}


# 5. Run the Application
Connect your Android device via USB (with USB debugging enabled) or start an emulator, then:
bashflutter run
Common Issues and Solutions
"NDK did not have a source.properties file" Error
If you see this error:
[CXX1101] NDK at C:\...\Android\Sdk\ndk\... did not have a source.properties file
Solution:

Open Android Studio > SDK Manager > SDK Tools tab
Check "NDK (Side by side)" and "CMake"
Click "Apply" and wait for installation to complete
Run flutter clean followed by flutter run

Syntax Error in build.gradle.kts
If you see errors about unexpected tokens in the Gradle files:
Solution:
Kotlin DSL requires assignments with equals signs:

Change ndkVersion "25.1.8937393" to ndkVersion = "25.1.8937393"

Device Not Authorized
If your device shows as "unauthorized" when connected:
Solution:

Disconnect your device
Go to Settings > Developer options
Revoke USB debugging authorizations
Reconnect your device
Accept the debugging authorization prompt on your device

Project Structure

lib/ - Contains all Dart code for the application
android/ - Android-specific configuration files
ios/ - iOS-specific configuration files (if applicable)
assets/ - Contains images, fonts, and other static files

Contributing
Please read CONTRIBUTING.md for details on our code of conduct and the process for submitting pull requests.
License
This project is licensed under the MIT License - see the LICENSE.md file for details

Feel free to customize the instructions based on your specific project details, and make sure to:

1. Replace `YOUR_USERNAME` with your actual GitHub username
2. Add any additional project-specific instructions
3. Include any screenshots or additional information that might help others setup the project

This README covers all the issues you encountered and should help your friends avoid the same setup problems.










