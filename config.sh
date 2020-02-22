#!/bin/sh
# 
# You can setup the template automatically by downloading the `install.sh`
# script from this repository (a git.io short link is available).
#
# Note that at this stage we dont have the CA root cert bundle installed so 
# need to install using `--no-verify-hostname` and `--no-verify-peer`. This
# is (in theory) subject to a MITM attack so ensure you review the script 
# before running. Alternatively you might want to install the ca_root_nss
# package before doing this (though this will need you to bootstrap pkg)
#
# fetch -o config.sh --no-verify-hostname --no-verify-peer https://git.io/Jv0sU
# sh ./config.sh
#
# _OR_
#
# ASSUME_ALWAYS_YES=yes pkg bootstrap
# pkg update
# pkg install -y ca_root_nss
# fetch -o config.sh https://git.io/Jv0sU
# sh ./config.sh

# Update system
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

# Disable root password login if required
pw usermod root -h -

# Create /firstboot flag for rc(8)
touch /firstboot

# Poweroff machine
shutdown -p now
