#!/usr/bin/env bash

# sleep 0 # idk i wanted some delay or colors dont get applied properly
if [ ! -d "$HOME"/.cache/ags/user/generated ]; then
    mkdir -p "$HOME"/.cache/ags/user/generated
fi
cd "$HOME/.config/ags" || exit

colornames=''
colorstrings=''
colorlist=()
colorvalues=()

# wallpath=$(swww query | awk -F 'image: ' '{print $2}')
# wallpath_png="$HOME"'/.cache/ags/user/generated/hypr/lockscreen.png'
# convert "$wallpath" "$wallpath_png"
# wallpath_png=$(echo "$wallpath_png" | sed 's/\//\\\//g')
# wallpath_png=$(sed 's/\//\\\\\//g' <<< "$wallpath_png")

if [[ "$1" = "--bad-apple" ]]; then
    cp scripts/color_generation/specials/_material_badapple.scss scss/_material.scss
    colornames=$(cat scripts/color_generation/specials/_material_badapple.scss | cut -d: -f1)
    colorstrings=$(cat scripts/color_generation/specials/_material_badapple.scss | cut -d: -f2 | cut -d ' ' -f2 | cut -d ";" -f1)
    IFS=$'\n'
    # filearr=( $filelist ) # Get colors
    colorlist=( $colornames ) # Array of color names
    colorvalues=( $colorstrings ) # Array of color values
else
    colornames=$(cat scss/_material.scss | cut -d: -f1)
    colorstrings=$(cat scss/_material.scss | cut -d: -f2 | cut -d ' ' -f2 | cut -d ";" -f1)
    IFS=$'\n'
    # filearr=( $filelist ) # Get colors
    colorlist=( $colornames ) # Array of color names
    colorvalues=( $colorstrings ) # Array of color values
fi

