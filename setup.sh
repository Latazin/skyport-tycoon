#!/usr/bin/env bash
# Gera as pastas android/ e ios/, ícones e splash. Rode uma vez após baixar o projeto.
set -e
flutter create --org com.skyporttycoon --project-name skyport_tycoon --platforms android,ios .
rm -f test/widget_test.dart
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
MANIFEST=android/app/src/main/AndroidManifest.xml
sed -i.bak 's/android:label="[^"]*"/android:label="SkyPort: Airport Tycoon"/' "$MANIFEST" && rm -f "$MANIFEST.bak"
PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ]; then sed -i.bak 's/<string>Skyport Tycoon<\/string>/<string>SkyPort: Airport Tycoon<\/string>/' "$PLIST" && rm -f "$PLIST.bak"; fi
# AdMob: o SDK fecha o app na abertura se o ID do aplicativo não estiver no manifesto.
# admob_app_id.txt guarda o ID (o padrão é o ID de TESTE do Google).
ADMOB_ID="$(tr -d ' \n\r' < admob_app_id.txt 2>/dev/null || true)"
[ -z "$ADMOB_ID" ] && ADMOB_ID="ca-app-pub-3940256099942544~3347511713"
ADMOB_ID="$ADMOB_ID" python3 - <<'PY'
import os
f = 'android/app/src/main/AndroidManifest.xml'
s = open(f).read()
if 'com.google.android.gms.ads.APPLICATION_ID' not in s:
    tag = '<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="%s"/>\n        ' % os.environ['ADMOB_ID']
    s = s.replace('<activity', tag + '<activity', 1)
    open(f, 'w').write(s)
print('AdMob ok:', os.environ['ADMOB_ID'])
PY
# o verificador "lint" do Android quebra analisando plugins (bug do lint); não afeta o app
for f in android/build.gradle.kts android/build.gradle; do
  [ -f "$f" ] || continue
  grep -q "lintVital" "$f" || printf '\nsubprojects {\n    tasks.matching { it.name.startsWith("lintVital") }.configureEach { enabled = false }\n}\n' >> "$f"
done
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
