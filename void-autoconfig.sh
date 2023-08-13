#!/bin/bash
##
tput setaf 1
echo "Void Linux autoconfig by mkonji."
sleep 2
tput sgr0
tput setaf 2
sudo -v

# Redirect output of the script to a log file
exec > >(tee logfile.txt)

# Prompt the user to enter the username
read -p "Enter the username: " user_name
# Confirm the username
echo "So, you are $user_name, correct? (yes/no) "
read -r usn_verify

echo "Checking internet access"
sleep 2
# Check if there is internet access
if ping -c 1 google.com &>/dev/null; then
	# There is internet access, continue
	echo "Internet access is available."
else
	# There is no internet access, exit
	echo "Internet access is not available."
	exit 1
fi
echo "This will only continue if there is internet access."

##
echo "Installing xbps package manager,updating system, adding nonfree repos and installing some base packages."
sleep 1
# Update the xbps package manager
if sudo xbps-install -Syu xbps; then
	echo "Installed/Updated xbps."
else
	echo "Error installing/updating xbps. Exiting."
	exit 1
fi
# Update Void Linux
if sudo xbps-install -Suvy; then
	echo "Updating Void Linux."
else
	echo "Error updating Void Linux. Exiting."
	exit 1
fi
# Restart services post system update
if sudo xcheckrestart; then
	echo "Restarting updated services."
else
	echo "Error restarting services. Exiting."
	exit 1
fi
# Enable nonfree repositories
echo "Enabling non-free repositories."
sudo xbps-install -Sy void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree &&
	echo "Non-Free repos enabled." ||
	echo "Error enabling non-free repos."
# Install essential packages
echo "Installing base system packages."
sudo xbps-install -Sy libltdl libltdl-32bit curl wget xz unzip zip cfdisk xtools mtools mlocate ntfs-3g fuse-exfat bash-completion linux-headers gtksourceview4 ffmpeg mesa-vdpau mesa-vaapi htop neofetch timeshift ranger &&
	echo "Essential packages installed." ||
	echo "Error installing essential packages."
# Install essential packages
if [ ! -f packages/main_packages.txt ]; then
	echo "The main_packages.txt file does not exist."
	exit 1
fi
main_packages=$(cat packages/main_packages.txt)
for main_pkgs in $main_packages; do
	xbps-install -Sy $main_pkgs
	echo "Main system packages installed."
done
sleep 1

##
# Install developer Packages
echo "Installing dev doodads."
sudo xbps-install -Sy autoconf automake make libtool optipng sassc python python3 python3-pip &&
	echo "Developer packages installed." ||
	echo "Error installing developer packages."

##
echo "Installing ohmybash and copying .bashrc"
rm /home/$user_name/.bashrc
if [ -d /home/$user_name/.oh-my-bash ]; then
	rm -rf /home/$user_name/.oh-my-bash
else
	echo "oh-my-bash directory does not exist, continuing oh-my-bash installation"
fi
if sudo -u $user_name curl -sLf https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | bash; then
	cp dotfiles/.bashrc /home/$user_name/.bashrc
	rm -rf .bashrc.omb-backup-*
	echo "oh-my-bash has been installed"
else
	echo "There has been an error installing oh-my-bash, exiting"
	exit 1
fi
sleep 1

if [ -f "packages/developer_packages.txt" ]; then
	read -p "Do you want to install developer doodads? (yes/no) " dev_doodads
	if [ "$dev_doodads" = "yes" ]; then
		while read devstuff; do
			xbps-install -Sy $devstuff
		done <developer_packages.txt
		echo "Downloading Go..."
		curl -OL https://golang.org/dl/go1.18.3.linux-amd64.tar.gz
		mv go*.tar.gz /home/$user_name/
		echo "Extracting Go..."
		tar -xzvf /home/$user_name/go*.tar.gz
		rm -rf /home/$user_name/go*.tar.gz
		echo "Setting Gopath..."
		sudo -u $user_name export GOPATH=$user_name/go
		echo "Adding Go to the PATH..."
		sudo -u $user_name echo "export PATH=$PATH:$GOPATH/bin" >>/home/$user_name/.bashrc
		source /home/$user_name/.bashrc
		echo "Go has been installed."
	else
		echo "Guess you did not want to install the developer doodads, exiting."
	fi
else
	echo "The developer_packages.txt file does not exist, exiting."
	exit 1
fi
echo "Developer doodads installed"
sleep 1

##
# opendoas config
# vars set at beginning of script
echo "Setting up doas, minimal sudo alternative"
sudo xbps-install -Sy opendoas
# Check if the file does not exist
if [ ! -f /etc/doas.conf ]; then
	# Read and verify the username
	while [[ $usn_verify != "yes" ]] && [[ $usn_verify != "no" ]]; do
		echo "Please enter yes or no."
		read -r usn_verify
	done
	# Create the doas.conf file
	if [[ $usn_verify == "yes" ]]; then
		sudo echo "permit persist $user_name as root" >/etc/doas.conf
		echo "opendoas has been configured for $user_name"
	else
		echo "The doas.conf file was not created."
	fi
