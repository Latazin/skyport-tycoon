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
# notificações: permissão e desugaring exigidos pelo flutter_local_notifications
grep -q POST_NOTIFICATIONS "$MANIFEST" || sed -i.bak 's#<application#<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <application#' "$MANIFEST" && rm -f "$MANIFEST.bak"
python3 - <<'PY'
import os, re
for f in ['android/app/build.gradle.kts', 'android/app/build.gradle']:
    if not os.path.exists(f): continue
    s = open(f).read()
    kts = f.endswith('.kts')
    if 'oreLibraryDesugaring' not in s:
        s = s.replace('compileOptions {', 'compileOptions {\n        ' + ('isCoreLibraryDesugaringEnabled = true' if kts else 'coreLibraryDesugaringEnabled true'), 1)
        dep = ('coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")' if kts else "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'")
        if re.search(r'^dependencies \{', s, re.M): s = re.sub(r'^dependencies \{', 'dependencies {\n    ' + dep, s, count=1, flags=re.M)
        else: s += '\ndependencies {\n    ' + dep + '\n}\n'
        open(f, 'w').write(s)
    print('desugaring ok em', f)
PY
echo "Projeto pronto. Teste: flutter run  |  APK: flutter build apk --release  |  AAB: flutter build appbundle --release"
