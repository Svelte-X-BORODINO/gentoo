#!/bin/bash
# GENTOO HARDCORE INSTALLER vMBR-OpenRC
# MBR + OpenRC = ИДЕАЛЬНАЯ КОМБО

set -e

# Конфиг
DISK="/dev/sda"
STAGE3_URL="https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64-openrc.tar.xz"
HOSTNAME="gentoo-openrc"

echo "🔥 GENTOO MBR + OpenRC MASTER"
echo "=============================="

# 1. ЧИСТИМ ДИСК
echo "💀 Wiping $DISK..."
dd if=/dev/zero of=$DISK bs=512 count=1 2>/dev/null

# 2. РАЗМЕТКА MBR
echo "📀 Partitioning MBR style..."
fdisk $DISK << EOF
o
n
p
1

+512M
a
1
n
p
2


w
EOF

# 3. ФАЙЛОВЫЕ СИСТЕМЫ
echo "📁 Formatting..."
mkfs.ext4 ${DISK}1  # /boot
mkfs.ext4 ${DISK}2  # /

# 4. МОНТИРУЕМ
echo "📂 Mounting..."
mount ${DISK}2 /mnt/gentoo
mkdir -p /mnt/gentoo/boot
mount ${DISK}1 /mnt/gentoo/boot

# 5. STAGE3 С OpenRC (уже в названии!)
echo "📦 Downloading OpenRC stage3..."
cd /mnt/gentoo
wget -q --show-progress $STAGE3_URL -O stage3.tar.xz

echo "📂 Extracting..."
tar xpf stage3.tar.xz --xattrs-include='*.*' --numeric-owner
rm -f stage3.tar.xz

# 6. БАЗОВАЯ КОНФИГУРАЦИЯ
echo "⚙️  Basic config..."
cp /etc/resolv.conf etc/
echo "Europe/Moscow" > etc/timezone
echo "$HOSTNAME" > etc/hostname

# FSTAB
genfstab -U /mnt/gentoo >> etc/fstab

# 7. CHROOT И УСТАНОВКА
echo "🔁 Chrooting..."
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys  
mount --rbind /dev /mnt/gentoo/dev

chroot /mnt/gentoo /bin/bash << CHROOT_EOF
# Обновляем окружение
env-update
source /etc/profile

# Портедж
emerge-webrsync

# Профиль (OpenRC по умолчанию!)
eselect profile set default/linux/amd64/17.1/desktop

# Локали
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen  
locale-gen
eselect locale set en_US.utf8

# ⚡ БИНАРНОЕ ЯДРО
echo "⚡ Installing gentoo-kernel-bin..."
emerge -q sys-kernel/gentoo-kernel-bin

# СЕТЬ (OpenRC сервис!)
echo "🌐 Installing network..."
emerge -q net-misc/dhcpcd
rc-update add dhcpcd default

# 🎯 MBR ЗАГРУЗЧИК
echo "👢 Installing GRUB for MBR..."
emerge -q sys-boot/grub
grub-install $DISK
grub-mkconfig -o /boot/grub/grub.cfg

# OpenRC СЕРВИСЫ
echo "🔄 Enabling OpenRC services..."
rc-update add sshd default
rc-update add cronie default

# ПОЛЬЗОВАТЕЛЬ
echo "👤 Setting root password..."
echo "root:gentoo" | chpasswd

# ЧИСТКА
echo "🧹 Cleaning..."
emerge --depclean
CHROOT_EOF

# 8. ФИНАЛ
echo "🎉 PURE GENTOO INSTALLED!"
echo "💻 Hostname: $HOSTNAME"  
echo "🔑 Root password: gentoo"
echo "💾 Boot: MBR (no systemd crap!)"
echo "🔄 Init: OpenRC (the right way!)"
echo "🐧 Kernel: gentoo-kernel-bin"
echo "🚀 Reboot and enjoy REAL Linux!"

# Отмонтируем
umount -l /mnt/gentoo/dev{/shm,/pts,}
umount -R /mnt/gentoo

echo "✅ Done. Remove live media and reboot to OpenRC paradise!"
