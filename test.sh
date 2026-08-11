#!/usr/bin/env bash

set -eux

# before running:
#   xcrun simctl create 'iPhone 16' 'iPhone 16' 'ios18.3.1'

export GOOGLEMOBILEADS_PLUGIN_SCOPE="*google_mobile_ads*"
export GOOGLEMOBILEADS_PLUGIN_SCOPE_EXAMPLE="*google_mobile_ads_example*"

export GITHUB_WORKSPACE=$(pwd)
export GITHUB_PATH=$(mktemp)

function _common {
  git checkout -- packages/google_mobile_ads
  git status --ignored=matching --porcelain -- packages/google_mobile_ads | grep '^!!' | awk '{print $2}' | xargs rm -rfv

  # Install Flutter
  rm -rf _flutter
  ./.github/workflows/scripts/install-flutter.sh 3.44.2

  # Install Tools
  ./.github/workflows/scripts/install-tools.sh

  export PATH=$(cat ${GITHUB_PATH} | tr "\n" ":"):${PATH}
}

function _android {
  # Build Example
  rm -rf packages/google_mobile_ads/example/build
  mkdir -p packages/google_mobile_ads/example/build/ios/SourcePackages

  ./.github/workflows/scripts/build-example.sh android ./lib/main.dart packages/google_mobile_ads/example
  
  # Unit Tests
  pushd packages/google_mobile_ads/example/android
  ./gradlew :google_mobile_ads:testDebugUnitTest
  popd
}

function _ios {
  # Build iOS Example
  rm -rf packages/google_mobile_ads/example/build rf packages/google_mobile_ads/example/ios/build
  mkdir -p packages/google_mobile_ads/example/build/ios/SourcePackages packages/google_mobile_ads/example/ios/build/ios/SourcePackages
  
  # Unit Tests
  ./.github/workflows/scripts/build-example.sh ios ./lib/main.dart packages/google_mobile_ads/example
  
  pushd packages/google_mobile_ads/example/ios
  rm -rf TestResults TestResults.xcresult
  flutter clean
  flutter pub get
  pod install
  xcodebuild -configuration Debug -resultBundlePath TestResults VERBOSE_SCRIPT_LOGGING=YES -workspace Runner.xcworkspace -scheme Runner -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' test  
  popd
}

function _flutter {
  # Unit Tests
  pushd packages/google_mobile_ads/
  flutter test
  popd
  
  # Flutter Analyze
  pushd packages/google_mobile_ads/
  flutter analyze --no-fatal-warnings || true
  popd

  # Flutter Publish
  pushd packages/google_mobile_ads/
  flutter pub publish --dry-run || true
  popd

  # Flutter Format
  dart format packages/google_mobile_ads/
  ./.github/workflows/scripts/validate-formatting.sh
}

function _formatting {
  dart format packages/google_mobile_ads/
  flutter pub global activate flutter_plugin_tools
  flutter pub global run flutter_plugin_tools format --clang-format-path clang-format-mp-18
}

_common
_android
_ios
_flutter
#_formatting
