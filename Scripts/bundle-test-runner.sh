#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-Studio.app>"
    echo ""
    echo "Example: $0 ~/Desktop/Studio.app"
    exit 1
fi

APP_PATH="$1"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

echo "Building test runner for bundling into ${APP_PATH}..."

CONFIGURATION="Release"
DERIVED_DATA_PATH="${PROJECT_DIR}/Build"
TEST_PRODUCTS_DIR="${DERIVED_DATA_PATH}/Build/Products"

echo "Building TestHost for iOS Simulator..."
xcodebuild build-for-testing \
    -project "${PROJECT_DIR}/Studio.xcodeproj" \
    -scheme TestHost \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
    -only-testing:TestHostUITests \
    ONLY_ACTIVE_ARCH=NO \
    ENABLE_TESTABILITY=YES

echo "Building TestHost for iOS Device..."
xcodebuild build-for-testing \
    -project "${PROJECT_DIR}/Studio.xcodeproj" \
    -scheme TestHost \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    -destination 'generic/platform=iOS' \
    -only-testing:TestHostUITests \
    ONLY_ACTIVE_ARCH=NO \
    ENABLE_TESTABILITY=YES

echo "Creating TestRunner directories in app bundle..."
TESTRUNNER_DIR="${APP_PATH}/Contents/Resources/TestRunner"
SIMULATOR_DIR="${TESTRUNNER_DIR}/Simulator"
DEVICE_DIR="${TESTRUNNER_DIR}/Device"
mkdir -p "${SIMULATOR_DIR}"
mkdir -p "${DEVICE_DIR}"

echo "Copying simulator test artifacts..."
find "${TEST_PRODUCTS_DIR}" -name "*iphonesimulator*.xctestrun" -exec cp {} "${SIMULATOR_DIR}/" \;
cp -R "${TEST_PRODUCTS_DIR}/${CONFIGURATION}-iphonesimulator/TestHost.app" "${SIMULATOR_DIR}/"
cp -R "${TEST_PRODUCTS_DIR}/${CONFIGURATION}-iphonesimulator/TestHostUITests-Runner.app" "${SIMULATOR_DIR}/"

echo "Patching simulator xctestrun paths..."
SIMULATOR_XCTESTRUN=$(find "${SIMULATOR_DIR}" -name "*.xctestrun" | head -1)
if [ -f "$SIMULATOR_XCTESTRUN" ]; then
    plutil -convert xml1 "$SIMULATOR_XCTESTRUN"
    sed -i '' 's|/Release-iphonesimulator/|/|g' "$SIMULATOR_XCTESTRUN"
    sed -i '' 's|/Release-iphonesimulator<|<|g' "$SIMULATOR_XCTESTRUN"
    plutil -convert binary1 "$SIMULATOR_XCTESTRUN"
fi

echo "Copying device test artifacts..."
find "${TEST_PRODUCTS_DIR}" -name "*iphoneos*.xctestrun" -exec cp {} "${DEVICE_DIR}/" \;
cp -R "${TEST_PRODUCTS_DIR}/${CONFIGURATION}-iphoneos/TestHost.app" "${DEVICE_DIR}/"
cp -R "${TEST_PRODUCTS_DIR}/${CONFIGURATION}-iphoneos/TestHostUITests-Runner.app" "${DEVICE_DIR}/"

echo "Patching device xctestrun paths..."
DEVICE_XCTESTRUN=$(find "${DEVICE_DIR}" -name "*.xctestrun" | head -1)
if [ -f "$DEVICE_XCTESTRUN" ]; then
    plutil -convert xml1 "$DEVICE_XCTESTRUN"
    sed -i '' 's|/Release-iphoneos/|/|g' "$DEVICE_XCTESTRUN"
    sed -i '' 's|/Release-iphoneos<|<|g' "$DEVICE_XCTESTRUN"
    plutil -convert binary1 "$DEVICE_XCTESTRUN"
fi

echo "✅ Test runner bundled successfully!"
echo "Test artifacts at: ${TESTRUNNER_DIR}"
ls -la "${TESTRUNNER_DIR}"
