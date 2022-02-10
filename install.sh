#!/bin/sh

# ------------------------ DO NOT USE THIS!
# ------------------------ IT WILL PROBABLY BREAK YOUR COMPUTER!

printf "\n[VERIFY INTERNET]\n"

ping -c1 -W2000 archlinux.org 2>/dev/null 1>/dev/null

if [ "$?" = 0 ]
then
  printf "\n[OK]\n"
else
  printf "\n[FAILED]\n"
  exit 1
fi

read -p "Hostname: " ARCHINSTALL_hostname
read -p "Username: " ARCHINSTALL_username
read -p "Keymap (default: sv-latin1): " ARCHINSTALL_keymap
ARCHINSTALL_keymap="${ARCHINSTALL_keymap:=sv-latin1}"
read -p "Timezone (default: Europe/Amsterdam): " ARCHINSTALL_timezone
ARCHINSTALL_timezone="${ARCHINSTALL_timezone:=Europe/Amsterdam}"
read -p "Root pwd: " ARCHINSTALL_rootpwd
read -p "$ARCHINSTALL_username pwd: " ARCHINSTALL_userpwd
read -p "CPU (amd or intel): " ARCHINSTALL_cpu

fdisk -l
read -p "Select disk: " ARCHINSTALL_disk

loadkeys $ARCHINSTALL_keymap

printf "\n[PARTITION DISK]\n"

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

if [ "$?" = 0 ]
then
  printf "\n[OK]\n"
else
  printf "\n[FAILED]\n"
  exit 1
fi

printf "\n[MAKE FILESYSTEMS]\n"

mkfs.fat -F32 ${ARCHINSTALL_disk}1
mkswap ${ARCHINSTALL_disk}2
swapon ${ARCHINSTALL_disk}2
mkfs.ext4 ${ARCHINSTALL_disk}3

if [ "$?" = 0 ]
then
  printf "\n[OK]\n"
else
  printf "\n[FAILED]\n"
  exit 1
fi

printf "\n[MOUNT PARTITIONS]\n"

mount ${ARCHINSTALL_disk}3 /mnt
mkdir /mnt/boot
mount ${ARCHINSTALL_disk}1 /mnt/boot

if [ "$?" = 0 ]
then
  printf "\n[OK]\n"
else
  printf "\n[FAILED]\n"
  exit 1
fi

printf "\n[INSTALL KERNEL]\n"

pacstrap /mnt base linux linux-firmware

if [ "$?" = 0 ]
then
  printf "\n[OK]\n"
else
  printf "\n[FAILED]\n"
  exit 1
fi

printf "\n[GENERATE FILESYSTEM TABLE]\n"

genfstab -U /mnt >> /mnt/etc/fstab

if [ "$?" = 0 ]
then
  printf "\n[OK]\n"
else
  printf "\n[FAILED]\n"
  exit 1
fi

printf "\n[-> ENTER CHROOT /mnt]\n"

cat <<EOF > /install-part2.sh
if [ "$?" = 0 ]
then
  printf "\n[OK]\n"
else
  printf "\n[FAILED]\n"
  exit 1
fi

printf "\n[SETUP LOCAL TIME & HW CLOCK]\n"

ln -sf /usr/share/zoneinfo/$ARCHINSTALL_timezone /etc/localtime

if [ "$?" = 0 ]
then
  printf "\n[OK]\n"
else
  printf "\n[FAILED]\n"
  exit 1
fi
hwclock --systohc

printf "\n[SETUP SYSTEM LOCALE]\n"

sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#sv_SE.UTF-8 UTF-8/sv_SE.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

if [ "$?" = 0 ]
then
  printf "\n[OK]\n"
else
  printf "\n[FAILED]\n"
  exit 1
fi

printf "\n[SETUP HOSTNAME & HOSTS]\n"

echo $ARCHINSTALL_hostname > /etc/hostname
echo "127.0.0.1    localhost" >> /etc/hosts
echo "::1          localhost" >> /etc/hosts
echo "127.0.1.1    $ARCHINSTALL_hostname.localdomain    $ARCHINSTALL_hostname" >> /etc/hosts

if [ "$?" = 0 ]
then
  printf "\n[OK]\n"
else
  printf "\n[FAILED]\n"
  exit 1
fi

printf "\n[SETUP root & '$ARCHINSTALL_username']\n"

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

if [ "$?" = 0 ]
then
  printf "\n[OK]\n"
else
  printf "\n[FAILED]\n"
  exit 1
fi

pacman -S --noconfirm sudo
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

if [ "$?" = 0 ]
then
  printf "\n[OK]\n"
else
  printf "\n[FAILED]\n"
  exit 1
fi

printf "\n[SETUP BOOTLOADER]\n"

pacman -S --noconfirm ${ARCHINSTALL_cpu}-ucode
pacman -S --noconfirm grub efibootmgr dosfstools os-prober mtools
grub-install --target=x86_64-efi --bootloader-id=grub_uefi --efi-directory=/boot --recheck

if [ "$?" = 0 ]
then
  printf "\n[OK]\n"
else
  printf "\n[FAILED]\n"
  exit 1
fi

grub-mkconfig -o /boot/grub/grub.cfg

if [ "$?" = 0 ]
then
  printf "\n[OK]\n"
else
  printf "\n[FAILED]\n"
  exit 1
fi

printf "\n[INSTALL NETWORK MANAGER]\n"

pacman -S --noconfirm networkmanager
systemctl enable NetworkManager

if [ "$?" = 0 ]
then
  printf "\n[OK]\n"
else
  printf "\n[FAILED]\n"
  exit 1
fi

printf "\n[INSTALL WINDOW MANAGER]\n"

pacman -S --noconfirm mesa xorg i3 lightdm-gtk-greeter
systemctl enable lightdm
#localectl set-x11-keymap se # not working in arch-chroot ?

if [ "$?" = 0 ]
then
  printf "\n[OK]\n"
else
  printf "\n[FAILED]\n"
  exit 1
fi

printf "\n[INSTALL DEVELOPMENT PACKAGES]\n"

pacman -S --noconfirm base-devel git kitty vim

if [ "$?" = 0 ]
then
  printf "\n[OK]\n"
else
  printf "\n[FAILED]\n"
  exit 1
fi

printf "\n[INSTALL YAY (AUR)]\n"

#mkdir home/$ARCHINSTALL_username/git && cd home/$ARCHINSTALL_username/git
#git clone https://aur.archlinux.org/yay && cd yay
#sudo -H -u $ARCHINSTALL_username makepkg -sri

if [ "$?" = 0 ]
then
  printf "\n[OK]\n"
else
  printf "\n[FAILED]\n"
  exit 1
fi

printf "\n[SETUP CONFIGURATION]\n"

# clone dotfiles etc.

if [ "$?" = 0 ]
then
  printf "\n[OK]\n"
else
  printf "\n[FAILED]\n"
  exit 1
fi

printf "\n[<- EXIT CHROOT /mnt]\n"
exit 0
EOF

chmod +x /install-part2.sh
cp /install-part2.sh /mnt
arch-chroot /mnt /bin/bash /install-part2.sh
rm /mnt/install-part2.sh
rm /install-part2.sh

printf "\n[UNMOUNT & REBOOT]\n"

umount -l /mnt/boot
umount -l /mnt

if [ "$?" = 0 ]
then
  printf "\n[OK]\n"
else
  printf "\n[FAILED]\n"
  exit 1
fi

read -p "DONE! Press ENTER to reboot." ARCHINSTALL_tmp

reboot
