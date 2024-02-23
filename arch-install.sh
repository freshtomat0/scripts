#! /usr/bin/sh


# ask for some variables

echo "Please enter EFI partition (example: /dev/sda1 or /dev/nvme0n1p1)"
read EFI

echo "Please enter SWAP partition (example: /dev/sda2 or /dev/nvme0n1p2)"
read SWAP

echo "Please enter ROOT partition (example: /dev/sda3 or /dev/nvme0n1p3)"
read ROOT

echo "Do you want to have a HOME partition? (1 yes / 0 no)"
read IFHOME

if [[$IFHOME == '1']];
then
	echo "Please enter HOME partition (example: /dev/sda4 or /dev/nvme0n1p4)"
	read HOME
fi

echo "Please enter your username:"
read USERNAME

echo "please enter your password:"
read PASSWORD

echo "Please select TYPE of install:"
echo "0. No desktop environment / window manager"
echo "1. i3wm + lightdm"
read INSTALLTYPE

# make filesystems
echo -e "\nCreating Filesystems...\n"

mkfs.vfat -F32 -n "EFISYSTEM" "${EFI}"
mkswap "${SWAP}"
swapon "${SWAP}"
mkfs.ext4 -L "ROOT" "${ROOT}"

if [[$IFHOME == '1']];
then
	mkfs.ext4 -L "HOME" "${HOME}"
fi

# mount target
mount -t ext4 "${ROOT}" /mnt
mkdir /mnt/boot
mount -t vfat "${EFI}" /mnt/boot/

if [[$IFHOME == '1']];
then
	mkdir /mnt/home
	mount "${HOME}" /mnt/home
fi

echo "INSTALLING Arch Linux BASE on Main Drive"
pacstrap /mnt base base-devel --noconfirm --needed	# --needed only installs what is not already installed

# kernel
pacstrap /mnt linux linux-firmware --noconfirm --needed

echo  "Setup Dependencies"
pacstrap /mnt networkmanager network-manager-applet wireless_tools nano vim intel-ucode bluez bluez-utils blueman git --noconfirm --needed

# fstab
genfstab -U /mnt >> /mnt/etc/fstab


echo "--------------------------------------"
echo "-- Bootloader Installation  --"
echo "--------------------------------------"
bootctl install --path /mnt/boot
echo "default arch.conf" >> /mnt/boot/loader/loader.conf
cat <<EOF > /mnt/boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=${ROOT} rw
EOF


cat <<NEXT > /mnt/next.sh

useradd -m $USER
usermod -aG wheel,storage,power,audio $USER
echo $USER:$PASSWORD | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "-------------------------------------------------"
echo "Setup Language to US and set locale"
echo "-------------------------------------------------"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf

ln -sf /usr/share/zoneinfo/Asia/Kathmandu /etc/localtime
hwclock --systohc

echo "arch" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1	localhost
::1			localhost
127.0.1.1	arch.localdomain	arch
EOF

echo "-------------------------------------------------"
echo "Display and Audio Drivers"
echo "-------------------------------------------------"

pacman -S xorg pulseaudio --noconfirm --needed
pacman -S nitrogen alsa-utils pavucontrol --noconfirm --needed


systemctl enable NetworkManager bluetooth

#DESKTOP ENVIRONMENT
if [[ $DESKTOP == '0' ]]
then 
    echo "You have choosen to Install Desktop Yourself"
elif [[ $DESKTOP == '1' ]]
then
    pacman -S lightdm i3-wm i3lock i3status i3blocks lightdm-slick-greeter --noconfirm --needed
		systemctl enable lightdm
fi

# additional packages
echo "Installing additional packages"
pacman -S firefox lxappearance rofi dmenu terminator --noconfirm -needed

echo "-------------------------------------------------"
echo "Install Complete, You can reboot now"
echo "-------------------------------------------------"

EOF

NEXT

arch-chroot /mnt sh next.sh
