#!/bin/bash

# Get the repository root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Version
VERSION="0.1"
PKG_NAME="apple-sharpener-${VERSION}.pkg"
RELEASES_FILE="$REPO_ROOT/releases"
BUILD_FILE="$REPO_ROOT/build/libapple_sharpener.dylib"

# Change to repository root
cd "$REPO_ROOT"

# Check if version already exists
if [ -f "$RELEASES_FILE" ] && grep -q "^${VERSION}$" "$RELEASES_FILE"; then
    echo "Error: Version ${VERSION} already exists in releases log"
    echo "Please update the VERSION variable to a new version number"
    exit 1
fi

# Check if build exists, if not, run make
if [ ! -f "$BUILD_FILE" ]; then
    echo "Build not found. Running make..."
    if ! make; then
        echo "Error: Build failed"
        exit 1
    fi
fi

# Create temporary directory structure
TEMP_DIR="$(mktemp -d)"
PAYLOAD_DIR="$TEMP_DIR/payload"
SCRIPTS_DIR="$TEMP_DIR/scripts"

mkdir -p "$PAYLOAD_DIR/usr/local/bin/ammonia/tweaks"
mkdir -p "$SCRIPTS_DIR"

# Copy files to payload
if ! cp "$BUILD_FILE" "$PAYLOAD_DIR/usr/local/bin/ammonia/tweaks/"; then
    echo "Error: Failed to copy dylib"
    rm -rf "$TEMP_DIR"
    exit 1
fi

if ! cp libapple_sharpener.dylib.blacklist "$PAYLOAD_DIR/usr/local/bin/ammonia/tweaks/"; then
    echo "Error: Failed to copy blacklist"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Create postinstall script
cat > "$SCRIPTS_DIR/postinstall" << 'EOF'
#!/bin/bash

# Restart Ammonia service
sudo pkill -9 ammonia || true
sleep 2
sudo launchctl bootout system /Library/LaunchDaemons/com.bedtime.ammonia.plist 2>/dev/null || true
sleep 2
sudo launchctl bootstrap system /Library/LaunchDaemons/com.bedtime.ammonia.plist

exit 0
EOF

chmod +x "$SCRIPTS_DIR/postinstall"

# Build package
pkgbuild --root "$PAYLOAD_DIR" \
         --scripts "$SCRIPTS_DIR" \
         --identifier com.yourusername.apple-sharpener \
         --version "$VERSION" \
         --install-location "/" \
         "$PKG_NAME"

# Check if package was created successfully
if [ $? -eq 0 ] && [ -f "$PKG_NAME" ]; then
    # Clean up temp directory
    rm -rf "$TEMP_DIR"

    # Log the version (ensure clean line-by-line logging)
    if [ ! -f "$RELEASES_FILE" ] || [ ! -s "$RELEASES_FILE" ]; then
        # If file doesn't exist or is empty, create with just the version
        echo "$VERSION" > "$RELEASES_FILE"
    else
        # Add new version and sort in reverse order (newest first)
        echo "$VERSION" >> "$RELEASES_FILE"
        sort -rV "$RELEASES_FILE" | uniq > "$RELEASES_FILE.tmp"
        mv "$RELEASES_FILE.tmp" "$RELEASES_FILE"
    fi

    # Remove any empty lines from the releases file
    sed -i '' '/^[[:space:]]*$/d' "$RELEASES_FILE"

    echo "Created installer package: $REPO_ROOT/$PKG_NAME"
    echo "Version $VERSION logged in $RELEASES_FILE"
else
    # Clean up on failure
    rm -rf "$TEMP_DIR"
    [ -f "$PKG_NAME" ] && rm "$PKG_NAME"
    echo "Error: Failed to create installer package"
    exit 1
fi 