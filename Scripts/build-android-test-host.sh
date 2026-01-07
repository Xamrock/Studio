#!/bin/bash

# Build script for Android Test Host APKs
# This script builds the Android instrumentation test APKs and copies them to the Resources folder

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ANDROID_DIR="$PROJECT_ROOT/AndroidTestHost"
RESOURCES_DIR="$PROJECT_ROOT/Studio/Resources/AndroidTestHost"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Xamrock Studio - Android Test Host Build${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if Android project exists
if [ ! -d "$ANDROID_DIR" ]; then
    echo -e "${RED}Error: AndroidTestHost directory not found at $ANDROID_DIR${NC}"
    exit 1
fi

# Check if gradlew exists
if [ ! -f "$ANDROID_DIR/gradlew" ]; then
    echo -e "${RED}Error: gradlew not found in $ANDROID_DIR${NC}"
    echo -e "${YELLOW}Tip: Ensure you have the Android project set up correctly${NC}"
    exit 1
fi

# Check for Java
if ! command -v java &> /dev/null; then
    echo -e "${RED}Error: Java (JDK) is required but not found${NC}"
    echo -e "${YELLOW}Please install JDK 17 or later:${NC}"
    echo -e "  brew install openjdk@17"
    exit 1
fi

echo -e "${YELLOW}Java version:${NC}"
java -version
echo ""

# Navigate to Android project
cd "$ANDROID_DIR"

echo -e "${BLUE}Step 1:${NC} Cleaning previous build..."
./gradlew clean

echo ""
echo -e "${BLUE}Step 2:${NC} Building debug APK..."
./gradlew assembleDebug

echo ""
echo -e "${BLUE}Step 3:${NC} Building instrumentation test APK..."
./gradlew assembleDebugAndroidTest

echo ""
echo -e "${BLUE}Step 4:${NC} Verifying APKs..."

APP_APK="$ANDROID_DIR/app/build/outputs/apk/debug/app-debug.apk"
TEST_APK="$ANDROID_DIR/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk"

if [ ! -f "$APP_APK" ]; then
    echo -e "${RED}Error: app-debug.apk not found${NC}"
    exit 1
fi

if [ ! -f "$TEST_APK" ]; then
    echo -e "${RED}Error: app-debug-androidTest.apk not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ app-debug.apk found${NC}"
echo -e "${GREEN}✓ app-debug-androidTest.apk found${NC}"

echo ""
echo -e "${BLUE}Step 5:${NC} Copying APKs to Resources folder..."

# Create Resources directory if it doesn't exist
mkdir -p "$RESOURCES_DIR"

# Copy APKs
cp "$APP_APK" "$RESOURCES_DIR/"
cp "$TEST_APK" "$RESOURCES_DIR/"

echo -e "${GREEN}✓ APKs copied to $RESOURCES_DIR${NC}"

echo ""
echo -e "${BLUE}Step 6:${NC} Displaying APK information..."

APP_SIZE=$(du -h "$RESOURCES_DIR/app-debug.apk" | cut -f1)
TEST_SIZE=$(du -h "$RESOURCES_DIR/app-debug-androidTest.apk" | cut -f1)

echo -e "  app-debug.apk: ${GREEN}$APP_SIZE${NC}"
echo -e "  app-debug-androidTest.apk: ${GREEN}$TEST_SIZE${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Build completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Rebuild Xamrock Studio in Xcode to bundle the new APKs"
echo -e "  2. Run Xamrock Studio and test Android recording"
echo ""
