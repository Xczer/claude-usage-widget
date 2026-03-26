#!/usr/bin/env zsh
# deploy.sh — build, sign, and install Claude Usage Widget
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ClaudeUsageWidget"
APP_DEST="$HOME/Applications/$APP_NAME.app"
BUILD_DIR="/tmp/claude-widget-build"
HOST_ENT="$PROJECT_DIR/ClaudeUsageWidget/ClaudeUsageWidget.entitlements"
EXT_ENT="$PROJECT_DIR/ClaudeUsageWidgetExtension/ClaudeUsageWidgetExtension.entitlements"
ICON="$PROJECT_DIR/ClaudeUsageWidget/AppIcon.icns"
EXT_BUNDLE="$APP_DEST/Contents/PlugIns/ClaudeUsageWidgetExtension.appex"

echo "▸ Killing existing processes..."
pkill -f "$APP_NAME" 2>/dev/null || true
pkill -f "ClaudeUsageWidgetExtension" 2>/dev/null || true
sleep 1

echo "▸ Building..."
xcodebuild build \
  -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "error:|warning:|BUILD|SUCCEED|FAIL" | grep -v "deprecated"

echo "▸ Installing..."
rm -rf "$APP_DEST"
cp -R "$BUILD_DIR/Build/Products/Release/$APP_NAME.app" "$APP_DEST"

echo "▸ Injecting icon..."
mkdir -p "$APP_DEST/Contents/Resources"
cp "$ICON" "$APP_DEST/Contents/Resources/AppIcon.icns"

echo "▸ Signing with entitlements..."
codesign --force --sign - --entitlements "$EXT_ENT" "$EXT_BUNDLE"
codesign --force --sign - --entitlements "$HOST_ENT" "$APP_DEST"

echo "▸ Clearing widget cache..."
rm -rf "$HOME/Library/Containers/com.claude.usagewidget.widget/Data/SystemData/com.apple.chrono/" 2>/dev/null || true

echo "▸ Registering extension..."
pluginkit -r "$EXT_BUNDLE" 2>/dev/null || true
sleep 1
pluginkit -a "$EXT_BUNDLE"
sleep 1

echo "▸ Registering with Launch Services..."
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f "$APP_DEST"

echo "▸ Restarting widget host..."
killall NotificationCenter 2>/dev/null || true
sleep 2

echo "▸ Launching app..."
open "$APP_DEST" --args --background

sleep 2
echo ""
echo "✓ Deployed! Extension registered:"
pluginkit -m -v | grep claude
echo ""
echo "→ Right-click desktop → Edit Widgets → search 'Claude' → add"
