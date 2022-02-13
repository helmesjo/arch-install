#!/bin/sh

set -eu -o pipefail

cyn=$'\e[1;36m'
mag=$'\e[1;35m'
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;93m'
wht=$'\e[0m'

log() {
  paddingcolor=${cyn}
  textcolor="${2:-$cyn}"
  termwidth="$(tput cols)"
  padding="$(printf '%0.1s' -{1..500})"
  printf '%b%*.*s|%b%s%b|%*.*s%b\n' ${paddingcolor} 0 "$(((termwidth-6-${#1})/2))" "$padding" ${textcolor} "$1" ${paddingcolor} 0 "$(((termwidth-1-${#1})/2))" "$padding" ${wht}
}

log_result() {
  color="${3:-$mag}"
  termwidth="$(tput cols)"
  padding="$(printf '%0.1s' .{1..500})"
  printf '%b%s%*.*s%b%s%b\n' ${wht} "$1" 0 "$(( ${#1} < 26 ? 26-${#1} : 2))" "$padding" ${color} "$2" ${wht}
}

function log_error {
    log " INSTALLATION FAILED " ${red}
    read line file <<<$(caller)
    echo "An error occurred in line $line of file $file:" >&2
    sed "${line}q;d" "$file" >&2
    exit 1
}
trap log_error ERR

log_ok () {
  log " OK " ${grn}
}

wait_for_confirm () {
  prompt="${1:-"Press ENTER to continue..."}"
  printf "\n%s" ""
  read -p "$prompt"
  printf "\n%s" ""
}

printf "\n%s" ""
printf "\n%s" ""

log "‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾" ${cyn}
log "        ARCH LINUX INSTALL HELPER (EFI)   " ${cyn}
log "                                          " ${cyn}
log "     github.com/helmesjo/arch-install     " ${cyn}
log "                                          " ${cyn}
log "    NOTE: THIS CAN BREAK YOUR COMPUTER    " ${yel}
log "__________________________________________" ${cyn}

printf "\n%s" ""
printf "\n%s" ""

log " VERIFY INTERNET "

ping -c2 -W2000 archlinux.org

log_ok

log " OPTIONS "

ARCHINSTALL_devpackages="base-devel"
ARCHINSTALL_default_pacpackages="mesa xorg i3 lightdm-gtk-greeter pulseaudio-alsa noto-fonts noto-fonts-extra noto-fonts-emoji git kitty vim"
ARCHINSTALL_default_aurpackages="rlaunch siji-git polybar"
ARCHINSTALL_default_services="lightdm"
ARCHINSTALL_default_timezone="Europe/Amsterdam"
ARCHINSTALL_default_locale="sv_SE.UTF-8"
ARCHINSTALL_default_keymap="sv-latin1"
ARCHINSTALL_default_customsetup="https://github.com/helmesjo/dotfiles"
ARCHINSTALL_proceed="n"

read -p "Hostname: " ARCHINSTALL_hostname
read -p "Username: " ARCHINSTALL_username
read -p "$ARCHINSTALL_username pwd: " ARCHINSTALL_userpwd
read -p "Root pwd: " ARCHINSTALL_rootpwd
read -p "Timezone (default: $ARCHINSTALL_default_timezone): " ARCHINSTALL_timezone
ARCHINSTALL_timezone="${ARCHINSTALL_timezone:=$ARCHINSTALL_default_timezone}"
read -p "Locale (default: $ARCHINSTALL_default_locale): " ARCHINSTALL_locale
ARCHINSTALL_locale="${ARCHINSTALL_locale:=$ARCHINSTALL_default_locale}"
read -p "Keymap (default: $ARCHINSTALL_default_keymap): " ARCHINSTALL_keymap
ARCHINSTALL_keymap="${ARCHINSTALL_keymap:=$ARCHINSTALL_default_keymap}"

read -p "Pacman packages (default: $ARCHINSTALL_default_pacpackages): " ARCHINSTALL_pacpackages
ARCHINSTALL_pacpackages="${ARCHINSTALL_pacpackages:=$ARCHINSTALL_default_pacpackages}"

