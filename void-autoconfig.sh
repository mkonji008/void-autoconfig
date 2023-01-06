#!/bin/bash
##
echo "Void Linux autoconfig By-mkonji "

# Redirect output of the script to a log file
exec > >(tee logfile.txt)

##
# Update the xbps package manager 
if sudo xbps-install -Syu xbps; then
  echo "Installed/Updated xbps."
else
  echo "Error installing/updating xbps. Exiting."
  exit 1
fi

##
# Update Void Linux
if sudo xbps-install -Suv; then
  echo "Updating Void Linux."
else
  echo "Error updating Void Linux. Exiting."
  exit 1
fi

##
# Restart services post system update
if sudo xcheckrestart; then
  echo "Restarting updated services."
else
  echo "Error restarting services. Exiting."
  exit 1

##
# Enable nonfree repositories
sudo xbps-install void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree
echo "Enable non-free repositories."
sudo xbps-install void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree && \
echo "Developer packages installed." || \
echo "Error enabling non-free repos. Exiting." && exit 1

##
# Install essential packages
echo "Installing essential packages."
sudo xbps-install -S vim curl wget xz unzip zip vim gptfdisk xtools mtools mlocate ntfs-3g fuse-exfat bash-completion linux-headers gtksourceview4 ffmpeg mesa-vdpau mesa-vaapi htop neofetch timeshift ranger && \
echo "Developer packages installed." || \
echo "Error installing essential packages. Exiting." && exit 1

##
# Install developer Packages
echo "Installing developer packages."
sudo xbps-install -S autoconf automake bison m4 make libtool flex meson ninja optipng sassc python python3 python3-piph&& \
echo "Developer packages installed." || \
echo "Error installing developer packages. Exiting." && exit 1

##
# Install security
echo "Installing security packages."
sudo xbps-install -S gpg gpg2 yadm pass && \
echo "Installation of security packages complete." || \
echo "Error installing security packages. Exiting." && exit 1

##
# Install xorg, dbus and elogind and enable their services
echo "Installing xorg, dbus, and elogind and enabling services."
sudo xbps-install -S xorg dbus elogind && \
sudo ln -s /etc/sv/dbus /var/service/ && \
sudo ln -s /etc/sv/elogind /var/service/ && \
echo "Installation and configuration completed" || \
echo "Error. Exiting." && exit 1

##
# Install SpacevVim
echo "Instaling SpaceVim."

curl -sLf https://spacevim.org/install.sh | bash
cp SpaceVim/init.toml ~/.SpaceVim.d/init.toml

echo "SpaceVim Installed. Please run vim post script completion to auto install plugins"

## Install WM/DE
#
echo "Enter 'i3', 'bspwm', 'gnome', or 'kde' to install the corresponding window manager: "
read wm
echo "Now Installing and Configuring $wm."
cd ~/git/void-autoconfig
# Install selected window manager and copy configuration file
if [ "$wm" == "i3" ]; then
  sudo xbps-install -S i3
  mkdir ~/.config/i3
  cp i3/config ~/.config/i3/config
  mkdir ~/.config/polybar
  cp polybar/config.ini ~/.config/polybar/config.ini
elif [ "$wm" == "bspwm" ]; then
  sudo xbps-install -S bspwm sxhkd polybar
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
if [ -f "packages/pkgslist-$wm.txt" ]; then
  # Install packages from package list file
  while read pkg; do
    sudo xbps-install -S "$pkg"
  done < "packages/pkgslist-$wm.txt"
fi

echo "WM/DE Installation complete, moving onto next step."

##
# Pull void-src and configure it
git clone https://github.com/void-linux/void-packages.git
cd void-packages
./xbps-src binary-bootstrap

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

sudo xbps-install -y cronie && \
sudo ln -sv /etc/sv/cronie /var/service/ && \
echo "Installation of Cronie completed." || \
echo "Error installing and enabling Cronie service. Exiting." && exit 1

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
sudo xbps-install -Rs socklog-void && \
sudo ln -s /etc/sv/socklog-unix /var/service/ && \
sudo ln -s /etc/sv/nanoklogd /var/service/ && \
echo "Successfully installed and configured Cronie." || \
echo "Error installing and enabling Cronie service. Exiting." && exit 1

##
# Configure Profile Sync Daemon 
# set up profile sync daemon PSD is a service that symlinks & syncs browser profile
# directories to RAM, thus reducing HDD/SSD calls & speeding up browsers. You can get
# it from here. This helps Firefox & Chromium reduce ram usage.
echo "Pull and Configure Profile Sync Daemon."
git clone https://github.com/madand/runit-services && \
cd runit-services && \
sudo mv psd /etc/sv/ && \
sudo ln -s /etc/sv/psd /var/service/ && \
sudo chmod +x etc/sv/psd/* && \
echo "Successfully installed and configured Profile Sync Daemon." || \
echo "Failure installing and configuring Profile Sync Daemon. Exiting." && exit 1

##
# Install fonts 
echo "Installing Fonts."
sudo xbps-install -Rs noto-fonts-emoji noto-fonts-ttf noto-fonts-ttf-extra nerd-fonts && \
echo "Installed Noto and Nerd Fonts." || \
echo "Error installing Noto and Nerd Fonts. Exiting." && exit 1

# Install Microsoft fonts for compatibility
git clone https://github.com/void-linux/void-packages
cd void-packages
./xbps-src binary-bootstrap
echo "XBPS_ALLOW_RESTRICTED=yes" >> etc/conf

##
# Install Syncthing and enable autostart
echo "Installing Syncthing." 
sudo xbps-install -Rs syncthing && \
sudo cp /usr/share/applications/syncthing-start.desktop ~/.config/autostart/ && \
echo "Installed Syncthing. Please configure manually." || \
echo "Failure to install Syncthing. Exiting." && exit 1

##
# Configure Fish Shell
cd ~/git/void-autoconfig
mkdir ~/.config/fish/
touch ~/.config/fish/config.fish
# Read alias definitions from a file and add them to the Fish shell config
while read -r alias; do
  if echo "$alias" >> ~/.config/fish/config.fish; then
    echo "Alias added: $alias"
  else
    echo "Error adding alias: $alias"
  fi
done < fish-aliases.txt
echo "Aliases added."

##
# Install Bluetooth and GUI
if sudo xbps-install -S bluez bluez-utils blueman; then
  echo "Bluetooth software and GUI installed."
else
  echo "Error installing Bluetooth packages and GUI. Exiting."
  exit 1
fi

# Enable Bluetooth service
if sudo ln -s /etc/sv/bluetoothd /var/service/; then
  echo "Bluetooth service enabled."
else
  echo "Error enabling Bluetooth service. Exiting."
  exit 1
fi

echo "Installation complete."

##
# Set wallpaper file path
wallpaper_path=~/git/void-autoconfig/wallpaper.png

# Create Pictures/wallpaper directory if it does not exist
if [ ! -d ~/Pictures/wallpaper ]; then
  mkdir -p ~/Pictures/wallpaper
fi

# Copy wallpaper file to Pictures/wallpaper directory
if cp "$wallpaper_path" ~/Pictures/wallpaper/; then
  echo "Wallpaper copied to Pictures/wallpaper directory."
else
  echo "Error copying wallpaper. Exiting."
  exit 1
fi

# Set wallpaper with Nitrogen
if nitrogen --set-scaled ~/Pictures/wallpaper/wallpaper.png; then
  echo "Wallpaper set with Nitrogen."
else
  echo "Error setting wallpaper with Nitrogen. Exiting."
  exit 1
fi

echo "Wallpaper set successfully.
"
