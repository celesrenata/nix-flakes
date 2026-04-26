#!/usr/bin/env bash
# Configure winapps with only apps that should be accessed via RDP
# Skips browsers and utilities that should stay on Linux

cd ~/winapps/pkg

BIN_PATH="$HOME/.local/bin"
APP_PATH="$HOME/.local/share/applications"
SYS_PATH="$HOME/.local/share/winapps"

# Only these apps get Linux desktop entries
APPS=(
    # Microsoft Office
    word-o365
    excel-o365
    powerpoint-o365
    outlook-o365
    onenote-o365
    publisher-o365
    access
    # Adobe
    adobe-cc
    photoshop-cc
    lightroom-cc
    illustrator-cc
    premiere-pro-cc
    aftereffects-cc
    acrobat-reader-dc
    # Utilities worth having via RDP
    cmd
    powershell
)

# Ensure winapps binary is in place
cp -n "$HOME/winapps/pkg/bin/winapps" "$BIN_PATH/winapps" 2>/dev/null
chmod +x "$BIN_PATH/winapps"

# Configure Windows desktop entry
mkdir -p "$SYS_PATH/icons"
cp "$HOME/winapps/pkg/icons/windows.svg" "$SYS_PATH/icons/windows.svg"
cat > "$APP_PATH/windows.desktop" << EOF
[Desktop Entry]
Name=Windows
Exec=$BIN_PATH/winapps windows %F
Terminal=false
Type=Application
Icon=$SYS_PATH/icons/windows.svg
StartupWMClass=Microsoft Windows
Comment=Microsoft Windows
Categories=Windows
EOF

# Configure each app
for F in "${APPS[@]}"; do
    if [ -d "apps/$F" ]; then
        . "apps/$F/info"
        mkdir -p "$SYS_PATH/apps/$F"
        cp -r "apps/$F/"* "$SYS_PATH/apps/$F/"

        # Find icon extension
        ICON_EXT="svg"
        [ -f "$SYS_PATH/apps/$F/icon.ico" ] && ICON_EXT="ico"
        [ -f "$SYS_PATH/apps/$F/icon.png" ] && ICON_EXT="png"

        cat > "$APP_PATH/$F.desktop" << EOF
[Desktop Entry]
Name=$NAME
Exec=$BIN_PATH/winapps $F %F
Terminal=false
Type=Application
Icon=$SYS_PATH/apps/$F/icon.$ICON_EXT
StartupWMClass=$FULL_NAME
Comment=$FULL_NAME
Categories=${CATEGORIES:-WinApps}
MimeType=${MIME_TYPES:-}
EOF

        cat > "$BIN_PATH/$F" << EOF
#!/usr/bin/env bash
$BIN_PATH/winapps $F \$@
EOF
        chmod +x "$BIN_PATH/$F"
        echo "✅ $NAME ($F)"
    fi
done

echo "WinApps configuration complete."
