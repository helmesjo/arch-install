#!/bin/sh

log() {
  termwidth="$(tput cols)"
  padding="$(printf '%0.1s' ={1..500})"
  printf '%*.*s %s %*.*s\n' 0 "$(((termwidth-2-${#1})/2))" "$padding" "$1" 0 "$(((termwidth-1-${#1})/2))" "$padding"
}

verify_success () {
  if [ "$?" = 0 ]
  then
    log "[OK]"
  else
    log "[FAILED]"
    exit 1
  fi
}

log "=="
log "DO NOT USE THIS"
log "IT CAN BREAK YOUR COMPUTER"
log "=="

printf "\n\n"

log "[VERIFY INTERNET]"

ping -c1 -W2000 archlinux.org 2>/dev/null 1>/dev/null

verify_success

printf "\n\n"

ARCHINSTALL_devpackages="base-devel git kitty vim"
ARCHINSTALL_wmpackages="mesa xorg i3 lightdm-gtk-greeter"
ARCHINSTALL_aurpackages="rlaunch"
ARCHINSTALL_services="lightdm"

read -p "Hostname: " ARCHINSTALL_hostname
read -p "Username: " ARCHINSTALL_username
read -p "Timezone (default: Europe/Amsterdam): " ARCHINSTALL_timezone
ARCHINSTALL_timezone="${ARCHINSTALL_timezone:=Europe/Amsterdam}"
read -p "Root pwd: " ARCHINSTALL_rootpwd
read -p "$ARCHINSTALL_username pwd: " ARCHINSTALL_userpwd
read -p "CPU (amd or intel): " ARCHINSTALL_cpu

printf "\n\n"

log "[PARTITION DISK]"

fdisk -l
read -p "Select disk: " ARCHINSTALL_disk

(
echo g # Create a new empty DOS partition table
echo n # Add EFI partition
echo 1 # Partition number
echo   # First sector (accept default)
echo +550M # 550MB for EFI
echo t # Change type
echo 1 # Partition number
echo 1 # Partition type 'EFI System'
echo n # Add swap partition
echo 2 # Partition number
echo   # First sector (accept default)
echo +2G  # 2GB for swap
echo t # Change type
echo 2 # Partition number
echo 19 # Partition type 'Linux swap'
echo n # Add root partition
echo 3 # Partition number
echo   # First sector (accept default)
echo   # Last sector (use remainder)
echo t # Change type
echo 3 # Partition number
echo 20 # Partition type 'Linux filesystem'
echo w # Write changes
) | fdisk $ARCHINSTALL_disk

verify_success

log "[MAKE FILESYSTEMS]"

mkfs.fat -F32 ${ARCHINSTALL_disk}1
mkswap ${ARCHINSTALL_disk}2
swapon ${ARCHINSTALL_disk}2
mkfs.ext4 ${ARCHINSTALL_disk}3

verify_success

log "[MOUNT PARTITIONS]"

mount ${ARCHINSTALL_disk}3 /mnt
mkdir /mnt/boot
mount ${ARCHINSTALL_disk}1 /mnt/boot

verify_success

log "[INSTALL KERNEL]"

pacstrap /mnt base linux linux-firmware

verify_success

log "[GENERATE FILESYSTEM TABLE]"

genfstab -U /mnt >> /mnt/etc/fstab

verify_success

log "[-> ENTER CHROOT /mnt]"

cat <<EOF > /install-part2.sh
#!/bin/sh

log() {
  termwidth="\$(tput cols)"
  padding="\$(printf '%0.1s' ={1..500})"
  printf '%*.*s %s %*.*s\n' 0 "\$(((termwidth-2-\${#1})/2))" "\$padding" "\$1" 0 "\$(((termwidth-1-\${#1})/2))" "\$padding"
}

verify_success () {
  if [ "\$?" = 0 ]
  then
    log "[OK]"
  else
    log "[FAILED]"
    exit 1
  fi
}

disable_passwd () {
  sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
}

enable_passwd () {
  sed -i 's/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
}

log "[SETUP LOCAL TIME & HW CLOCK]"

ln -sf /usr/share/zoneinfo/$ARCHINSTALL_timezone /etc/localtime
hwclock --systohc

verify_success

log "[SETUP SYSTEM LOCALE]"

sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#sv_SE.UTF-8 UTF-8/sv_SE.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

verify_success

log "[SETUP HOSTS]"

echo $ARCHINSTALL_hostname > /etc/hostname
echo "127.0.0.1    localhost" >> /etc/hosts
echo "::1          localhost" >> /etc/hosts
echo "127.0.1.1    $ARCHINSTALL_hostname.localdomain    $ARCHINSTALL_hostname" >> /etc/hosts

verify_success

log "[SETUP USERS]"

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

verify_success

pacman -S --noconfirm sudo
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

verify_success

log "[SETUP BOOTLOADER]"

pacman -S --noconfirm ${ARCHINSTALL_cpu}-ucode
pacman -S --noconfirm grub efibootmgr dosfstools os-prober mtools
grub-install --target=x86_64-efi --bootloader-id=grub_uefi --efi-directory=/boot --recheck

verify_success

grub-mkconfig -o /boot/grub/grub.cfg

verify_success

log "[INSTALL NETWORK MANAGER]"

pacman -S --noconfirm networkmanager
systemctl enable NetworkManager

verify_success

log "[INSTALL DEVELOPMENT PACKAGES: $ARCHINSTALL_devpackages]"

pacman -S --noconfirm $ARCHINSTALL_devpackages

verify_success

log "[INSTALL WINDOW PACKAGES: $ARCHINSTALL_wmpackages]"

pacman -S --noconfirm $ARCHINSTALL_wmpackages

verify_success

# -----------------------------------
# Temporarily disable password prompt
disable_passwd

log "[INSTALL AUR HELPER: yay]"

su -c 'git clone https://aur.archlinux.org/yay /home/$ARCHINSTALL_username/git/yay' $ARCHINSTALL_username
su -c 'cd /home/$ARCHINSTALL_username/git/yay && makepkg -Acs --noconfirm' $ARCHINSTALL_username
pacman -U --noconfirm /home/$ARCHINSTALL_username/git/yay/*.pkg.tar.zst

verify_success

rm -rf /home/$ARCHINSTALL_username/git

log "[INSTALL AUR PACKAGES: $ARCHINSTALL_aurpackages]"

su -c 'yay -S --noconfirm $ARCHINSTALL_aurpackages' $ARCHINSTALL_username
verify_success

enable_passwd
# Re-enable password prompt
# -----------------------------------

log "[SETUP CONFIGURATION]"

# clone dotfiles etc.

verify_success

log "[ENABLE SERVICES: $ARCHINSTALL_services]"

for service in ${ARCHINSTALL_services}; do
    systemctl enable \$service
done

verify_success

log "[<- EXIT CHROOT /mnt]"
exit 0
EOF

chmod +x /install-part2.sh
cp /install-part2.sh /mnt
arch-chroot /mnt /bin/bash /install-part2.sh
rm /mnt/install-part2.sh
rm /install-part2.sh

log "[UNMOUNT]"

umount -l /mnt/boot
umount -l /mnt

verify_success

printf "\n\n"

log "[INSTALLATION DONE]"

read -p "DONE! Reboot? (y/n): " ARCHINSTALL_reboot

if [ "$ARCHINSTALL_reboot" = "y" ]
then
  reboot
fi

exit 0