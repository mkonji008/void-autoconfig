#!/bin/bash
##
echo "Void Linux autoconfig By-mkonji "

# Redirect output of the script to a log file
exec > >(tee logfile.txt)

##
# Update the xbps package manager and update Void
sudo xbps-install -Syu xbps
sudo xbps-install -Suv

##
# Install essential packages
sudo xbps-install -S vim curl wget xz unzip zip vim gptfdisk xtools mtools mlocate ntfs-3g fuse-exfat bash-completion linux-headers gtksourceview4 ffmpeg mesa-vdpau mesa-vaapi htop neofetch timeshift ranger

##
# Install developer Packages
sudo xbps-install autoconf automake bison m4 make libtool flex meson ninja optipng sassc python python3 python3-pip 

##
# Install security
sudo xbps-install -S gpg gpg2 yadm pass

##
# Install xorg, dbus and elogind and enable their services
sudo xbps-install -S xorg dbus elogind
sudo ln -s /etc/sv/dbus /var/service
sudo ln -s /etc/sv/elogind /var/service

echo "Enter 'i3', 'bspwm', 'gnome', or 'kde' to install the corresponding window manager: "
read wm

# Install selected window manager and copy configuration file
if [ "$wm" == "i3" ]; then
  sudo xbps-install -S i3
  cp i3/config ~/.config/i3/confignerd-fonts
elif [ "$wm" == "bspwm" ]; then
  sudo xbps-install -S bspwm
  cp bspwm/config ~/.config/bspwm/config
elif [ "$wm" == "gnome" ]; then
  sudo xbps-install -s gnome gdm
  sudo ln -s /etc/sv/gdm /var/service
  sudo xbps-install -Rs xdg-desktop-portal xdg-desktop-portal-gtk xdg-user-dirs xdg-user-dirs-gtk xdg-utils
elif [ "$wm" == "kde" ]; then
  sudo xbps-install -S kde
else
  echo "Invalid input. Exiting."
  exit 1
fi

# Check for package list file
if [ -f "pkgslist-$wm.txt" ]; then
  # Install packages from package list file
  while read pkg; do
    sudo xbps-install -S "$pkg"
  done < "pkgslist-$wm.txt"
fi

echo "WM/DE Installation complete, moving onto next step."

#######
# Install a desktop enviornment 
echo "Enter 'i3' to install i3 window manager, 'bspwm' to install bspwm, 'xfce' to install 'xfce', or 'kde' to install KDE: "
read input

if [ "$input" == "i3" ]; then
  sudo xbps-install -S i3 i3lock polybar nm-applet xfce4-power-manager picom nitrogen xrandr arandr flameshot copyq pulseaudio pavucontrol thunar rofi blueman
  cp i3/myconfigfile.txt ~/.config/i3/
elif [ "$input" == "bspwm" ]; then
  sudo xbps-install -S bspwm sxhkd polybar  
elif [ "$input" == "kde" ]; then
  sudo xbps-install -S kde 
else
  echo "Invalid input. Exiting."
  exit 1
fi

# Install SpacevVim
curl -sLf https://spacevim.org/install.sh | bash

  cp SpaceVim/init.toml ~/.SpaceVim.d/init.toml
echo "Installation complete."


## 
# Display Configuration
# Prompt for what display adapter to install, install it and it's mircrocode
# After installing the driver check what display adapter is used and add the tearfree option to the xorg.conf file
echo "Enter 'intel' to install Intel drivers and microcode, 'amd' to install AMD drivers and microcode, or 'nvidia' to install NVIDIA drivers: "
read drivers

if [ "$drivers" == "intel" ]; then
  sudo xbps-install -S xf86-video-intel linux-firmware-intel intel-ucode mesa-dri vulkan-loader mesa-vulkan-intel intel-video-accel
elif [ "$drivers" == "amd" ]; then
  sudo xbps-install -S linux-firmware-amd xf86-video-amdgpu amd-ucode mesa-dri vulkan-loader mesa-vulkan-radeon mesa-vaapi mesa-vdpau
elif [ "$drivers" == "nvidia" ]; then
  sudo xbps-install -S nvidia nvidia-settings
else
  echo "Invalid input. Exiting."
  exit 1
fi

echo "Installation complete."

##
# Check for display adapter
if lspci | grep -q "Intel"; then
  display="intel"
elif lspci | grep -q "AMD"; then
  display="amdgpu"
elif lspci | grep -q "NVIDIA"; then
  display="nvidia"
else
  echo "Unable to determine display adapter. Exiting."
  exit 1
fi

# Check if the Xorg configuration file exists
if [ ! -f "/etc/X11/xorg.conf" ]; then
  # Create the Xorg configuration file if it does not exist
  echo "Section \"Device\"" >> /etc/X11/xorg.conf
  echo "    Identifier  \"Graphics Adapter\"" >> /etc/X11/xorg.conf
  echo "    Driver      \"$display\"" >> /etc/X11/xorg.conf
  echo "    Option      \"TearFree\"    \"true\"" >> /etc/X11/xorg.conf
  echo "EndSection" >> /etc/X11/xorg.conf
else
  # Check if the NoTear option is already set in the Xorg configuration file
  if ! grep -q "Option      \"TearFree\"" /etc/X11/xorg.conf; then
    # Add the NoTear option if it is not set
    sed -i '/Identifier/a \    Option      \"TearFree\"    \"true\"' /etc/X11/xorg.conf
  fi
fi

echo "NoTear option added to Xorg configuration file."

##
# Install Cronie for cron jobs
echo "Installing and Configuring Cronie."

sudo xbps-install -y cronie
sudo ln -sv /etc/sv/cronie /var/service

##
# Install TLP and PowerTop if this is a laptop
echo "(Powertop/TLP config) Is this a laptop? (yes/no)"
read is_laptop

if [ "$is_laptop" == "yes" ]; then
  sudo xbps-install -S tlp tlp-rdw powertop
  sudo ln -sv /etc/sv/tlp /var/service
  echo "tlp, tlp-rdw, and powertop Installed."
else
  echo "Skipping Laptop Power configuration."
fi

##
# Logging Daemon Activation
# Install a logging Daemon as void does not have one by default
echo "Logging Daemon Activation."

sudo xbps-install -Rs socklog-void
sudo ln -s /etc/sv/socklog-unix /var/service/
sudo ln -s /etc/sv/nanoklogd /var/service/

##
# Configure Profile Sync Daemon 
# set up profile sync daemon PSD is a service that symlinks & syncs browser profile
# directories to RAM, thus reducing HDD/SSD calls & speeding up browsers. You can get
# it from here. This helps Firefox & Chromium reduce ram usage.
echo "Configure Profile Sync Daemon."

git clone https://github.com/madand/runit-services
cd runit-services
sudo mv psd /etc/sv/
sudo ln -s /etc/sv/psd /var/service/
sudo chmod +x etc/sv/psd/*

##
# Install fonts 
echo "Installing Fonts."

sudo xbps-install -Rs noto-fonts-emoji noto-fonts-ttf noto-fonts-ttf-extra nerd-fonts

# Install Microsoft fonts for compatibility
git clone https://github.com/void-linux/void-packages
cd void-packages
./xbps-src binary-bootstrap
echo "XBPS_ALLOW_RESTRICTED=yes" >> etc/conf

##
# Install Syncthing and enable autostart
echo "Installing Syncthing."

sudo xbps-install -Rs syncthing
sudo cp /usr/share/applications/syncthing-start.desktop ~/.config/autostart/

