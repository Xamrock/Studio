# Xamrock Studio

A macOS application for recording iOS app interactions and generating automated test code for XCUITest, Maestro, and Appium.

## Installation

### Option 1: Download Pre-built Release (Recommended)

1. Download the latest `Xamrock Studio.app.zip` from [Releases](https://github.com/YOUR_USERNAME/Studio/releases)
2. Unzip the downloaded file
3. Move `Xamrock Studio.app` to your Applications folder
4. Right-click the app and select "Open" to bypass Gatekeeper (first launch only)

> **Note**: Pre-built releases include the test runner already bundled. No additional setup required.

### Option 2: Build from Source

#### Prerequisites
- macOS 14.6 or later
- Xcode 16.0 or later
- Command Line Tools installed

#### Build Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/Studio.git
   cd Studio
   ```

2. **Open and build the project**
   ```bash
   open Studio.xcodeproj
   ```
   - Select the `Studio` scheme
   - Build the project (⌘B)
   - Archive the app (Product > Archive)
   - Export the app to your Desktop

3. **Bundle the test runner**
   ```bash
   ./Scripts/bundle-test-runner.sh ~/Desktop/Xamrock\ Studio.app
   ```

   This will:
   - Build test artifacts for both iOS Simulator and iOS Device
   - Bundle them into the app's Resources directory
   - Patch configuration files for standalone distribution

4. **Launch the app**
   ```bash
   open ~/Desktop/Xamrock\ Studio.app
   ```

## First Launch

On first launch, Xamrock Studio will:
1. Request permissions (if needed)
2. Load available iOS devices and simulators
3. Be ready to start recording

## Requirements

- **Development**: Requires Xcode and iOS Simulators
- **Physical Devices**: Requires device to be connected and trusted
- **Target Apps**: Can record any iOS app by bundle ID

## Creating a Release

For maintainers creating GitHub releases with bundled test runner:

```bash
# 1. Archive the app in Xcode
# 2. Export to ~/Desktop/Xamrock Studio.app
# 3. Bundle the test runner
./Scripts/bundle-test-runner.sh ~/Desktop/Xamrock\ Studio.app

# 4. Zip for distribution
cd ~/Desktop
zip -r "Xamrock Studio.app.zip" "Xamrock Studio.app"

# 5. Upload to GitHub Releases
```

## Troubleshooting

**"Xamrock Studio.app is damaged and can't be opened"**
- This is a Gatekeeper warning. Right-click the app and select "Open"
- Or remove the quarantine attribute:
  ```bash
  xattr -cr /Applications/Xamrock\ Studio.app
  ```

**Test runner fails to start**
- Ensure Xcode Command Line Tools are installed:
  ```bash
  xcode-select --install
  ```
- Verify simulator exists:
  ```bash
  xcrun simctl list devices
  ```

**Physical device not detected**
- Ensure device is unlocked and trusted
- Check that the device appears in:
  ```bash
  xcrun xctrace list devices
  ```

## License

[Your License Here]
