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
  local paddingcolor=${cyn}
  local textcolor="${2:-$cyn}"
  local termwidth="$(tput cols)"

  local duration=""
  if [ "$ARCHINSTALL_showduration" = true ]; then
    ARCHINSTALL_duration=$(($ARCHINSTALL_duration+$SECONDS))
    local duration=" $(date +%T -d "1/1 + $ARCHINSTALL_duration sec")"
    if [ $SECONDS -gt 0 ]; then
      SECONDS=0
    fi
  fi
  local text=$1
  if [ ${#text} -gt 64 ]; then
   text="$(echo $text | cut -c -64)..."
  fi

  local padding="$(printf '%0.1s' -{1..500})"
  local paddingformat_lhs="$((((termwidth-${#text})/2-1)))"
  local paddingformat_rhs="$((((termwidth-${#text}+1)/2-1)-${#duration}-1))"
  printf '%b%*.*s|%b%s%b|%*.*s|%b%s\n' ${paddingcolor} 0 $paddingformat_lhs "$padding" ${textcolor} "$text" ${paddingcolor} 0 "$paddingformat_rhs" "$padding" ${wht} "$duration"
}
export -f log

log_result() {
  local color="${3:-$mag}"
  local termwidth="$(tput cols)"
  local padding="$(printf '%0.1s' .{1..500})"
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
  local prompt="${1:-"Continue?"}"
  printf "\n%b%s%b" ${cyn} "$prompt [y/n]: " ${wht}
  read -p "" ARCHINSTALL_reply
  if [ "$ARCHINSTALL_reply" != "y" ]; then
    exit 1
  fi
  echo ""
}
export -f wait_for_confirm

read_input() {
  local prompt="${1:-""}"
  local default="${2:-}"
  local matcher=${3:-.*}

  if [ -n "$default" ]; then
    local defaultprompt=" (default: $default)"
  else
    local defaultprompt=""
  fi
  
  local ARCHINSTALL_reply
  while [ -z ${ARCHINSTALL_reply+x} ] || ! [[ "$ARCHINSTALL_reply" =~ $matcher ]]; do
    printf "%b%s%b%s" ${cyn} "$prompt" ${wht} "$defaultprompt: "
    read ARCHINSTALL_reply
  done
  
  retVal=${ARCHINSTALL_reply:=$default}
}
export -f read_input

echo ""
echo ""

log "‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾" ${cyn}
log "      ARCH LINUX INSTALL HELPER (EFI)     " ${cyn}
log "                                          " ${cyn}
log "     github.com/helmesjo/arch-install     " ${cyn}
log "                                          " ${cyn}
log "    NOTE: THIS CAN BREAK YOUR COMPUTER    " ${yel}
log "__________________________________________" ${cyn}

echo ""
echo ""

log " VERIFY INTERNET "

ping -c2 -W2000 archlinux.org

log_ok

log " OPTIONS "

export ARCHINSTALL_devpackages="base-devel git"
export ARCHINSTALL_default_pacpackages=""
export ARCHINSTALL_default_timezone="Europe/Amsterdam"
export ARCHINSTALL_default_locale="sv_SE.UTF-8"
export ARCHINSTALL_default_keymap="us"
export ARCHINSTALL_default_customsetup="https://github.com/helmesjo/dotfiles"
export ARCHINSTALL_bootsizeMB="550"
export ARCHINSTALL_swapsizeMB="4000"

echo ""

read_input "Hostname"
export ARCHINSTALL_hostname="$retVal"

read_input "Username"
export ARCHINSTALL_username="$retVal"

read_input "$ARCHINSTALL_username pwd"
export ARCHINSTALL_userpwd="$retVal"

read_input "Root pwd"
export ARCHINSTALL_rootpwd="$retVal"

read_input "Timezone" "$ARCHINSTALL_default_timezone"
export ARCHINSTALL_timezone="$retVal"

read_input "Locale" "$ARCHINSTALL_default_locale"
export ARCHINSTALL_locale="$retVal"

read_input "Keymap" "$ARCHINSTALL_default_keymap"
export ARCHINSTALL_keymap="$retVal"

read_input "Pacman packages" "$ARCHINSTALL_default_pacpackages"
export ARCHINSTALL_pacpackages="$retVal"

read_input "Custom setup repo" "$ARCHINSTALL_default_customsetup"
export ARCHINSTALL_customsetup="$retVal"

read_input "CPU [amd|intel]" "" "[amd|intel]"
export ARCHINSTALL_cpu="$retVal"

export ARCHINSTALL_disk=""
# Filter out & print disks of interest (ignore loop devices)
ARCHINSTALL_fdisklist=$(fdisk -l | grep 'Disk /dev' | sed '/loop/d')
# Loop until a valid disk has been selected
until partprobe -d -s "$ARCHINSTALL_disk" >/dev/null 2>&1
do
  # Print disk info
  while IFS= read -r disk;
  do
    diskname=$(echo "$disk" | awk '{print $2}' | sed 's/://')
    disk_info=$(fdisk -l $diskname | sed '/Disk \/dev/d' | sed 's/^/  /')
    printf '%b%s\n%b%s%b\n' ${yel} "$disk" ${dyel} "$disk_info" ${wht}
  done <<< "$ARCHINSTALL_fdisklist"

  read_input "Select disk"
  ARCHINSTALL_disk="$retVal"
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
log_result "  Partition 1" "EFI System        ${ARCHINSTALL_bootsizeMB}MB" ${yel}
log_result "  Partition 2" "Linux swap        ${ARCHINSTALL_swapsizeMB}MB" ${yel}
log_result "  Partition 3" "Linux filsystem   rest" ${yel}

wait_for_confirm "Correct?"
wait_for_confirm "Start installation?"

# Reset timer
SECONDS=0
ARCHINSTALL_duration=0
ARCHINSTALL_showduration=true

log " PARTITION DISK "

# Find and erase any existing partition(s) & disk label (extract partition numbers)
ARCHINSTALL_existingdiskpartitionnumbers=($(fdisk $ARCHINSTALL_disk -l | tail +10 | awk '{print $1}' | awk '{print substr($1, length, 1)}' | xargs))
for partnr in ${ARCHINSTALL_existingdiskpartitionnumbers[@]}; do
  parted $ARCHINSTALL_disk rm $partnr
done
wipefs --all --force $ARCHINSTALL_disk

parted $ARCHINSTALL_disk mklabel gpt
parted $ARCHINSTALL_disk mkpart "\"EFI System\"" fat32 1MiB ${ARCHINSTALL_bootsizeMB}MiB            # EFI
parted $ARCHINSTALL_disk set 1 esp on                                                               # Flag as EFI
parted $ARCHINSTALL_disk mkpart "\"Linux swap\"" linux-swap $((${ARCHINSTALL_bootsizeMB}+1))MiB $((${ARCHINSTALL_swapsizeMB} + ${ARCHINSTALL_bootsizeMB}))MiB # Swap
parted $ARCHINSTALL_disk mkpart "root" ext4 $((${ARCHINSTALL_swapsizeMB} + ${ARCHINSTALL_bootsizeMB} + 1))MiB 100%                   # Rest for root

# Extract new partition devices (full path, eg. '/dev/sda0')
ARCHINSTALL_newdiskpartitions=($(fdisk $ARCHINSTALL_disk -l | tail +10 | awk '{print $1}' | xargs))

log_ok

log " MAKE FILESYSTEMS "

mkfs.fat -F32 ${ARCHINSTALL_newdiskpartitions[0]}
mkswap ${ARCHINSTALL_newdiskpartitions[1]}
swapon ${ARCHINSTALL_newdiskpartitions[1]}
mkfs.ext4 ${ARCHINSTALL_newdiskpartitions[2]}

log_ok

log " MOUNT PARTITIONS "

mount ${ARCHINSTALL_newdiskpartitions[2]} /mnt
mkdir /mnt/boot
mount ${ARCHINSTALL_newdiskpartitions[0]} /mnt/boot

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

log " PACMAN UPGRADE "

pacman -Sy --noconfirm archlinux-keyring && pacman -Su --noconfirm

log_ok

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

pacman -S --needed --noconfirm sudo
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

log_ok

log " SETUP BOOTLOADER "

pacman -S --needed --noconfirm ${ARCHINSTALL_cpu}-ucode
pacman -S --needed --noconfirm grub efibootmgr dosfstools os-prober mtools
grub-install --target=x86_64-efi --bootloader-id=grub_uefi --efi-directory=/boot --recheck
grub-mkconfig -o /boot/grub/grub.cfg

log_ok

log " INSTALL NETWORK MANAGER "

pacman -S --needed --noconfirm iwd networkmanager
echo [device]            > /etc/NetworkManager/conf.d/wifi_backend.conf
echo "wifi.backend=iwd" >> /etc/NetworkManager/conf.d/wifi_backend.conf

systemctl enable iwd
systemctl enable NetworkManager

log_ok

log " INSTALL DEVELOPMENT PACKAGES: $ARCHINSTALL_devpackages "

# Compile packages using all cores
sed -i 's/^#MAKEFLAGS=.*/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf

pacman -S --needed --noconfirm $ARCHINSTALL_devpackages

log_ok

if test -n "${ARCHINSTALL_pacpackages-}"; then
  log " INSTALL PACMAN PACKAGES: $ARCHINSTALL_pacpackages "

  pacman -S --needed --noconfirm $ARCHINSTALL_pacpackages

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

log " CLEAN UP UNUSED PACKAGES "

pacman -Qtdq | pacman --noconfirm -Rns - 2>/dev/null || true

log_ok

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

wait_for_confirm "Shutdown now? Note: Eject install medium before booting."

shutdown now

