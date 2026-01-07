# Building Android Test APKs

## Option 1: Using Android Studio (Recommended)

1. **Open the project:**
   - Android Studio should have opened the `AndroidTestHost` folder
   - Wait for Gradle sync to complete

2. **Build the APKs:**
   - Open the Terminal in Android Studio (View → Tool Windows → Terminal)
   - Run: `./gradlew assembleDebug assembleDebugAndroidTest`

   OR

   - Build → Make Project (Cmd+F9)
   - Then in Terminal: `./gradlew assembleDebugAndroidTest`

3. **Find the built APKs:**
   - `app/build/outputs/apk/debug/app-debug.apk`
   - `app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk`

4. **Copy APKs to Xamrock Studio bundle:**
   ```bash
   mkdir -p "/Users/kiloloco/Library/Developer/Xcode/DerivedData/Studio-dgcncnmufbhmpxfrqnyqamtlrojx/Build/Products/Debug/Xamrock Studio.app/Contents/Resources/AndroidTestHost"

   cp app/build/outputs/apk/debug/app-debug.apk "/Users/kiloloco/Library/Developer/Xcode/DerivedData/Studio-dgcncnmufbhmpxfrqnyqamtlrojx/Build/Products/Debug/Xamrock Studio.app/Contents/Resources/AndroidTestHost/"

   cp app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk "/Users/kiloloco/Library/Developer/Xcode/DerivedData/Studio-dgcncnmufbhmpxfrqnyqamtlrojx/Build/Products/Debug/Xamrock Studio.app/Contents/Resources/AndroidTestHost/"
   ```

## Option 2: Using Homebrew Gradle

If Android Studio doesn't work:

```bash
# Install Gradle
brew install gradle

# Build APKs
cd AndroidTestHost
gradle assembleDebug assembleDebugAndroidTest

# Copy APKs (same as above)
```

## Verification

After copying, check that the APKs exist:
```bash
ls -la "/Users/kiloloco/Library/Developer/Xcode/DerivedData/Studio-dgcncnmufbhmpxfrqnyqamtlrojx/Build/Products/Debug/Xamrock Studio.app/Contents/Resources/AndroidTestHost/"
```

You should see:
- `app-debug.apk` (~2-5 MB)
- `app-debug-androidTest.apk` (~2-5 MB)

Now restart Xamrock Studio and try recording on Android!
