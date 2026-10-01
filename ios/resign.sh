#!/bin/bash
# Firma manual del .app del archive con el certificado de distribución y los
# perfiles de App Store, e empaqueta el .ipa. Necesario porque `xcodebuild` no
# deja usar perfiles "Xcode managed" en modo manual, y en modo automático se
# empeña en firmar para desarrollo (que exige dispositivos registrados).
set -euo pipefail
SP="$(cd "$(dirname "$0")" && pwd)"
IDENTITY="Apple Distribution: JAVIER COLAS ROMANOS (5JHD53WQ67)"
PROF_DIR="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
APP="$SP/BaliCircle.xcarchive/Products/Applications/Bali Circle.app"

# Localiza cada perfil por el application-identifier que declara.
find_profile() {
  local want="$1"
  for f in "$PROF_DIR"/*.mobileprovision; do
    if security cms -D -i "$f" 2>/dev/null | plutil -p - 2>/dev/null \
       | grep -q "\"application-identifier\" => \"$want\""; then echo "$f"; return 0; fi
  done
  echo "NO ENCONTRADO: $want" >&2; return 1
}
P_APP="$(find_profile "5JHD53WQ67.com.javiercolroma.balicircle")"
echo "perfil app:    $(basename "$P_APP")"

# Entitlements explícitos. beta-reports-active es lo que habilita TestFlight.
cat > "$SP/ent-app.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>application-identifier</key><string>5JHD53WQ67.com.javiercolroma.balicircle</string>
  <key>com.apple.developer.team-identifier</key><string>5JHD53WQ67</string>
  <key>com.apple.developer.applesignin</key><array><string>Default</string></array>
  <key>beta-reports-active</key><true/>
  <key>get-task-allow</key><false/>
</dict></plist>
EOF

cp "$P_APP" "$APP/embedded.mobileprovision"

# De dentro hacia fuera: primero frameworks, luego la app (ya no hay extensión de widget).
if [ -d "$APP/Frameworks" ]; then
  for fw in "$APP/Frameworks"/*; do
    [ -e "$fw" ] || continue
    codesign --force --timestamp --sign "$IDENTITY" "$fw"
  done
fi
codesign --force --timestamp --options runtime --sign "$IDENTITY" --entitlements "$SP/ent-app.plist" "$APP"

echo "=== verificación de firma ==="
codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 | tail -3

echo "=== entitlements finales de la app ==="
# Ojo: `| plutil -p -` falla aquí (el volcado no es plist limpio) y con
# `set -o pipefail` aborta el script. Se leen como texto plano.
codesign -d --entitlements :- "$APP" 2>/dev/null | tr -d '\0' \
  | grep -oE "com\.apple\.developer\.[a-z.-]+|application-identifier|beta-reports-active|Default"

# Empaqueta el .ipa
rm -rf "$SP/ipa" "$SP/export"; mkdir -p "$SP/ipa/Payload" "$SP/export"
cp -R "$APP" "$SP/ipa/Payload/"
(cd "$SP/ipa" && zip -qry "$SP/export/Bali Circle.ipa" Payload)
echo "=== ipa ==="; ls -la "$SP/export/"
