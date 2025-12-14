#!/usr/bin/env bash
if ! [ -f ~/.local/share/initialSetup.1 ]; then
  cp -r ~/.configstaging ~/.config
  chown 1000:100 -R ~/.config
  chmod -R +w ~/.config
  rsync -azL --no-perms ~/.configstaging/ ~/.config 2> /dev/null --exclude='*.bak'
  mkdir -p ~/.local/share
  mkdir -p ~/.config/foot
  mkdir -p ~/.config/fuzzel
  mkdir -p ~/.config/wofi
  mkdir -p ~/Videos
  touch ~/.local/share/initialSetup.1
  reboot
fi
if ! [ -f ~/.local/share/initialSetup.2 ]; then
  imgpath=~/Pictures/Backgrounds/love-is-love.jpg
  cursorposx=$(hyprctl cursorpos -j | gojq '.x' 2>/dev/null) || cursorposx=960
  cursorposy=$(hyprctl cursorpos -j | gojq '.y' 2>/dev/null) || cursorposy=540
  cursorposy_inverted=$(( screensizey - cursorposy ))
  sleep 5
  chown 1000:100 -R ~/.config
  chmod -R +w ~/.config
  swww img "$imgpath" --transition-step 100 --transition-fps 60 \
	 --transition-type grow --transition-angle 30 --transition-duration 2 \
	 --transition-pos "$cursorposx, $cursorposy_inverted"
  # QuickShell color generation
  ~/.config/quickshell/ii/scripts/colors/switchwall.sh "${imgpath}"
  if [ $? -eq 0 ]; then
    touch ~/.local/share/initialSetup.2
  fi
fi
for IDE in $(find ~/.config/JetBrains/ -name "*.vmoptions" 2>/dev/null); do
  if ! grep -q '\-Dawt.toolkit.name=WLToolkit' ${IDE}; then
    echo '' >> ${IDE}
    echo '-Dawt.toolkit.name=WLToolkit' >> ${IDE}
  fi
done
