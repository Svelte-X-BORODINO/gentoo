#!/bin/bash

# --- Конфигурация ---
DISK="/dev/sda"           # Жёсткий диск
USER="miska"              # Имя пользователя
PASSWORD="miska"          # Пароль (user + root)
TIMEZONE="Europe/Moscow"  # Часовой пояс
HOSTNAME="gentoo"      # Имя компьютера

# --- Проверка на root ---
[ "$(id -u)" != "0" ] && { echo -e "\033[31mОШИБКА: Запусти от root!\033[0m"; exit 1; }

# --- Разметка диска (GPT/UEFI) ---
echo -e "\033[32m=== Автоустановка Gentoo ===\033[0m"
echo -e "\033[33m[1/6] Разметка диска...\033[0m"
parted $DISK --script mklabel gpt
parted $DISK --script mkpart primary fat32 1MiB 512MiB
parted $DISK --script set 1 esp on
parted $DISK --script mkpart primary ext4 512MiB 100%
mkfs.fat -F32 ${DISK}1
mkfs.ext4 ${DISK}2
mount ${DISK}2 /mnt
mkdir -p /mnt/boot/efi
mount ${DISK}1 /mnt/boot/efi

# --- Загрузка Stage3 (последняя версия) ---
echo -e "\033[33m[2/6] Загрузка Stage3...\033[0m"
STAGE_URL="https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64-openrc.txt"
wget $(curl -s $STAGE_URL | grep -o 'https://.*stage3.*\.tar\.xz' | head -1) -O /mnt/stage3.tar.xz
tar xpvf /mnt/stage3.tar.xz -C /mnt --xattrs-include='*.*' --numeric-owner

# --- Настройка базовой системы ---
echo -e "\033[33m[3/6] Настройка системы...\033[0m"
cp /etc/resolv.conf /mnt/etc/
mount -t proc /proc /mnt/proc
mount --rbind /sys /mnt/sys
mount --rbind /dev /mnt/dev

# --- Chroot-скрипт для автоматической настройки ---
cat > /mnt/auto-setup.sh << 'EOF'
#!/bin/bash

# Настройка локалей и времени
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
echo "Europe/Moscow" > /etc/timezone

# Настройка make.conf
cat > /etc/portage/make.conf << 'MAKE_EOF'
COMMON_FLAGS="-pipe -O2 -march=native"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
MAKEOPTS="-j$(nproc)"
ACCEPT_LICENSE="*"
FEATURES="parallel-fetch parallel-install"
MAKE_EOF

# Обновление системы
emerge-webrsync
emerge --sync
emerge -avuDN @world

# Установка ядра (минимальное)
emerge --ask sys-kernel/gentoo-kernel
emerge --ask sys-kernel/linux-firmware

# Настройка сети
echo "hostname=\"$HOSTNAME\"" > /etc/conf.d/hostname
emerge --ask net-misc/dhcpcd
rc-update add dhcpcd default

# Настройка загрузчика (GRUB)
emerge --ask sys-boot/grub
grub-install $DISK
grub-mkconfig -o /boot/grub/grub.cfg

# Создание пользователя
useradd -m -G wheel,audio,video,usb $USER
echo "$USER:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd

# Включение sudo
emerge --ask app-admin/sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Очистка
rm /auto-setup.sh
EOF

# --- Запуск chroot и автоматической настройки ---
echo -e "\033[33m[4/6] Запуск автоматической настройки...\033[0m"
chmod +x /mnt/auto-setup.sh
chroot /mnt /bin/bash /auto-setup.sh

# --- Установка графики (опционально) ---
echo -e "\033[33m[5/6] Установка графической среды...\033[0m"
cat > /mnt/post-install.sh << 'EOF'
#!/bin/bash
emerge --ask x11-base/xorg-server
emerge --ask kde-plasma/plasma-meta
rc-update add dbus default
rc-update add sddm default
EOF
chmod +x /mnt/post-install.sh
chroot /mnt /bin/bash /post-install.sh

# --- Завершение ---
echo -e "\033[32m[6/6] Установка завершена!\033[0m"
echo "Перезагрузись и войди под пользователем $USER:"
echo "  reboot"
echo "Для установки дополнительных пакетов:"
echo "  emerge --ask <package>"
