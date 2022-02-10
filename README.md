Arch Linux Install (EFI)

1. Set keyboard layout
    * `loadkeys sv-latin1`
2. Verify internet connection
    * `ping archlinux.org`
3. Ensure system clock is accurate
    * `timedatectl set-ntp true`
4. List disks and find which to partition (eg. `/dev/sda`)
    * `fdisk -l`
5. Create partitions
    1. `fdisk /dev/sda`
    2. Create partition table (GPT)
        * `g`
    3. Add partitions. Required
        * `n`:
          1. efi system partition (Type: "EFI System", Size: 550MB)
          2. swap partition (Type: "Linux Swap", Size: ~2GB)
          3. root (Type: Linux filesystem", Size: Remainder)
    4. Change partition types
        * `t`
          1. Partition 1 -> "EFI System" (option 1)
          2. Partition 2 -> "Linux swap" (option 19)
          3. Partition 3 -> "Linux filesystem" (option 20)
    5. `w`
      * Write table to disk.
6. Make filesystems
    1. mkfs.fat -F32 /dev/sda1
    2. mkswap /dev/sda2
    3. swapon /dev/sda2
    4. mkfs.ext4 /dev/sda3
7. Mount partitions
    * `mount /dev/sda3 /mnt`
    * `mount /dev/sda1 /mnt/boot`
8. Install base package, kernel and firmware
    * `pacstrap /mnt base linux linux-firmware`
9. Generate filesystem table
    * `genfstab -U /mnt >> /mnt/etc/fstab`
10. Root to mounted filesystem
    * `arch-chroot /mnt`
11. Setup timezone
    * `ln -sf /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime`
12. Set hardware clock
    * `hwclock --systohc`
13. Set system locale.
    * `sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen`
    * `sed -i 's/#sv_SE.UTF-8 UTF-8/sv_SE.UTF-8 UTF-8/' /etc/locale.gen`
14. Make locale & keyboard layout persistent
    1. `echo "LANG=sv_SE.UTF-8" >> /etc/locale.conf`
    2. `echo "KEYMAP=se-latin1" >> /etc/vconsole.conf`
15. `locale-gen`
    * Generate locales.
16. Set hostname
    * `echo <name> > /etc/hostname`
    * For scripting: 
        ```
        read -ep "Hostname: " ARCHINSTALL_hostname
        echo $ARCHINSTALL_hostname > /etc/hostname
        ```
17. Create hosts file.
    * `vim /etc/hosts`
    * For scripting:
        ```
        echo "127.0.0.1    localhost" >> /etc/hosts
        echo "::1          localhost" >> /etc/hosts
        echo "127.0.1.1    $ARCHINSTALL_hostname.localdomain    $ARCHINSTALL_hostname" >> /etc/hosts
        ```
18. Create users and passwords.
    1. `passwd`
        * Set root password.
    2. `useradd -m <name>`
    3. `passwd <name>`
        * Set user password.
    4. `usermod -aG wheel,audio,video,storage,optical <name>`
        * Add user to groups.
19. Enable `sudo` for users in `wheel` group.
    1. `pacman -S --noconfirm sudo`
    2. `sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers`
        * Allow users in group `wheel` to use `sudo`.
20. Setup boot loader.
    1. `pacman -S --noconfirm [amd-ucode|intel-ucode]`
    2. `pacman -S --noconfirm grub efibootmgr dosfstools os-prober mtools`
    5. `grub-install --target=x86_64-efi --bootloader-id=grub_uefi --efi-directory=/boot --recheck`
    6. `grub-mkconfig -o /boot/grub/grub.cfg`
21. Install network manager
    1. `pacman -S --noconfirm networkmanager`
    2. `systemctl enable NetworkManager`
23. Install development packages
    * `pacman -S --noconfirm base-devel git kitty vim`
23. Install `yay` (AUR helper)
    1. `mkdir ~/git && cd ~/git`
    2. `git clone https://aur.archlinux.org/yay && cd yay`
    3. `makepkg -sri`
22. Install Window & Display Manager, and set key layout for system (x11)
    1. `pacman -S --noconfirm mesa xorg i3 lightdm-gtk-greeter`
    2. `systemctl enable lightdm`
    3. `localectl set-x11-keymap se`
24. Setup dotfiles
    1. `cd ...`
24. Exit chroot, unmount & reboot
    1. `exit`
    2. `umount -l /mnt/boot`
    3. `umount -l /mnt`
    4. `reboot`