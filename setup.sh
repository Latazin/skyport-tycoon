#!/usr/bin/env bash
# Gera as pastas android/ e ios/, ícones e splash. Rode uma vez após baixar o projeto.
set -e
flutter create --org com.skyporttycoon --project-name skyport_tycoon --platforms android,ios .
rm -f test/widget_test.dart
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
MANIFEST=android/app/src/main/AndroidManifest.xml
sed -i.bak 's/android:label="[^"]*"/android:label="SkyPort Tycoon"/' "$MANIFEST" && rm -f "$MANIFEST.bak"
PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ]; then sed -i.bak 's/<string>Skyport Tycoon<\/string>/<string>SkyPort Tycoon<\/string>/' "$PLIST" && rm -f "$PLIST.bak"; fi
echo "Projeto pronto. Teste: flutter run  |  APK: flutter build apk --release  |  AAB: flutter build appbundle --release"