read -p "AUR packages (default: $ARCHINSTALL_default_aurpackages): " ARCHINSTALL_aurpackages
ARCHINSTALL_aurpackages="${ARCHINSTALL_aurpackages:=$ARCHINSTALL_default_aurpackages}"

read -p "Auto-enable services (default: $ARCHINSTALL_default_services): " ARCHINSTALL_services
ARCHINSTALL_services="${ARCHINSTALL_services:=$ARCHINSTALL_default_services}"

printf "%s\n" "Custom setup repo. Will clone & execute './setup.sh' as user '$ARCHINSTALL_username' (NOPASS)"
read -p "  URL: ('none' to skip, default: $ARCHINSTALL_default_customsetup): " ARCHINSTALL_customsetup
ARCHINSTALL_customsetup="${ARCHINSTALL_customsetup:=$ARCHINSTALL_default_customsetup}"

ARCHINSTALL_fdisklist=$(fdisk -l 2>&1)

ARCHINSTALL_disk=""
until sudo partprobe -d -s $ARCHINSTALL_disk >/dev/null 2>&1
do
  printf '\n%b%s%b\n\n' ${yel} "$ARCHINSTALL_fdisklist" ${wht}
  read -p "Select disk: " ARCHINSTALL_disk
done

ARCHINSTALL_cpu=""
while [[ "$ARCHINSTALL_cpu" != "amd" && "$ARCHINSTALL_cpu" != "intel" ]]
do
  read -p "CPU (amd or intel): " ARCHINSTALL_cpu
done

log " VERIFY OPTIONS "

log_result "Hostname" "$ARCHINSTALL_hostname" 
log_result "Username" "$ARCHINSTALL_username"
log_result "Timezone" "$ARCHINSTALL_timezone"
log_result "Root pwd" "$ARCHINSTALL_rootpwd"
log_result "User pwd" "$ARCHINSTALL_userpwd"
log_result "Pacman packages" "$ARCHINSTALL_pacpackages"
log_result "AUR packages" "$ARCHINSTALL_aurpackages"
log_result "Services" "$ARCHINSTALL_services"
log_result "Custom setup" "$ARCHINSTALL_customsetup (./setup.sh)"
log_result "CPU" "$ARCHINSTALL_cpu" ${yel}
log_result "Disk" "$ARCHINSTALL_disk" ${yel}
log_result "  Partition 1" "${ARCHINSTALL_disk}1: 550MB  GPT" ${yel}
log_result "  Partition 2" "${ARCHINSTALL_disk}2: 2GB    Linux swap" ${yel}
log_result "  Partition 3" "${ARCHINSTALL_disk}3: rest   Linux filsystem" ${yel}

wait_for_confirm
wait_for_confirm "Are you sure? If not, hit CTRL+C."

log " PARTITION DISK "

(
echo g # Create a new empty GPT partition table
# Create partitions (EFI, swap & root)
echo n # Add EFI partition
echo 1 # Partition number
echo   # First sector (accept default)
echo +550M # 550MB for EFI
echo n # Add swap partition
echo 2 # Partition number
echo   # First sector (accept default)
echo +2G  # 2GB for swap
echo n # Add root partition
echo 3 # Partition number
echo   # First sector (accept default)
echo   # Last sector (use remainder)
# Change partition types
echo t # Change type
echo 1 # Partition number
echo 1 # Partition type 'EFI System'
echo t # Change type
echo 2 # Partition number
echo 19 # Partition type 'Linux swap'
echo t # Change type
echo 3 # Partition number
echo 20 # Partition type 'Linux filesystem'
echo w # Write changes
) | fdisk $ARCHINSTALL_disk

log_ok

log " MAKE FILESYSTEMS "

mkfs.fat -F32 ${ARCHINSTALL_disk}1
mkswap ${ARCHINSTALL_disk}2
swapon ${ARCHINSTALL_disk}2
mkfs.ext4 ${ARCHINSTALL_disk}3

