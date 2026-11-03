#!/bin/zsh
# Builds a universal Release SlapBook.app and packages dist/SlapBook-Pro-macOS.zip.
#
# Local build, ad hoc signed (opens on this Mac only):
#   Tools/release.sh
#
# Distribution build, signed with Developer ID and notarized by Apple:
#   xcrun notarytool store-credentials slapbook   # once; asks for Apple ID and app-specific password
#   DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE=slapbook Tools/release.sh
#
# BUILD_DIR defaults to /tmp because Finder metadata on Desktop folders can make
# codesign reject the bundle ("resource fork, Finder information, or similar detritus").
set -euo pipefail

ROOT=${0:A:h:h}
BUILD_DIR=${BUILD_DIR:-/tmp/SlapBookPro-release}
APP="$BUILD_DIR/Build/Products/Release/SlapBook.app"
ZIP="$ROOT/dist/SlapBook-Pro-macOS.zip"
DEVELOPER_ID=${DEVELOPER_ID:-}
NOTARY_PROFILE=${NOTARY_PROFILE:-}

if [[ -n $NOTARY_PROFILE && -z $DEVELOPER_ID ]]; then
  echo "NOTARY_PROFILE needs DEVELOPER_ID: Apple notarizes only Developer ID signed apps." >&2
  exit 1
fi

if [[ -n $DEVELOPER_ID ]]; then
  TEAM=${DEVELOPER_ID##*\(}; TEAM=${TEAM%\)}
  if [[ $TEAM == "$DEVELOPER_ID" ]]; then
    echo "DEVELOPER_ID must end with the team ID in parentheses, as listed by: security find-identity -v -p codesigning" >&2
    exit 1
  fi
  # A secure timestamp is required for notarization. Not injecting base
  # entitlements keeps the debugging entitlement out of a distributed app.
  SIGNING=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=$DEVELOPER_ID" "DEVELOPMENT_TEAM=$TEAM"
           OTHER_CODE_SIGN_FLAGS=--timestamp CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO)
  echo "Signing with $DEVELOPER_ID"
else
  SIGNING=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=)
  echo "Signing ad hoc. The result opens on this Mac only; set DEVELOPER_ID to distribute."
fi

echo "Building universal Release into $BUILD_DIR"
xcodebuild -project "$ROOT/SlapBook.xcodeproj" -scheme SlapBook -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$BUILD_DIR" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO "${SIGNING[@]}" clean build > "$BUILD_DIR.log" 2>&1 || {
  tail -30 "$BUILD_DIR.log" >&2
  echo "Build failed. Full log: $BUILD_DIR.log" >&2
  exit 1
}

codesign --verify --deep --strict "$APP"
codesign -d --entitlements - "$APP" 2>/dev/null | grep -q com.apple.security.app-sandbox || {
  echo "The built app is missing the App Sandbox entitlement." >&2
  exit 1
}
echo "Architectures: $(lipo -archs "$APP/Contents/MacOS/SlapBook")"

package() {
  mkdir -p "${ZIP:h}"
  rm -f "$ZIP"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
}
package

if [[ -n $NOTARY_PROFILE ]]; then
  echo "Submitting to Apple notary service (this can take a few minutes)"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  package
  spctl --assess --type execute --verbose=2 "$APP"
  echo "Notarized and stapled."
elif [[ -n $DEVELOPER_ID ]]; then
  echo "Signed but not notarized: Gatekeeper will still warn on other Macs. Set NOTARY_PROFILE to notarize."
fi

unzip -tq "$ZIP"
echo "Packaged $ZIP ($(du -h "$ZIP" | cut -f1))"
