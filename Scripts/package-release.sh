#!/bin/bash

set -e

# Usage: ./package-release.sh [version]
# Example: ./package-release.sh 1.0.0

VERSION=${1:-"1.0.0"}
CONFIGURATION="Release"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/Build"
APP_NAME="Xamrock Studio.app"
ARCHIVE_PATH="${BUILD_DIR}/Studio.xcarchive"
APP_PATH="${BUILD_DIR}/${APP_NAME}"
DIST_DIR="${BUILD_DIR}/Distribution"
ZIP_NAME="Xamrock-Studio-${VERSION}.zip"

echo "=========================================="
echo "Packaging Xamrock Studio v${VERSION}"
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
    SKIP_INSTALL=NO

# Step 2: Export the app bundle
echo ""
echo "Step 2/5: Exporting app bundle..."
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${BUILD_DIR}" \
    -exportOptionsPlist "${SCRIPT_DIR}/ExportOptions.plist"

# Step 3: Bundle test runners
echo ""
echo "Step 3/5: Bundling iOS test runners..."
"${SCRIPT_DIR}/bundle-test-runner.sh" "${APP_PATH}"

# Step 3.5: Re-sign the app after adding test runners
echo ""
echo "Step 3.5/5: Re-signing app bundle..."
codesign --force --sign "-" --deep "${APP_PATH}"

# Step 4: Prepare distribution directory
echo ""
echo "Step 4/5: Preparing distribution package..."
mkdir -p "${DIST_DIR}"
rm -rf "${DIST_DIR}/${APP_NAME}"
cp -R "${APP_PATH}" "${DIST_DIR}/"

# Step 5: Create ZIP archive
echo ""
echo "Step 5/5: Creating ZIP archive..."
cd "${DIST_DIR}"
zip -qr -X "${ZIP_NAME}" "${APP_NAME}"

# Calculate checksum
CHECKSUM=$(shasum -a 256 "${ZIP_NAME}" | cut -d ' ' -f 1)

echo ""
echo "=========================================="
echo "✅ Release package created successfully!"
echo "=========================================="
echo "Package: ${DIST_DIR}/${ZIP_NAME}"
echo "Size: $(du -h "${DIST_DIR}/${ZIP_NAME}" | cut -f1)"
echo "SHA256: ${CHECKSUM}"
echo ""
echo "To distribute:"
echo "1. Upload ${ZIP_NAME} to GitHub releases"
echo "2. Include the SHA256 checksum in release notes"
echo ""