log_ok

log " MOUNT PARTITIONS "

mount ${ARCHINSTALL_disk}3 /mnt
mkdir /mnt/boot
mount ${ARCHINSTALL_disk}1 /mnt/boot

log_ok

log " INSTALL KERNEL "

pacstrap /mnt base linux linux-firmware

log_ok

log " GENERATE FILESYSTEM TABLE "

genfstab -U /mnt >> /mnt/etc/fstab

log_ok

cat <<EOF > /install-part2.sh
#!/bin/sh

set -eu -o pipefail

cyn=$'\e[1;36m'
mag=$'\e[1;35m'
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;93m'
wht=$'\e[0m'

log() {
  paddingcolor=\${cyn}
  textcolor="\${2:-\$cyn}"
  termwidth="\$(tput cols)"
  padding="\$(printf '%0.1s' -{1..500})"
  printf '%b%*.*s|%b%s%b|%*.*s%b\n' \${paddingcolor} 0 "\$(((termwidth-6-\${#1})/2))" "\$padding" \${textcolor} "\$1" \${paddingcolor} 0 "\$(((termwidth-1-\${#1})/2))" "\$padding" \${wht}
}

log_ok () {
  log " OK " \${grn}
}

function log_error {
  log " ERROR " \${red}
  read line file <<<\$(caller)
  echo "An error occurred in line \$line of file \$file:" >&2
  sed "\${line}q;d" "\$file" >&2
  exit 1
}
trap log_error ERR

disable_passwd () {
  sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
}

enable_passwd () {
  sed -i 's/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
}

log " SETUP TIMEZONE: $ARCHINSTALL_timezone "

ln -sf /usr/share/zoneinfo/$ARCHINSTALL_timezone /etc/localtime
hwclock --systohc

log " SETUP SYSTEM LOCALE: $ARCHINSTALL_locale "

sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#sv_SE.UTF-8 UTF-8/sv_SE.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

log_ok

echo LANG="en_US.UTF-8"                      >  /etc/locale.conf
echo LC_NUMERIC="$ARCHINSTALL_locale"        >> /etc/locale.conf
echo LC_TIME="$ARCHINSTALL_locale"           >> /etc/locale.conf
echo LC_MONETARY="$ARCHINSTALL_locale"       >> /etc/locale.conf
echo LC_PAPER="$ARCHINSTALL_locale"          >> /etc/locale.conf
echo LC_NAME="$ARCHINSTALL_locale"           >> /etc/locale.conf
echo LC_ADDRESS="$ARCHINSTALL_locale"        >> /etc/locale.conf
echo LC_TELEPHONE="$ARCHINSTALL_locale"      >> /etc/locale.conf
echo LC_MEASUREMENT="$ARCHINSTALL_locale"    >> /etc/locale.conf
echo LC_IDENTIFICATION="$ARCHINSTALL_locale" >> /etc/locale.conf

#echo LC_COLLATE="$ARCHINSTALL_locale""       >> /etc/locale.conf
#echo LANGUAGE="$ARCHINSTALL_locale""         >> /etc/locale.conf
#echo LC_CTYPE="$ARCHINSTALL_locale""         >> /etc/locale.conf
#echo LC_MESSAGES="$ARCHINSTALL_locale""      >> /etc/locale.conf

log " SETUP HOSTS "

echo $ARCHINSTALL_hostname > /etc/hostname
echo "127.0.0.1    localhost" >> /etc/hosts
echo "::1          localhost" >> /etc/hosts
echo "127.0.1.1    $ARCHINSTALL_hostname.localdomain    $ARCHINSTALL_hostname" >> /etc/hosts

log_ok

log " SETUP USERS "

(
echo $ARCHINSTALL_rootpwd
echo $ARCHINSTALL_rootpwd
) | passwd

useradd -m $ARCHINSTALL_username

(
echo $ARCHINSTALL_userpwd
echo $ARCHINSTALL_userpwd
) | passwd $ARCHINSTALL_username

