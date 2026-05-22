#!/bin/bash
# LOUCE Linux DEB Build Script
# This script builds the production Linux app and packages it as a Debian (.deb) file.

set -e

VERSION="0.0.0"
APP_NAME="louce"
DEB_NAME="${APP_NAME}_v${VERSION}"

echo "=========================================="
echo "    Building LOUCE Linux DEB (Release)    "
echo "=========================================="

cd ../louce

# Clean previous builds
echo "[*] Cleaning old builds..."
flutter clean
flutter pub get

# Ensure rust code is updated
echo "[*] Updating flutter_rust_bridge bindings..."
flutter_rust_bridge_codegen generate

echo "[*] Compiling Flutter App for Linux..."
flutter build linux --release

# Ensure Rust Library is up to date (Linux flutter build handles this via CMake, but let's be sure)
cd ../rust
cargo build --release
cd ../louce

# Package to Debian
echo "[*] Creating Debian package structure..."
DEB_DIR="../packaging/${DEB_NAME}_amd64"
mkdir -p "$DEB_DIR/DEBIAN"
mkdir -p "$DEB_DIR/usr/bin"
mkdir -p "$DEB_DIR/usr/lib/$APP_NAME"
mkdir -p "$DEB_DIR/usr/share/applications"
mkdir -p "$DEB_DIR/usr/share/icons/hicolor/128x128/apps"

# Create Control File
cat <<EOF > "$DEB_DIR/DEBIAN/control"
Package: louce
Version: $VERSION
Section: utils
Priority: optional
Architecture: amd64
Depends: libc6 (>= 2.31), libgtk-3-0 (>= 3.24.0)
Maintainer: Funbinet <funbinet@gmail.com>
Description: LOUCE - Autonomous Bug Bounty Framework
 LOUCE is a production-grade autonomous bug bounty framework integrating a native Rust backend for lightning-fast network operations with a beautiful Flutter frontend.
EOF

# Copy Build Artifacts
cp -r build/linux/x64/release/bundle/* "$DEB_DIR/usr/lib/$APP_NAME/"

# Create Executable Wrapper
cat <<EOF > "$DEB_DIR/usr/bin/$APP_NAME"
#!/bin/bash
cd /usr/lib/$APP_NAME
exec ./$APP_NAME "\$@"
EOF
chmod +x "$DEB_DIR/usr/bin/$APP_NAME"

# Create Desktop Entry
cat <<EOF > "$DEB_DIR/usr/share/applications/$APP_NAME.desktop"
[Desktop Entry]
Name=LOUCE
Comment=Autonomous Bug Bounty Framework
Exec=/usr/bin/$APP_NAME
Icon=$APP_NAME
Terminal=false
Type=Application
Categories=Utility;Security;
EOF

# Copy Icon
if [ -f "assets/icons/logo.png" ]; then
    cp assets/icons/logo.png "$DEB_DIR/usr/share/icons/hicolor/128x128/apps/$APP_NAME.png"
fi

# Build DEB
cd ../packaging
echo "[*] Building Debian package..."
dpkg-deb --build "${DEB_NAME}_amd64"
mv "${DEB_NAME}_amd64.deb" "louce_v${VERSION}.deb"

# Clean up build dir
rm -rf "${DEB_NAME}_amd64"

echo "[*] Success! Application is ready at: packaging/louce_v${VERSION}.deb"
echo "=========================================="
