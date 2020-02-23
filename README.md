# hcloud-freebsd

Hetzner Cloud auto-provisioning for FreeBSD

## Introduction

This repository enables auto-provisioning of FreeBSD instances on [Hetzner Cloud](https://www.hetzner.com/cloud).

Currently only Linux auto-provisioning is enabled by default however by initially manually configuring a FreeBSD instance manually and adding the `hcloud` utility and rc.d script included in this repository, it is possible to create a snapshot which can be used as a base instance and supports the normal auto-configuration functions available either in the cloud console or via the api or cli tools. 

## Installation

### OS Installation

Automated installation of FreeBSD instances is not currently available in the HCloud console, however it is possible to manually configure an instance as follows:

* Create a VM instance using the [cloud console](https://console.hetzner.cloud/projects). Pick a server type that matches the one you want to provision as a template (usually the smallest SSD type - currently CX11 - as you can resize instances upwards). The base image doesn't matter at this stage. 
* When the server has booted select the instance in the cloud console and attach a FreeBSD ISO image (select _ISO Images_ and search for an appropriate FreeBSD instance - 12.1 is currently supported)
* From the cloud console open the device console (**>_**) and reboot server.
* The FreeBSD installer should now start and you can install FreeBSD as normal. See the [FreeBSD handbook](https://www.freebsd.org/doc/handbook/bsdinstall.html) for details. The recommended options for installation are:
  - Appropriate keymap/hostname
  - Default install components (kernel-dbg/lib32)
  - Configure networking (**vtnet0/IPv4/DHCP**) - don't worry about configuring IPv6 at the moment (will be configured for cloned instances through cloud-config)
  - Select distrobution mirror - default is fine (ftp://ftp.freebsd.org) 
  - Select  **Auto (UFS)** partition type, **Entire Disk**, **GPT**, and accept default partitions
  - _(Distribution files should now install)_
  - Set root password (this is only needed for initial configuration - password login will be disabled for instances)
  - Select appropriate Time Zone and Date/Time
  - Select default services (at least **sshd**)
  - Chose security hardening options (I usually select all of these)
  - Do **not** add users to the system unless you specifically want these as part of the base image
  - Exit installer making shre you select **Yes** to drop to **shell** to complete configuration
  
* From the installation shell follow the instructions in config.sh (either manually or by downloading the script):

```shell
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
# fetch -o config.sh --no-verify-peer https://git.io/Jv0sU sh ./config.sh
#
# _OR_
#
# ASSUME_ALWAYS_YES=yes pkg bootstrap pkg update
# pkg install -y ca_root_nss
# fetch -o config.sh https://git.io/Jv0sU sh ./config.sh
#
# The system will be powered off once the script has run and you should then 
# detach the ISO image and snapshot the instance (which can then be used as
# a template)

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

# Disable root password login (if required)
pw usermod root -h -

# Create /firstboot flag for rc(8)
touch /firstboot

# Poweroff machine
shutdown -p now
```

* The instance will power off at the end of the installation

* From the Hetzner cloud console 
  - **Unmount ISO**
  - From Snapshots menu **Take Snapshot**
  - When the snapshot has been created you can now use this as a template to
    start new cloud instances

### Creating Instances

* To create a new instance click on **Add Server** as normal select the
  appropriate snapshot from the  **Images / Snapshots** tab (you can also
  view the the snapshot page and create a new server from there).

* Select the options as normal on the **Add Server** page. These will be picked up by
the rc/hcloud script on firstboot and where possible the server configured. 

* The script supports auto-configuration of the following settings:

  - **hostname**
  - **network interfaces** (iprimary interface IPv4 and IPv6 addresses,
    additional private interfaces will be autodetected and configured to run
    DHCP) 
  - **ssh keys** will be added to root user
  - **userdata** script will be run. Note that the userdata script will be 
    written to disk and run directly so must be a valid script for the 
    target system - in particular you will almost certainly just want to
    use a plain /bin/sh script (first line should be `#!/bin/sh`). Multipart
    files and cloud-config (`#cloud-config`) data are not supported.

* Note that additional volumes are not auto-configured but will be
  automatically detected by the kernel (/dev/da[123...]) so could be
  configured/mounted using the user-data script. 

* It is also possible to configure new instances via the API or hcloud 
  utility - eg:

  - `hcloud server create --image <imageid> --name <name> --user-data-from-file <userdata>  --ssh-key <keyname> --type <type> --location <location>`