else
	echo "The doas.conf file already exists, skipping."
fi
sleep 1

##
# Install NeoVim
# install prerequsite
if sudo xbps-install -Sy ripgrep neovim; then
	echo "Installed/Updated ripgrep."
else
	echo "Error installing/updating ripgrep prerequsite. Exiting."
	exit 1
fi
# Create nvim directory if it does not exist
if [ ! -d "/home/$user_name/.config/nvim" ]; then
	mkdir /home/$user_name/.config/nvim
fi
echo "Configuring best editor."
# Copy nvim configuration
if cp -r dotfiles/nvim/ /home/$user_name/.config/nvim/; then
	echo "Copied NeoVim dots successfully."
else
	echo "Error copying nvim dots. Exiting."
	exit 1
fi
echo "NeoVim set up successfully."
sleep 1

## Install WM/DE
#
echo "Enter 'i3' or 'xfce' to install the DE/WM"
read -r wm
echo "Now Installing and Configuring $wm."
# Install selected window manager and copy configuration file
if [ "$wm" == "i3" ]; then
	sudo xbps-install -Sy i3
	mkdir /home/$user_name/.config/i3
	cp dotfiles/i3/config /home/$user_name/.config/i3/config
	mkdir /home/$user_name/.config/i3status
	cp dotfiles/i3status/config /home/$user_name/.config/i3status/config
elif [ "$wm" == "xfce" ]; then
	# xfce not really setup yet, needs some additonal love
	sudo xbps-install -Sy xfce4
else
	echo "Invalid input. Exiting."
	exit 1
fi
# Check for package list file
if [ -f "packages/pkgslist_$wm.txt" ]; then
	# Install packages from package list file
	while read -r pkg; do
		sudo xbps-install -Sy "$pkg"
	done <"packages/pkgslist_$wm.txt"
fi
echo "WM/DE Installation complete, moving onto next step."
sleep 1

##
# Create home folders
echo "Creating home folder structure."
# Create array of folder names
folders=(Documents Music Pictures Videos Downloads code git)
# Loop through array and create each folder
for folder in "${folders[@]}"; do
	if mkdir "/home/$user_name/$folder"; then
		echo "$folder directory created."
	else
		echo "Error creating $folder directory. Exiting."
		exit 1
	fi
done
sleep 1
##
# copy dotfiles for xfce4-terminal
echo "Copy dotfiles for xfce4-terminal."
if [ ! -d /home/$user_name/.config/xfce4/terminal ]; then
	mkdir /home/$user_name/.config/xfce4/terminal
fi
cp -r dotfiles/xfce4/terminal /home/$user_name/.config/xfce4/terminal
##
# Display Configuration
# Prompt for what display adapter to install, install it and it's mircrocode
# After installing the driver check what display adapter is used and add the tearfree option to the xorg.conf file
echo "Enter 'intel' to install Intel display and microcode, 'amd' to install AMD display and microcode, or 'nvidia' to install NVIDIA drivers: "
read -r drivers
if [ "$drivers" == "intel" ]; then
	sudo xbps-install -Sy xf86-video-intel linux-firmware-intel intel-ucode mesa-dri vulkan-loader mesa-vulkan-intel intel-video-accel
elif [ "$display" == "amd" ]; then
	sudo xbps-install -Sy linux-firmware-amd xf86-video-amdgpu amd-ucode mesa-dri vulkan-loader mesa-vulkan-radeon mesa-vaapi mesa-vdpau
elif [ "$drivers" == "nvidia" ]; then
	sudo xbps-install -Sy nvidia nvidia-libs nvidia-libs-32bit nvidia-firmware nvidia-dkms nvidia-gtklibs
else
	echo "Invalid input. Exiting."
	exit 1
fi
echo "Display adapter successfully installed."
sleep 1
if [ "$drivers" = "nvidia" ]; then
	# The drivers are nvidia, ask the user if they want to copy a configuration and a file
	read -p "Do you want to copy the nvidia configuration for longboi monitor (yes/no) " longboi
	if [ "$longboi" = "yes" ]; then
		# Copy the nvidia configuration
		cp dotfiles/.nvidia-settings-rc /home/$user_name/.nvidia-settings-rc
		cp dotfiles/.screenlayout.sh /home/$user_name/.config/.screenlayout.sh
		sudo chmod u+x /home/$user_name/.config/.screenlayout.sh
		echo "longboi monitor configured"
	fi
else
	echo "Not using longboi I suppose?, continuing with the script."
fi

