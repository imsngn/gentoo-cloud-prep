#!/bin/bash

# Set timezone
echo 'UTC' > /etc/timezone

# Set locale
echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
echo 'en_US ISO-8859-1' >> /etc/locale.gen
locale-gen
eselect locale set en_US.utf8

# Some rootfs stuff
grep -v rootfs /proc/mounts > /etc/mtab

# This is set in rackspaces prep, might help us
echo 'net.ipv4.conf.eth0.arp_notify = 1' >> /etc/sysctl.conf
echo 'vm.swappiness = 0' >> /etc/sysctl.conf

# Let's configure out grub
mkdir /boot/grub
echo 'GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8"' >> /etc/default/grub
grub2-mkconfig -o /boot/grub/grub.cfg
sed -r -i 's/loop[0-9]+p1/vda2/g' /boot/grub/grub.cfg
sed -i 's/UUID=[a-z,0-9,-]*/\/dev\/vda2/g' /boot/grub/grub.cfg

# And the fstab
echo '/dev/vda2 / ext4 defaults 0 0' > /etc/fstab

# allow the console log
sed -i 's/#s0/s0/g' /etc/inittab

# let ipv6 use normal slaac
sed -i 's/slaac/#slaac/g' /etc/dhcpcd.conf
# don't let dhcpcd set domain name or hostname
sed -i 's/domain_name\,\ domain_search\,\ host_name/domain_search/g' /etc/dhcpcd.conf

# need to do this here because it clobbers an openrc owned file
cat > /etc/conf.d/hostname << "EOL"
# Set to the hostname of this machine
if [ -f /etc/hostname ];then
  hostname=$(cat /etc/hostname 2> /dev/null | cut -d"." -f1 2> /dev/null)
else
  hostname="localhost"
fi
EOL
chmod 0644 /etc/conf.d/hostname
chown root:root /etc/conf.d/hostname

# set a nice default for /etc/resolv.conf
cat > /etc/resolv.conf << EOL
nameserver 8.8.8.8
EOL

# let's upgrade (security fixes and otherwise)
USE="-build" emerge -uDNv --with-bdeps=y --jobs=2 @world
USE="-build" emerge --verbose=n --depclean
USE="-build" emerge -v --usepkg=n @preserved-rebuild
etc-update --automode -3

# Clean up portage
emerge --verbose=n --depclean
eix-update
emaint all -f
eselect news read all
eclean-dist --destructive
sed -i '/^USE=\"\${USE}\ \ build\"$/d' /etc/portage/make.conf

# clean up system
passwd -d root
passwd -l root
rm -f /usr/portage/distfiles/*
rm -f /etc/ssh/ssh_host_*
rm -f /root/.bash_history
rm -f /root/.nano_history
rm -f /root/.lesshst
rm -f /root/.ssh/known_hosts
rm -f /usr/src/linux
for i in $(find /var/log -type f); do echo > $i; done
for i in $(find /tmp -type f); do rm -f $i; done
