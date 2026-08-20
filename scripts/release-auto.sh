#!/usr/bin/env bash
#
# release-auto.sh — fully automated release for MyQuickFinder.
#
# Runs the same pipeline as the interactive release.sh wizard (sign → notarize
# → staple → package → tag → GitHub release) with zero prompts. It fails fast
# with a clear message at the first step that cannot proceed; everything that
# can run without a human will run.
#
# Prerequisites (checked up front):
#   - checked out on `main`, working tree clean
#   - MARKETING_VERSION bumped so the tag does not exist yet
#   - Developer ID Application certificate installed
#   - notarytool credential profile "$NOTARY_PROFILE" stored in the keychain
#     (create once: xcrun notarytool store-credentials "$NOTARY_PROFILE" \
#       --key ~/.appstoreconnect/AuthKey_*.p8 --key-id <KEY_ID> \
#       --issuer <ISSUER_UUID> --team-id "$TEAM_ID")
#   - gh authenticated with push rights
#
# Usage: ./scripts/release-auto.sh
# Output is mirrored to .release-build/release-auto.log.

set -euo pipefail

TEAM_ID="${TEAM_ID:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-MyQuickFinder}"
SCHEME="MyQuickFinder"
APP_NAME="MyQuickFinder.app"

cd "$(git rev-parse --show-toplevel)"

BUILD_DIR="$(pwd)/.release-build"
ARTIFACT_DIR="$(pwd)/.release-artifacts"
VERSION=$(awk -F'"' '/MARKETING_VERSION:/ { print $2; exit }' project.yml)
TAG="v${VERSION}"
ZIP="${ARTIFACT_DIR}/MyQuickFinder-${VERSION}.zip"
LOG_DIR="${BUILD_DIR}"
LOG_FILE="${LOG_DIR}/release-auto.log"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

note() { printf '  %s\n' "$1"; }
ok()   { printf '  ✓ %s\n' "$1"; }
fail() { printf '  ✗ %s\n' "$1" >&2; exit 1; }

echo "== MyQuickFinder release-auto ${TAG} =="
date "+%Y-%m-%d %H:%M:%S"

# ── 1. Preflight ───────────────────────────────────────────────────────────
echo "== Preflight =="
BRANCH=$(git rev-parse --abbrev-ref HEAD)
[[ "$BRANCH" == "main" ]] || fail "Not on main (on ${BRANCH}). Check out main first."
[[ -z "$(git status --porcelain)" ]] || fail "Working tree is dirty. Commit or stash first."
git rev-parse --verify "refs/tags/${TAG}" >/dev/null 2>&1 && fail "${TAG} already exists. Bump MARKETING_VERSION in project.yml first."
ok "branch main, tree clean, tag ${TAG} free"

swift test --package-path MyQuickFinderKit >/dev/null 2>&1 || fail "Kit tests failed."
./scripts/lint.sh >/dev/null 2>&1 || fail "Lint failed."
ok "tests and lint pass"

# ── 2. Certificate ─────────────────────────────────────────────────────────
echo "== Developer ID certificate =="
IDENTITIES=$(security find-identity -v -p codesigning 2>/dev/null || true)
SIGN_ID=$(printf '%s\n' "$IDENTITIES" | awk -F'"' '/Developer ID Application/ { print $2; exit }')
[[ -n "$SIGN_ID" ]] || fail "No Developer ID Application certificate installed."
TEAM_ID="${TEAM_ID:-$(printf '%s' "$SIGN_ID" | sed -n 's/.*(\([A-Z0-9]*\))$/\1/p')}"
ok "signing with ${SIGN_ID}"

# ── 3. Notarization credentials ────────────────────────────────────────────
echo "== Notarization credentials =="
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
  || fail "Keychain profile '${NOTARY_PROFILE}' missing. Store it once, e.g.: xcrun notarytool store-credentials '${NOTARY_PROFILE}' --key ~/.appstoreconnect/AuthKey_*.p8 --key-id <KEY_ID> --issuer <ISSUER_UUID> --team-id ${TEAM_ID}"
ok "profile ${NOTARY_PROFILE} present"

# ── 4. Build with Developer ID ─────────────────────────────────────────────
echo "== Build =="
rm -rf "$BUILD_DIR" "$ARTIFACT_DIR"
mkdir -p "$ARTIFACT_DIR"
BUILD_NUMBER=$(git rev-list --count HEAD)
note "build number: ${BUILD_NUMBER}"
xcodebuild -project MyQuickFinder.xcodeproj -scheme "$SCHEME" \
  -configuration Release -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_IDENTITY="$SIGN_ID" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
  build >/dev/null 2>&1 || fail "Build failed. Rebuild without '>/dev/null' to see why."

APP="${BUILD_DIR}/Build/Products/Release/${APP_NAME}"
[[ -d "$APP" ]] || fail "No build product at ${APP}"
SIGN_INFO=$(codesign -dvv "$APP" 2>&1 || true)
echo "$SIGN_INFO" | grep -q "Developer ID Application" || fail "Product is not Developer ID signed."
ENTITLEMENTS=$(codesign -d --entitlements - --xml "$APP" 2>/dev/null || true)
if echo "$ENTITLEMENTS" | grep -q "get-task-allow"; then
  fail "Product carries get-task-allow (debug entitlement). CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO missing."
fi
ok "built and signed"

# ── 5. Notarize ────────────────────────────────────────────────────────────
echo "== Notarize =="
ditto -c -k --keepParent "$APP" "$ZIP"
NOTARY_OUT=$(xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1 || true)
echo "$NOTARY_OUT" | sed 's/^/    /'
SUBMISSION_ID=$(printf '%s\n' "$NOTARY_OUT" | awk '/^ *id:/ { print $2; exit }')
if ! echo "$NOTARY_OUT" | grep -q "status: Accepted"; then
  [[ -n "$SUBMISSION_ID" ]] && xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE" 2>&1 | sed 's/^/    /' || true
  fail "Notarization was not accepted."
fi
ok "notarized"

# ── 6. Staple and verify ───────────────────────────────────────────────────
echo "== Staple and verify =="
xcrun stapler staple "$APP" || fail "Stapling failed."
xcrun stapler validate "$APP" >/dev/null 2>&1 || fail "Ticket is not stapled."
GATEKEEPER=$(spctl -a -vvv -t install "$APP" 2>&1 || true)
echo "$GATEKEEPER" | grep -q "accepted" || { echo "$GATEKEEPER" | sed 's/^/    /'; fail "Gatekeeper rejects the app — do not ship."; }
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
ok "ticket stapled, Gatekeeper accepts, repackaged"

# ── 7. Tag and publish ─────────────────────────────────────────────────────
echo "== Publish =="
git tag -a "$TAG" -m "MyQuickFinder ${VERSION}"
git push origin "$TAG"
gh release create "$TAG" "$ZIP" \
  --title "MyQuickFinder ${VERSION}" \
  --notes "Signed with Developer ID, notarized by Apple, ticket stapled. Unzip and drag into Applications."
ok "published ${TAG}"

echo "== Done =="
note "artifact: ${ZIP}"
note "log: ${LOG_FILE}"
