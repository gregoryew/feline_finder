#!/bin/bash

# Script to prevent Firestore lock errors when running the app

echo "🧹 Cleaning up previous app instances..."
pkill -f "feline_finder" || true
pkill -f "flutter" || true

echo "⏳ Waiting for processes to fully terminate..."
sleep 2

echo "🧽 Running flutter clean..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🚀 Starting the app..."
flutter run -d macos

