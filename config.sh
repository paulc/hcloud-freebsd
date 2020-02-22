#!/bin/sh

# Update system
freebsd-update fetch --not-running-from-cron | cat
freebsd-update install --not-running-from-cron

# Bootstrap pkg tool and install required packages
ASSUME_ALWAYS_YES=yes pkg bootstrap
pkg update
pkg install -y python3 py37-pyaml py37-requests ca_root_nss

# Install hcloud utility
fetch -o /usr/local/bin/hcloud https://raw.githubusercontent.com/paulc/hcloud-freebsd/master/hcloud.py
chmod 755 /usr/local/bin/hcloud

# Install hcloud rc script
fetch -o /etc/rc.d/hcloud https://raw.githubusercontent.com/paulc/hcloud-freebsd/master/hcloud.rc
chmod 755 /etc/rc.d/hcloud

# Enable hcloud service
sysrc hcloud_enable=YES

# Allow root login with SSH key
sysrc sshd_flags="-o PermitRootLogin=prohibit-password"

# Set root shell to /bin/sh
pw usermod root -s /bin/sh

# Disable root password login
pw usermod root -h -

# Create /firstboot flag for rc(8)
touch /firstboot

# Poweroff machine
shutdown -p now
