#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter is not installed or not in PATH. See https://docs.flutter.dev/get-started/install' >&2
  exit 1
fi

# The application code is deliberately included without generated Flutter
# platform folders so it can bootstrap against the user-installed SDK.
# Preserve authored sources if `flutter create` rewrites defaults.
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
cp -R lib "$TEMP_DIR/lib"
cp pubspec.yaml "$TEMP_DIR/pubspec.yaml"
cp analysis_options.yaml "$TEMP_DIR/analysis_options.yaml"
cp README.md "$TEMP_DIR/README.md"
cp .gitignore "$TEMP_DIR/.gitignore"

flutter create \
  --project-name=savour \
  --org=dev.savour \
  --platforms=android,ios,linux \
  --android-language=kotlin \
  --no-pub \
  .

cp -R "$TEMP_DIR/lib/." lib/
cp "$TEMP_DIR/pubspec.yaml" pubspec.yaml
cp "$TEMP_DIR/analysis_options.yaml" analysis_options.yaml
cp "$TEMP_DIR/README.md" README.md
cp "$TEMP_DIR/.gitignore" .gitignore
# Flutter may add the example counter-app widget test, which is not ours.
rm -f test/widget_test.dart
python3 tool/configure_platforms.py
flutter pub get
# Generate installed launcher icons from supplied 1024px source.
dart run flutter_launcher_icons

echo
printf 'Ready! Run:\n  flutter run -d <device-id>\n  flutter analyze\n  flutter test\n'
