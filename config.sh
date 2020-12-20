#!/bin/sh
# 
# hcloud-freebsd/config.sh
#
# This script configures a clean FreeBSD install to support Hetzner cloud
# auto-provisioning.
#
# You can either run the commands manually or setup the system automatically 
# by downloading the this script (a git.io short link is available).
#
# Note that at this stage we dont have the CA root cert bundle installed so 
# need to run fetch using `--no-verify-peer`. This is potentially subject to 
# a MITM attack so ensure you review the script before running. Alternatively 
# you might want to install the ca_root_nss package before doing this (though 
# this will need you to bootstrap pkg).
#
# fetch -o config.sh --no-verify-peer https://git.io/Jv0sU
# sh ./config.sh
#
# _OR_
#
# ASSUME_ALWAYS_YES=yes pkg bootstrap pkg update
# pkg install -y ca_root_nss
# fetch -o config.sh https://git.io/Jv0sU
# sh ./config.sh
#
# The system will be powered off once the script has run and you should then 
# detach the ISO image and snapshot the instance (which can then be used as
# a template)

set -e

# Update system
if which hbsd-update; then  # HardenedBSD support
    hbsd-update
else
    freebsd-update fetch --not-running-from-cron | cat
    freebsd-update install --not-running-from-cron || echo "No updates available"
fi

# Bootstrap pkg tool and install required packages
ASSUME_ALWAYS_YES=yes pkg bootstrap
pkg update

# Get pkgs 
pkg install -y ca_root_nss python3 $(pkg search -q  -S name '^py3[0-9]+-yaml$' | sort | tail -1)

# Install hcloud utility
mkdir -p /usr/local/bin
fetch -o /usr/local/bin/hcloud https://raw.githubusercontent.com/paulc/hcloud-freebsd/master/bin/hcloud
chmod 755 /usr/local/bin/hcloud

# Install hcloud rc script
mkdir -p /usr/local/etc/rc.d
fetch -o /usr/local/etc/rc.d/hcloud https://raw.githubusercontent.com/paulc/hcloud-freebsd/master/etc/rc.d/hcloud
chmod 755 /usr/local/etc/rc.d/hcloud

# Enable hcloud service
sysrc hcloud_enable=YES

# Allow root login with SSH key
sysrc sshd_flags="-o PermitRootLogin=prohibit-password"

# Set root shell to /bin/sh
pw usermod root -s /bin/sh

# Disable root password login (if required)
pw usermod root -h -

# Create /firstboot flag for rc(8)
touch /firstboot

# Poweroff machine
echo "Configuration completed - detach ISO and create snapshot."
read -p "Do you want to power-off instance? [yn]: " yn
case $yn in
    [Yy]*) shutdown -p now; 
           break;;
    *)     ;;
esac

