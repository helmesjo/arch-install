#!/bin/bash
set -eu -o pipefail

export cyn=$'\e[1;36m'
export mag=$'\e[1;35m'
export red=$'\e[1;31m'
export grn=$'\e[1;32m'
export yel=$'\e[1;93m'
export dyel=$'\e[0;93m'
export wht=$'\e[0m'
export ARCHINSTALL_duration=0
export ARCHINSTALL_showduration=false

log() {
  paddingcolor=${cyn}
  textcolor="${2:-$cyn}"
  termwidth="$(tput cols)"

  if [ "$ARCHINSTALL_showduration" = true ]; then
    ARCHINSTALL_duration=$(($ARCHINSTALL_duration+$SECONDS))
    duration=" $(date +%T -d "1/1 + $ARCHINSTALL_duration sec")"
    if [ $SECONDS -gt 0 ]; then
      SECONDS=0
    fi
  else
    duration=""
  fi
  text=$1
  if [ ${#text} -gt 64 ]; then
   text="$(echo $text | cut -c -64)..."
  fi

  padding="$(printf '%0.1s' -{1..500})"
  paddingformat_lhs="$((((termwidth-${#text})/2-1)))"
  paddingformat_rhs="$((((termwidth-${#text}+1)/2-1)-${#duration}-1))"
  printf '%b%*.*s|%b%s%b|%*.*s|%b%s\n' ${paddingcolor} 0 $paddingformat_lhs "$padding" ${textcolor} "$text" ${paddingcolor} 0 "$paddingformat_rhs" "$padding" ${wht} "$duration"
}
export -f log

log_result() {
  color="${3:-$mag}"
  termwidth="$(tput cols)"
  padding="$(printf '%0.1s' .{1..500})"
  printf '%b%s%*.*s%b%s%b\n' ${wht} "$1" 0 "$(( ${#1} < 26 ? 26-${#1} : 2))" "$padding" ${color} "$2" ${wht}
}
export -f log_result

log_error() {
  log " INSTALLATION FAILED " ${red}
  read line file <<<$(caller)
  echo "An error occurred in line $line of file $file:" >&2
  sed "${line}q;d" "$file" >&2
  exit 1
}
trap log_error ERR
export -f log_error

log_ok () {
  log " OK " ${grn}
}
export -f log_ok

wait_for_confirm () {
  prompt="${1:-"Continue?"}"
  printf "\n%b%s%b" ${cyn} "$prompt [y/n]: " ${wht}
  read -p "" ARCHINSTALL_reply
  if [ "$ARCHINSTALL_reply" != "y" ]; then
    exit 1
  fi
  printf "\n%s" ""
}
export -f wait_for_confirm

printf "\n%s" ""
printf "\n%s" ""

log "‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾" ${cyn}
log "      ARCH LINUX INSTALL HELPER (EFI)     " ${cyn}
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

export ARCHINSTALL_devpackages="base-devel git"
export ARCHINSTALL_default_pacpackages=""
export ARCHINSTALL_default_timezone="Europe/Amsterdam"
export ARCHINSTALL_default_locale="sv_SE.UTF-8"
export ARCHINSTALL_default_keymap="sv-latin1"
export ARCHINSTALL_default_customsetup="https://github.com/helmesjo/dotfiles"

echo ""

export ARCHINSTALL_hostname
printf "%b%s%b" ${cyn} "Hostname: " ${wht}
read ARCHINSTALL_hostname

export ARCHINSTALL_username
printf "%b%s%b" ${cyn} "Username: " ${wht}
read ARCHINSTALL_username

export ARCHINSTALL_userpwd
printf "%b%s%b" ${cyn} "$ARCHINSTALL_username pwd: " ${wht}
read ARCHINSTALL_userpwd

export ARCHINSTALL_rootpwd
printf "%b%s%b" ${cyn} "Root pwd: " ${wht}
read ARCHINSTALL_rootpwd

printf "%b%s%b" ${cyn} "Timezone (default: $ARCHINSTALL_default_timezone): " ${wht}
read ARCHINSTALL_timezone
export ARCHINSTALL_timezone="${ARCHINSTALL_timezone:=$ARCHINSTALL_default_timezone}"

printf "%b%s%b" ${cyn} "Locale (default: $ARCHINSTALL_default_locale): " ${wht}
read ARCHINSTALL_locale
export ARCHINSTALL_locale="${ARCHINSTALL_locale:=$ARCHINSTALL_default_locale}"

printf "%b%s%b" ${cyn} "Keymap (default: $ARCHINSTALL_default_keymap): " ${wht}
read ARCHINSTALL_keymap
export ARCHINSTALL_keymap="${ARCHINSTALL_keymap:=$ARCHINSTALL_default_keymap}"

printf "%b%s%b" ${cyn} "Pacman packages (default: $ARCHINSTALL_default_pacpackages): " ${wht}
read ARCHINSTALL_pacpackages
export ARCHINSTALL_pacpackages="${ARCHINSTALL_pacpackages:=$ARCHINSTALL_default_pacpackages}"

printf "%b%s\n  %s%b" ${cyn} "Custom setup repo. Will clone & execute './setup.sh' as user '$ARCHINSTALL_username' (NOPASS)" "URL: ('none' to skip, default: $ARCHINSTALL_default_customsetup): " ${wht}
read ARCHINSTALL_customsetup
export ARCHINSTALL_customsetup="${ARCHINSTALL_customsetup:=$ARCHINSTALL_default_customsetup}"

export ARCHINSTALL_cpu=""
while [[ "$ARCHINSTALL_cpu" != "amd" && "$ARCHINSTALL_cpu" != "intel" ]]
do
  printf "%b%s%b" ${cyn} "CPU (amd or intel): " ${wht}
  read ARCHINSTALL_cpu
done

export ARCHINSTALL_disk=""

# Filter out & print disks of interest (ignore loop devices)
ARCHINSTALL_fdisklist=$(fdisk -l | grep 'Disk /dev' | sed '/loop/d')
until partprobe -d -s $ARCHINSTALL_disk >/dev/null 2>&1
do
  # Print disk info
  while IFS= read -r disk;
  do
    diskname=$(echo "$disk" | awk '{print $2}' | sed 's/://')
    disk_info=$(fdisk -l $diskname | sed '/Disk \/dev/d' | sed 's/^/  /')
    printf '%b%s\n%b%s%b\n' ${yel} "$disk" ${dyel} "$disk_info" ${wht}
  done <<< "$ARCHINSTALL_fdisklist"

  printf "%b%s%b" ${cyn} "Select disk: " ${wht}
  read ARCHINSTALL_disk
done

# Check if selected disk already has a partition table
if [ "$(fdisk $ARCHINSTALL_disk -l | grep 'Disklabel type:' | awk '{print $3}')" != "" ]; then
  wait_for_confirm "$ARCHINSTALL_disk contains data which will be erased. Proceed anyways?"
fi

log " VERIFY OPTIONS "

log_result "Hostname" "$ARCHINSTALL_hostname" 
log_result "Username" "$ARCHINSTALL_username"
log_result "Root pwd" "$ARCHINSTALL_rootpwd"
log_result "User pwd" "$ARCHINSTALL_userpwd"
log_result "Timezone" "$ARCHINSTALL_timezone"
log_result "Locale" "$ARCHINSTALL_locale"
log_result "Keymap" "$ARCHINSTALL_keymap"
log_result "Pacman packages" "$ARCHINSTALL_pacpackages"
log_result "Custom setup" "$ARCHINSTALL_customsetup (./setup.sh)"
log_result "CPU" "$ARCHINSTALL_cpu" ${yel}
log_result "Disk" "$ARCHINSTALL_disk" ${yel}
log_result "  Partition 1" "${ARCHINSTALL_disk}1: 550MB  EFI System" ${yel}
log_result "  Partition 2" "${ARCHINSTALL_disk}2: 2GB    Linux swap" ${yel}
log_result "  Partition 3" "${ARCHINSTALL_disk}3: rest   Linux filsystem" ${yel}

wait_for_confirm
wait_for_confirm "Start installation?"

# Reset timer
SECONDS=0
ARCHINSTALL_duration=0
ARCHINSTALL_showduration=true

log " PARTITION DISK "

ARCHINSTALL_diskpartitioncount=$(lsblk $ARCHINSTALL_disk | grep 'part' | wc -l || echo 0)
# Erase existing partitions (if any)
for i in $(seq 1 $ARCHINSTALL_diskpartitioncount)
do
  parted $ARCHINSTALL_disk rm $i
done

parted $ARCHINSTALL_disk mklabel gpt
parted $ARCHINSTALL_disk mkpart "\"EFI System\"" fat32 1MiB 551MiB         # 550MB for EFI
parted $ARCHINSTALL_disk set 1 esp on                                  # Flag as EFI
parted $ARCHINSTALL_disk mkpart "\"Linux swap\"" linux-swap 551MiB 4551MiB # 4GB for swap
parted $ARCHINSTALL_disk mkpart "root" ext4 4551MiB 100%               # Rest for root

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

cat <<"EOF" > /install-part2.sh
#!/bin/bash
set -eu -o pipefail
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

log_ok

log " SETUP SYSTEM LOCALE: $ARCHINSTALL_locale "

sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#sv_SE.UTF-8 UTF-8/sv_SE.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

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

echo KEYMAP="$ARCHINSTALL_keymap"             >  /etc/vconsole.conf
localectl set-keymap $ARCHINSTALL_keymap

log_ok

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

# Compile packages using all cores
sed -i 's/^#MAKEFLAGS=.*/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf

pacman -S --noconfirm $ARCHINSTALL_devpackages

log_ok

if test -n "${ARCHINSTALL_pacpackages-}"; then
  log " INSTALL PACMAN PACKAGES: $ARCHINSTALL_pacpackages "

  pacman -S --noconfirm $ARCHINSTALL_pacpackages

  log_ok
fi

# -----------------------------------
# Temporarily disable password prompt
disable_passwd

log " CUSTOM SETUP "

# Clone custom setup repo & run expected setup.sh

reponame=$(basename $ARCHINSTALL_customsetup)
repodir="/home/$ARCHINSTALL_username/$reponame"
su -c "cd /home/$ARCHINSTALL_username && git clone $ARCHINSTALL_customsetup $repodir || true" $ARCHINSTALL_username

# Skip if url invalid & nothing was cloned (eg. user typed 'skip'), or setup.sh not found.
if [ -f $repodir/setup.sh ]; then
  log " RUNNING $repodir/setup.sh... " ${mag}
  su -c "cd $repodir && ./setup.sh" $ARCHINSTALL_username
else
  log " SKIPPING CUSTOM SETUP: '$repodir/setup.sh' not found " ${yel}
fi

log_ok

enable_passwd
# Re-enable password prompt
# -----------------------------------

exit 0
EOF

chmod +x /install-part2.sh
cp /install-part2.sh /mnt

log " ENTER CHROOT " ${mag}
arch-chroot /mnt /bin/bash /install-part2.sh
log " EXIT CHROOT " ${mag}

rm /mnt/install-part2.sh
rm /install-part2.sh

log " UNMOUNT "

umount -l /mnt/boot
umount -l /mnt

log_ok

log " INSTALLATION SUCCESSFUL " ${grn}

wait_for_confirm "Reboot?"

reboot