transparentize() {
  local hex="$1"
  local alpha="$2"
  local red green blue

  red=$((16#${hex:1:2}))
  green=$((16#${hex:3:2}))
  blue=$((16#${hex:5:2}))

  printf 'rgba(%d, %d, %d, %.2f)\n' "$red" "$green" "$blue" "$alpha"
}

dehex() {
  local hex="$1"
  local red green blue

  red=$((16#${hex:1:2}))
  green=$((16#${hex:3:2}))
  blue=$((16#${hex:5:2}))

  printf '%d, %d, %d' "$red" "$green" "$blue"
}

get_light_dark() {
    lightdark=""
    if [ ! -f "$HOME"/.cache/ags/user/colormode.txt ]; then
        echo "" > "$HOME"/.cache/ags/user/colormode.txt
    else
        lightdark=$(cat "$HOME"/.cache/ags/user/colormode.txt) # either "" or "-l"
    fi
    echo "$lightdark"
}

apply_gtklock() {
    # Check if scripts/templates/gtklock/main.scss exists
    if [ ! -f "scripts/templates/gtklock/main.scss" ]; then
        echo "SCSS not found for Gtklock. Skipping that."
        return
    fi

    # Copy template
    mkdir -p "$HOME"/.cache/ags/user/generated/gtklock
    sass "scripts/templates/gtklock/main.scss" "$HOME"/.cache/ags/user/generated/gtklock/style.css
    cp "$HOME"/.cache/ags/user/generated/gtklock/style.css "$HOME"/.config/gtklock/style.css
}

apply_fuzzel() {
    # Check if scripts/templates/fuzzel/fuzzel.ini exists
    if [ ! -f "scripts/templates/fuzzel/fuzzel.ini" ]; then
        echo "Template file not found for Fuzzel. Skipping that."
        return
    fi
    # Copy template
    mkdir -p "$HOME"/.cache/ags/user/generated/fuzzel
    cp "scripts/templates/fuzzel/fuzzel.ini" "$HOME"/.cache/ags/user/generated/fuzzel/fuzzel.ini
    # Apply colors
    for i in "${!colorlist[@]}"; do
        sed -i "s/{{ ${colorlist[$i]} }}/${colorvalues[$i]#\#}/g" "$HOME"/.cache/ags/user/generated/fuzzel/fuzzel.ini
    done

    cp  "$HOME"/.cache/ags/user/generated/fuzzel/fuzzel.ini "$HOME"/.config/fuzzel/fuzzel.ini
}

apply_foot() {
    if [ ! -f "scripts/templates/foot/foot.ini" ]; then
        echo "Template file not found for Foot. Skipping that."
        return
    fi
    # Copy template
    mkdir -p "$HOME"/.cache/ags/user/generated/foot
    cp "scripts/templates/foot/foot.ini" "$HOME"/.cache/ags/user/generated/foot/foot.ini
    # Apply colors
    for i in "${!colorlist[@]}"; do
        # sed -i "s/${colorlist[$i]} #/${colorvalues[$i]#\#}/g" "$HOME"/.cache/ags/user/generated/foot/foot.ini
        sed -i "s/{{ ${colorlist[$i]} }}/${colorvalues[$i]#\#}/g" "$HOME"/.cache/ags/user/generated/foot/foot.ini
    done

    cp "$HOME"/.cache/ags/user/generated/foot/foot.ini "$HOME/.config/foot/foot.ini"
}

apply_term() {
    # Check if scripts/templates/foot/foot.ini exists
    if [ ! -f "scripts/templates/terminal/sequences.txt" ]; then
        echo "Template file not found for Terminal. Skipping that."
        return
    fi
    # Copy template
    mkdir -p "$HOME"/.cache/ags/user/generated/terminal
    cp "scripts/templates/terminal/sequences.txt" "$HOME"/.cache/ags/user/generated/terminal/sequences.txt
    # Apply colors
    for i in "${!colorlist[@]}"; do
        sed -i "s/${colorlist[$i]} #/${colorvalues[$i]#\#}/g" "$HOME"/.cache/ags/user/generated/terminal/sequences.txt
    done
    cp "$HOME"/.cache/ags/user/generated/terminal/sequences.txt "$HOME"/.config/fish/sequences.txt

    for file in /dev/pts/*; do
      if [[ $file =~ ^/dev/pts/[0-9]+$ ]]; then
        cat "$HOME"/.config/fish/sequences.txt > "$file"
      fi
    done
}

apply_hyprland() {
    # Check if scripts/templates/hypr/hyprland/colors.conf exists
    if [ ! -f "scripts/templates/hypr/hyprland/colors.conf" ]; then
        echo "Template file not found for Hyprland colors. Skipping that."
        return
    fi
    # Copy template
    mkdir -p "$HOME"/.cache/ags/user/generated/hypr/hyprland
    cp "scripts/templates/hypr/hyprland/colors.conf" "$HOME"/.cache/ags/user/generated/hypr/hyprland/colors.conf
    # Apply colors
    for i in "${!colorlist[@]}"; do
        sed -i "s/{{ ${colorlist[$i]} }}/${colorvalues[$i]#\#}/g" "$HOME"/.cache/ags/user/generated/hypr/hyprland/colors.conf
    done

    cp "$HOME"/.cache/ags/user/generated/hypr/hyprland/colors.conf "$HOME"/.config/hypr/hyprland/colors.conf
}

apply_hyprlock() {
    # Check if scripts/templates/hypr/hyprlock.conf exists
    if [ ! -f "scripts/templates/hypr/hyprlock.conf" ]; then
        echo "Template file not found for hyprlock. Skipping that."
        return
    fi
    # Copy template
    mkdir -p "$HOME"/.cache/ags/user/generated/hypr/
    cp "scripts/templates/hypr/hyprlock.conf" "$HOME"/.cache/ags/user/generated/hypr/hyprlock.conf
    # Apply colors
    # sed -i "s/{{ SWWW_WALL }}/${wallpath_png}/g" "$HOME"/.cache/ags/user/generated/hypr/hyprlock.conf
    for i in "${!colorlist[@]}"; do
        sed -i "s/{{ ${colorlist[$i]} }}/${colorvalues[$i]#\#}/g" "$HOME"/.cache/ags/user/generated/hypr/hyprlock.conf
    done

    cp "$HOME"/.cache/ags/user/generated/hypr/hyprlock.conf "$HOME"/.config/hypr/hyprlock.conf
}

apply_gtk() { # Using gradience-cli
    lightdark=$(get_light_dark)

    # Copy template
    mkdir -p "$HOME"/.cache/ags/user/generated/gradience
    cp "scripts/templates/gradience/preset.json" "$HOME"/.cache/ags/user/generated/gradience/preset.json

    # Apply colors
    for i in "${!colorlist[@]}"; do
        sed -i "s/{{ ${colorlist[$i]} }}/${colorvalues[$i]}/g" "$HOME"/.cache/ags/user/generated/gradience/preset.json
    done

    mkdir -p "$HOME/.config/presets" # create gradience presets folder
    gradience-cli apply -p "$HOME"/.cache/ags/user/generated/gradience/preset.json --gtk both

    # Set light/dark preference
    # And set GTK theme manually as Gradience defaults to light adw-gtk3
    # (which is unreadable when broken when you use dark mode)
    if [ "$lightdark" = "-l" ]; then
        gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
    else
        gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    fi
}

apply_ags() {
    sass "$HOME"/.config/ags/scss/main.scss "$HOME"/.cache/ags/user/generated/style.css
    ags run-js 'openColorScheme.value = true; Utils.timeout(2000, () => openColorScheme.value = false);'
    ags run-js "App.resetCss(); App.applyCss('${HOME}/.cache/ags/user/generated/style.css');"
}

apply_wofi() {
    # Check if scripts/templates/wofi/style.css exists
    if [ ! -f "scripts/templates/wofi/style.css" ]; then
        echo "Template file not found for Wofi colors. Skipping that."
        return
    fi
    # Copy template
    cp "scripts/templates/wofi/style.css" "$HOME/.config/wofi/style_new.css"
    # Apply colors
    for i in "${!colorlist[@]}"; do
        sed -i "s/{{ ${colorlist[$i]} }}/${colorvalues[$i]#\#}/g" "$HOME/.config/wofi/style_new.css"
    done

    for i in "${!colorlist[@]}"; do
        dehexed=$(dehex ${colorvalues[$i]})
        sed -i "s/{{ ${colorlist[$i]}-rgb }}/${dehexed}/g" "$HOME/.config/wofi/style_new.css"
    done

    mv "$HOME/.config/wofi/style_new.css" "$HOME/.config/wofi/style.css"
}

apply_ags &
apply_hyprland &
apply_hyprlock &
apply_gtk &
apply_foot &
# apply_gtklock &
apply_fuzzel &
apply_term &
apply_wofi &
