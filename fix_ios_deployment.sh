#!/bin/bash

# Script to fix iOS deployment target to 15.0

echo "Fixing iOS deployment target to 15.0..."

# Update Runner project
if [ -f "ios/Runner.xcodeproj/project.pbxproj" ]; then
    sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g' ios/Runner.xcodeproj/project.pbxproj
    echo "✓ Updated Runner project deployment target"
fi

# Clean and get dependencies
echo "Cleaning Flutter project..."
flutter clean

echo "Getting Flutter dependencies..."
flutter pub get

echo "Installing iOS pods..."
cd ios
pod install
cd ..

echo "✓ Done! iOS deployment target is now 15.0"