# Check if the Xorg configuration file exists
if [ ! -f "/etc/X11/xorg.conf" ]; then
	# Create the Xorg configuration file if it does not exist
	echo "Section \"Device\"" >>/etc/X11/xorg.conf
	echo "    Identifier  \"Graphics Adapter\"" >>/etc/X11/xorg.conf
	echo "    Driver      \"$display\"" >>/etc/X11/xorg.conf
	echo "    Option      \"TearFree\"    \"true\"" >>/etc/X11/xorg.conf
	echo "EndSection" >>/etc/X11/xorg.conf
else
	# Check if the NoTear option is already set in the Xorg configuration file
	if ! grep -q "Option      \"TearFree\"" /etc/X11/xorg.conf; then
		# Add the NoTear option if it is not set
		sed -i '/Identifier/a \    Option      \"TearFree\"    \"true\"' /etc/X11/xorg.conf
	fi
fi
echo "NoTear option added to Xorg configuration file."
sleep 1

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
sleep 1
##
# copy fonts
echo "Installing Fonts."
sudo xbps-install -Rsy nerd-fonts anthy anthy-unicode ipafont-fonts-otf firefox-esr-i18n-ja ibus-anthy libanthy libanthy-unicode &&
	echo "Installed Fonts." ||
	echo "Error installing Fonts. Exiting." && exit 1
sleep 1

##
# Install Bluetooth Jazz
read -p "Do you want to install bluetooth and enable the service? (yes/no) " enable_bt
if [ "$enable_bt" = "yes" ]; then
	sudo xbps-install -Sy bluez bluez-alsa libbluetooth blueman
	sudo ln -s /etc/sv/bluetoothd /var/service/
	echo "Bluetooth installation and configuration complete."
else
	echo "Ok fine, you don't want to install bluetooth, continuing with the script."
fi
sleep 1
##
# Configuring wallpaper
echo "Setting wallpaper."
# Create Pictures/wallpaper directory if it does not exist
if [ ! -d /home/$user_name/Pictures/wallpaper ]; then
	mkdir -p /home/$user_name/Pictures/wallpaper
fi
# Copy wallpaper file to Pictures/wallpaper directory
if cp /dotfiles/wallpaper.png /home/$user_name/Pictures/wallpaper/wallpaper.png; then
	echo "Wallpaper copied to Pictures/wallpaper directory."
else
	echo "Error copying wallpaper. Exiting."
	exit 1
fi
# Set wallpaper with Nitrogen
if nitrogen --set-scaled /home/$user_name/Pictures/wallpaper/wallpaper.png; then
	echo "Wallpaper set with Nitrogen."
else
	echo "Error setting wallpaper with Nitrogen. Exiting."
	exit 1
fi
echo "Wallpaper set successfully."
sleep 1

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
sleep 1

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
if nix-channel --add https://nixos.org/channels/nixpkgs-unstable unstable &&
	nix-channel --add https://nixos.org/channels/nixos-22.05 nixpkgs &&
	nix-channel --update &&
	nix-channel --list; then
	echo "Nix channels added."
else
	echo "Error adding Nix channels. Exiting."
	exit 1
fi
# Create symlink to applications directory
if sudo ln -s "/home/$user_name/.nix-profile/share/applications" "/home/$user_name/.local/share/applications/nix-env"; then
	echo "Symlink to applications directory created."
else
	echo "Error creating symlink to applications directory. Exiting."
	exit 1
fi
echo "Nix package manager set up successfully. Now installing some nix packages."
sleep 1
if [ -x "$(which nix)" ]; then
	echo "nix verified to be installed, installing nix packages."
	sudo -u $user_name nix-env -iA nixpkgs.google-drive-ocamlfuse
else
	echo "nix package manager seems to not exist, skipping installation of nix packages"
fi

##
# install gamer goodies?
echo "Would you like to install sweaty gamer goodies? (yes/no)"
read -r gamer_goodies
if [ "$gamer_goodies" == "yes" ]; then
	sudo xbps-install -Sy steam lutris libgcc-32bit libstdc++-32bit libdrm-32bit libglvnd-32bit openmw cavestory dreamchess
	echo "enjoy procrastination"
else
	echo "skipping procrastination proclamation"
fi
sleep 1

##
# Install xorg, dbus and elogind and enable their services
echo "Installing xorg, dbus, and lightdm and enabling services."
sudo xbps-install -Sy xorg-minimal lightdm lightdm-gtk3-greeter &&
	sudo ln -s /etc/sv/dbus /var/service/ &&
	sudo ln -s /etc/sv/lightdm /var/service/ &&
	echo "Installation and configuration completed" ||
	echo "Error installing/enabling xorg, dbus and lightdm."
sleep 1

echo "Script has completed, see logfile.txt in this directory, please restart"
exit
