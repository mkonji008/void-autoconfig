#!/bin/bash
##
tput setaf 1
echo "Void Linux autoconfig by mkonji."
tput sgr0
tput setaf 3
sudo -v

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
if sudo xbps-install -Suvy; then
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
fi

##
# Enable nonfree repositories
echo "Enable non-free repositories."
sudo xbps-install -Sy void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree && \
echo "Non-Free repos enabled." || 
echo "Error enabling non-free repos."

##
# Install essential packages
echo "Installing essential packages."
sudo xbps-install -Sy vim mkfontdir curl wget xz unzip zip vim gptfdisk xtools mtools mlocate ntfs-3g fuse-exfat bash-completion linux-headers gtksourceview4 ffmpeg mesa-vdpau mesa-vaapi htop neofetch timeshift ranger && \
echo "Essential packages installed." || \
echo "Error installing essential packages."

##
# Install developer Packages
echo "Installing developer packages."
sudo xbps-install -Sy autoconf automake bison m4 make libtool flex meson ninja optipng sassc python python3 python3-piph&& \
echo "Developer packages installed." || \
echo "Error installing developer packages."

##
# Install security
echo "Installing security packages."
sudo xbps-install -Sy gpg gpg2 yadm pass && \
echo "Installation of security packages complete." || \
echo "Error installing security packages."

##
# Install xorg, dbus and elogind and enable their services
echo "Installing xorg, dbus, and elogind and enabling services."
sudo xbps-install -Sy xorg dbus elogind && \
sudo ln -s /etc/sv/dbus /var/service/ && \
sudo ln -s /etc/sv/elogind /var/service/ && \
echo "Installation and configuration completed" || \
echo "Error installing/enabling xorg, dbus and elogind."

##
# Install SpaceVim
echo "Installing SpaceVim."
if curl -sLf https://spacevim.org/install.sh | bash; then
  echo "SpaceVim installed successfully."
else
  echo "Error installing SpaceVim. Exiting."
  exit 1
fi

# Create .SpaceVim.d directory if it does not exist
if [ ! -d "$HOME/.SpaceVim.d" ]; then
  mkdir "$HOME/.SpaceVim.d"
fi

# Copy init.toml to .SpaceVim.d
if cp SpaceVim/init.toml "$HOME/.SpaceVim.d/init.toml"; then
  echo "init.toml copied to .SpaceVim.d successfully."
else
  echo "Error copying init.toml. Exiting."
  exit 1
fi

echo "SpaceVim set up successfully."

## Install WM/DE
#
echo "Enter 'i3', 'bspwm', 'gnome', or 'kde' to install the corresponding window manager: "
read -r wm
echo "Now Installing and Configuring $wm."
cd ~/git/void-autoconfig
# Install selected window manager and copy configuration file
if [ "$wm" == "i3" ]; then
  sudo xbps-install -Sy i3
  mkdir ~/.config/i3
  cp i3/config ~/.config/i3/config
  mkdir ~/.config/polybar
  cp polybar/config.ini ~/.config/polybar/config.ini
elif [ "$wm" == "bspwm" ]; then
  sudo xbps-install -Sy bspwm sxhkd polybar
  cp bspwm/config ~/.config/bspwm/config
elif [ "$wm" == "gnome" ]; then
  sudo xbps-install -Sy gnome gdm
  sudo ln -s /etc/sv/gdm /var/service
  sudo xbps-install -Rsy xdg-desktop-portal xdg-desktop-portal-gtk xdg-user-dirs xdg-user-dirs-gtk xdg-utils
elif [ "$wm" == "kde" ]; then
  sudo xbps-install -Sy kde
else
  echo "Invalid input. Exiting."
  exit 1
fi

# Check for package list file
if [ -f "packages/pkgslist-$wm.txt" ]; then
  # Install packages from package list file
  while read -r pkg; do
    sudo xbps-install -Sy "$pkg"
  done < "packages/pkgslist-$wm.txt"
fi

echo "WM/DE Installation complete, moving onto next step."

##
# Pull void-src and configure it
# Clone Void Linux source code repository
if git clone https://github.com/void-linux/void-packages.git; then
  echo "Void Linux source code repository cloned."
else
  echo "Error cloning Void Linux source code repository. Exiting."
  exit 1
fi

# Change to void-packages directory
cd void-packages

