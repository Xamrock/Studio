#!/bin/bash

set -e

# Usage: ./package-release.sh [version]
# Example: ./package-release.sh 1.0.0
#
# Environment variables for code signing (optional):
#   SIGNING_IDENTITY - Developer ID Application certificate name
#   APPLE_ID - Apple ID for notarization
#   APPLE_ID_PASSWORD - App-specific password for notarization
#   APPLE_TEAM_ID - Team ID for notarization

VERSION=${1:-"1.0.0"}
CONFIGURATION="Release"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/Build"
APP_NAME="Xamrock Studio.app"
ARCHIVE_PATH="${BUILD_DIR}/Studio.xcarchive"
APP_PATH="${BUILD_DIR}/${APP_NAME}"
DIST_DIR="${BUILD_DIR}/Distribution"

# Determine if this is a signed release
if [ -n "$SIGNING_IDENTITY" ]; then
    ZIP_NAME="Xamrock-Studio-${VERSION}-Signed.zip"
    IS_SIGNED=true
else
    ZIP_NAME="Xamrock-Studio-${VERSION}.zip"
    IS_SIGNED=false
fi

echo "=========================================="
echo "Packaging Xamrock Studio v${VERSION}"
if [ "$IS_SIGNED" = true ]; then
    echo "Build type: Signed (Developer ID)"
    echo "Identity: $SIGNING_IDENTITY"
else
    echo "Build type: Unsigned (ad-hoc signing)"
fi
echo "=========================================="
echo ""

# Clean previous builds
echo "Cleaning previous build artifacts..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Step 1: Build Studio.app for macOS (arm64 only)
echo ""
echo "Step 1/5: Building Studio for macOS (arm64)..."
xcodebuild archive \
    -project "${PROJECT_DIR}/Studio.xcodeproj" \
    -scheme Studio \
    -configuration "${CONFIGURATION}" \
    -archivePath "${ARCHIVE_PATH}" \
    -derivedDataPath "${BUILD_DIR}" \
    -arch arm64 \
    SKIP_INSTALL=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Step 2: Export the app bundle
echo ""
echo "Step 2/5: Exporting app bundle..."
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${BUILD_DIR}" \
    -exportOptionsPlist "${SCRIPT_DIR}/ExportOptions.plist"

# Step 3: Build Android test host APKs
echo ""
echo "Step 3/6: Building Android test host..."
if "${SCRIPT_DIR}/build-android-test-host.sh"; then
    echo "✅ Android test host built successfully"

    # Bundle Android APKs into app
    ANDROID_RESOURCES_DIR="${PROJECT_DIR}/Studio/Resources/AndroidTestHost"
    ANDROID_BUNDLE_DIR="${APP_PATH}/Contents/Resources/AndroidTestHost"

    if [ -d "$ANDROID_RESOURCES_DIR" ]; then
        echo "Bundling Android test host APKs..."
        mkdir -p "${ANDROID_BUNDLE_DIR}"
        cp -R "${ANDROID_RESOURCES_DIR}/"* "${ANDROID_BUNDLE_DIR}/"
        echo "✅ Android APKs bundled"
    else
        echo "⚠️  Warning: Android resources not found, skipping Android bundle"
    fi
else
    echo "⚠️  Warning: Android test host build failed, continuing without Android support"
fi

# Step 4: Bundle iOS test runners
echo ""
echo "Step 4/6: Bundling iOS test runners..."
"${SCRIPT_DIR}/bundle-test-runner.sh" "${APP_PATH}"

# Step 5: Re-sign the app after adding test runners
echo ""
echo "Step 5/6: Re-signing app bundle..."
if [ "$IS_SIGNED" = true ]; then
    echo "Signing with Developer ID: $SIGNING_IDENTITY"
    # Sign with hardened runtime and timestamp for notarization
    codesign --force \
        --sign "$SIGNING_IDENTITY" \
        --deep \
        --options runtime \
        --timestamp \
        "${APP_PATH}"

    # Verify the signature
    echo "Verifying signature..."
    codesign --verify --verbose=2 "${APP_PATH}"
    spctl --assess --verbose=2 "${APP_PATH}"
else
    echo "Using ad-hoc signing (unsigned for distribution)"
    codesign --force --sign "-" --deep "${APP_PATH}"
fi

# Step 6: Prepare distribution directory
echo ""
echo "Step 6/6: Preparing distribution package..."
mkdir -p "${DIST_DIR}"
rm -rf "${DIST_DIR}/${APP_NAME}"
cp -R "${APP_PATH}" "${DIST_DIR}/"

# Create ZIP archive
echo ""
echo "Creating ZIP archive..."
cd "${DIST_DIR}"
zip -qr -X "${ZIP_NAME}" "${APP_NAME}"

# Notarize if this is a signed build
if [ "$IS_SIGNED" = true ]; then
    echo ""
    echo "=========================================="
    echo "Notarizing with Apple..."
    echo "=========================================="

    if [ -z "$APPLE_ID" ] || [ -z "$APPLE_ID_PASSWORD" ] || [ -z "$APPLE_TEAM_ID" ]; then
        echo "⚠️  Warning: Notarization credentials not provided"
        echo "Set APPLE_ID, APPLE_ID_PASSWORD, and APPLE_TEAM_ID to notarize"
        echo "Continuing without notarization..."
    else
        echo "Submitting ${ZIP_NAME} for notarization..."

        # Submit for notarization
        xcrun notarytool submit "${ZIP_NAME}" \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_ID_PASSWORD" \
            --team-id "$APPLE_TEAM_ID" \
            --wait

        echo "Notarization complete!"

        # Unzip, staple, and re-zip
        echo "Stapling notarization ticket..."
        unzip -q "${ZIP_NAME}"
        xcrun stapler staple "${APP_NAME}"

        # Re-create the ZIP with stapled ticket
        rm "${ZIP_NAME}"
        zip -qr -X "${ZIP_NAME}" "${APP_NAME}"

        echo "✅ Notarization ticket stapled successfully"
    fi
fi

# Calculate checksum
CHECKSUM=$(shasum -a 256 "${ZIP_NAME}" | cut -d ' ' -f 1)

echo ""
echo "=========================================="
echo "✅ Release package created successfully!"
echo "=========================================="
echo "Package: ${DIST_DIR}/${ZIP_NAME}"
echo "Size: $(du -h "${DIST_DIR}/${ZIP_NAME}" | cut -f1)"
echo "SHA256: ${CHECKSUM}"

if [ "$IS_SIGNED" = true ]; then
    echo ""
    echo "Build Type: Developer ID Signed & Notarized"
    echo "Distribution: Ready for immediate download and installation"
    echo "User Experience: No security warnings - double-click to install"
else
    echo ""
    echo "Build Type: Unsigned (ad-hoc signing)"
    echo "Distribution: Free/open-source distribution"
    echo "User Experience: Requires right-click > Open on first launch"
fi

echo ""
echo "To distribute:"
echo "1. Upload ${ZIP_NAME} to GitHub releases"
echo "2. Include the SHA256 checksum in release notes"
echo ""