usermod -aG wheel,audio,video,storage,optical $ARCHINSTALL_username

log_ok

pacman -S --noconfirm sudo
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

log_ok

log " SETUP BOOTLOADER "

pacman -S --noconfirm ${ARCHINSTALL_cpu}-ucode
pacman -S --noconfirm grub efibootmgr dosfstools os-prober mtools
grub-install --target=x86_64-efi --bootloader-id=grub_uefi --efi-directory=/boot --recheck
grub-mkconfig -o /boot/grub/grub.cfg

log_ok

log " INSTALL NETWORK MANAGER "

pacman -S --noconfirm networkmanager
systemctl enable NetworkManager

log_ok

log " INSTALL DEVELOPMENT PACKAGES: $ARCHINSTALL_devpackages "

pacman -S --noconfirm $ARCHINSTALL_devpackages

log_ok

log " INSTALL PACMAN PACKAGES: $ARCHINSTALL_pacpackages "

# Compile packages using all cores
sed -i 's/^#MAKEFLAGS=.*/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf

pacman -S --noconfirm $ARCHINSTALL_pacpackages

log_ok

# -----------------------------------
# Temporarily disable password prompt
disable_passwd

log " INSTALL AUR HELPER: yay "

su -c 'git clone https://aur.archlinux.org/yay /home/$ARCHINSTALL_username/git/yay' $ARCHINSTALL_username
su -c 'cd /home/$ARCHINSTALL_username/git/yay && makepkg -Acs --noconfirm' $ARCHINSTALL_username
pacman -U --noconfirm /home/$ARCHINSTALL_username/git/yay/*.pkg.tar.zst
rm -rf /home/$ARCHINSTALL_username/git

log_ok

log " INSTALL AUR PACKAGES: $ARCHINSTALL_aurpackages "

su -c 'yay -S --noconfirm $ARCHINSTALL_aurpackages' $ARCHINSTALL_username

log_ok

log " SETUP CONFIGURATION "

# Make git-credential-libsecret
if command -v git &> /dev/null
then
  (cd /usr/share/git/credential/libsecret && make)
fi

localectl set-keymap $ARCHINSTALL_keymap

# Clone custom setup repo & run expected setup.sh

su -c 'git clone $ARCHINSTALL_customsetup /home/$ARCHINSTALL_username/tmpcustomsetuprepo || true' $ARCHINSTALL_username

# Skip if url invalid & nothing was cloned (eg. user typed 'skip')
if [ -d "/home/$ARCHINSTALL_username/tmpcustomsetuprepo" ]; then
  echo "reponame=\`basename \$(git -C /home/$ARCHINSTALL_username/tmpcustomsetuprepo remote get-url origin) .git\`"
  git -C /home/$ARCHINSTALL_username/tmpcustomsetuprepo remote get-url origin
  reponame=\`basename \$(git -C /home/$ARCHINSTALL_username/tmpcustomsetuprepo remote get-url origin) .git\`
  echo \$reponame
  su -c 'mv /home/$ARCHINSTALL_username/tmpcustomsetuprepo /home/$ARCHINSTALL_username/\$reponame'
  su -c 'cd /home/$ARCHINSTALL_username/\$reponame && ./setup.sh' $ARCHINSTALL_username
fi

log_ok

log " ENABLE SERVICES: $ARCHINSTALL_services "

for service in ${ARCHINSTALL_services}; do
    systemctl enable \$service
done

log_ok

enable_passwd
# Re-enable password prompt
# -----------------------------------

exit 0
EOF

chmod +x /install-part2.sh
cp /install-part2.sh /mnt

log " ENTER CHROOT "
arch-chroot /mnt /bin/bash /install-part2.sh
log " EXIT CHROOT "

rm /mnt/install-part2.sh
rm /install-part2.sh

log " UNMOUNT "

umount -l /mnt/boot
umount -l /mnt

log_ok

log " INSTALLATION SUCCESSFUL " ${grn}

wait_for_confirm "Press ENTER to reboot..."

reboot