# Run binary-bootstrap script
if ./xbps-src binary-bootstrap; then
  echo "Binary bootstrap completed successfully."
else
  echo "Error running binary-bootstrap script. Exiting."
  exit 1
fi

echo "Void Linux source repository set up successfully."

##
# Create home folders 
echo "Creating home folder structure."

# Create array of folder names
folders=(Documents Music Pictures Videos)

# Loop through array and create each folder
for folder in "${folders[@]}"; do
  if mkdir "$HOME/$folder"; then
    echo "$folder directory created."
  else
    echo "Error creating $folder directory. Exiting."
    exit 1
  fi
done

echo "Home directory folders created successfully."

## 
# Display Configuration
# Prompt for what display adapter to install, install it and it's mircrocode
# After installing the driver check what display adapter is used and add the tearfree option to the xorg.conf file
echo "Enter 'intel' to install Intel drivers and microcode, 'amd' to install AMD drivers and microcode, or 'nvidia' to install NVIDIA drivers: "
read -r drivers

if [ "$drivers" == "intel" ]; then
  sudo xbps-install -Sy xf86-video-intel linux-firmware-intel intel-ucode mesa-dri vulkan-loader mesa-vulkan-intel intel-video-accel
elif [ "$drivers" == "amd" ]; then
  sudo xbps-install -Sy linux-firmware-amd xf86-video-amdgpu amd-ucode mesa-dri vulkan-loader mesa-vulkan-radeon mesa-vaapi mesa-vdpau
elif [ "$drivers" == "nvidia" ]; then
  sudo xbps-install -Sy nvidia nvidia-settings
else
  echo "Invalid input. Exiting."
  exit 1
fi

echo "Display adapter successfully installed."

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
read -r is_laptop

if [ "$is_laptop" == "yes" ]; then
  sudo xbps-install -Sy tlp tlp-rdw powertop
  sudo ln -sv /etc/sv/tlp /var/service
  echo "tlp, tlp-rdw, and powertop Installed."
else
  echo "Skipping Laptop Power configuration."
fi

##
# Logging Daemon Activation
# Install a logging Daemon as void does not have one by default
echo "Logging Daemon Activation."
sudo xbps-install -Rsy socklog-void && \
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
sudo xbps-install -Rsy noto-fonts-emoji noto-fonts-ttf noto-fonts-ttf-extra nerd-fonts && \
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
sudo xbps-install -Rsy syncthing && \
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
if sudo xbps-install -Sy bluez bluez-utils blueman; then
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

echo "Bluetooth installation adn configuration complete."

##
# Configuring wallpaper 
echo "Setting wallpaper."

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

echo "Wallpaper set successfully."

##
# Install Flatpak package manager
echo "Installing Flatpak package manager."
if sudo xbps-install -Sy flatpak; then
  echo "Flatpak installed."
else
  echo "Error installing Flatpak. Exiting."
  exit 1
fi

# Add Flathub repository
if flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; then
  echo "Flathub repository added."
else
  echo "Error adding Flathub repository. Exiting."
  exit 1
fi

echo "Flatpak and Flathub repository set up successfully."

##
# Install Nix package manager
echo "Installing Nix package manager."

if sudo xbps-install -Sy nix; then
  echo "Nix installed."
else
  echo "Error installing Nix. Exiting."
  exit 1
fi

# Add Nix daemon
if sudo ln -s /etc/sv/nix-daemon /var/service/; then
  echo "Nix daemon added."
else
  echo "Error adding Nix daemon. Exiting."
  exit 1
fi

# Source profile to pick up changes
if source /etc/profile; then
  echo "Profile sourced."
else
  echo "Error sourcing profile. Exiting."
  exit 1
fi

# Add all Nix channels
if nix-channel --add https://nixos.org/channels/nixpkgs-unstable unstable && \
   nix-channel --add https://nixos.org/channels/nixos-22.05 nixpkgs && \
   nix-channel --update && \
   nix-channel --list; then
  echo "Nix channels added."
else
  echo "Error adding Nix channels. Exiting."
  exit 1
fi

# Create symlink to applications directory
if sudo ln -s "$HOME/.nix-profile/share/applications" "$HOME/.local/share/applications/nix-env"; then
  echo "Symlink to applications directory created."
else
  echo "Error creating symlink to applications directory. Exiting."
  exit 1
fi

echo "Nix package manager set up successfully."

exit
