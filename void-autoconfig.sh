#!/bin/bash

# update the xbps package manager 
sudo xbps-install -S xbps

# install X11 and universal packages
sudo xbps-install -S xorg ranger vim xfce4-terminal anthy

echo "Enter 'i3' to install i3 window manager, 'bspwm' to install bspwm, 'xfce' to install 'xfce', or 'kde' to install KDE: "
read input

if [ "$input" == "i3" ]; then
  sudo xbps-install -S i3 i3lock polybar nm-applet xfce4-power-manager picom nitrogen xrandr arandr flameshot copyq pulseaudio pavucontrol thunar rofi blueman
  cp i3/myconfigfile.txt ~/.config/i3/
elif [ "$input" == "bspwm" ]; then
  sudo xbps-install -S bspwm sxhkd polybar xfce4-terminal 
elif [ "$input" == "kde" ]; then
  sudo xbps-install -S kde xfce4-terminal
else
  echo "Invalid input. Exiting."
  exit 1
fi

echo "Installation complete."

