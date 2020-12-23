# hcloud-freebsd

Hetzner Cloud auto-provisioning for FreeBSD

## Introduction

This repository enables auto-provisioning of FreeBSD instances on 
[Hetzner Cloud](https://www.hetzner.com/cloud).

Currently only Linux auto-provisioning is enabled by default however by
initially manually configuring a FreeBSD instance and adding the `hcloud`
utility and `rc.d` script included in this repository, it is possible to create
a snapshot which can be used as a base instance and supports the normal
auto-configuration functions available either in the cloud console or via the
api/cli tools. 

### *** Note that currently FreeBSD doesn't work on CPX (AMD/EPYC) instances - only CP (XEON) ***

## Installation

### OS Installation

Automated installation of FreeBSD instances is not currently available for
Hetzner Cloud, however it is possible to manually configure an instance as
follows:

* Create a VM instance using the [cloud console](https://console.hetzner.cloud/projects). 
  Pick a server type that matches the one you want to provision as a template
  (usually the smallest SSD type - currently CX11 - as you can resize instances
  upwards). The base image doesn't matter at this stage. 

* When the server has booted select the instance in the cloud console and
  attach a FreeBSD ISO image (select _ISO Images_ and search for an appropriate
  FreeBSD instance). The script will also support HardenedBSD however you will
  need to ask support to make the ISO available.

* From the cloud console open the device console (**>_**) and reboot server.

* The FreeBSD installer should now start and you can install FreeBSD as normal.
  See the [FreeBSD handbook](https://www.freebsd.org/doc/handbook/bsdinstall.html) for details.
  The recommended options for installation are:

  - Appropriate keymap/hostname
  - Default install components (kernel-dbg/lib32)
  - Configure networking (**vtnet0/IPv4/DHCP**) - don't worry about configuring 
    IPv6 at the moment (will be configured for cloned instances through cloud-config)
  - Select distrobution mirror - default is fine (ftp://ftp.freebsd.org) 
  - Select  **Auto (UFS)** partition type, **Entire Disk**, **GPT**, and accept default partitions (it is also possible to use ZFS if prefered - though UFS might be more suitable for low-memory instances). 
  - _(Distribution files should now install)_
  - Set root password (this is only needed for initial configuration - password login will be 
    disabled for instances)
  - Select appropriate Time Zone and Date/Time
  - Select default services (at least **sshd**)
  - Chose security hardening options (I usually select all of these)
  - Do **not** add users to the system unless you specifically want these as part of the base image
  - Exit installer making shre you select **Yes** to drop to **shell** to complete configuration
  
* From the installation shell follow the instructions in [config.sh](https://github.com/paulc/hcloud-freebsd/blob/master/config.sh) (either manually or by downloading the script):

* The instance will power off at the end of the installation

* From the Hetzner cloud console 
  - **Unmount ISO**
  - From Snapshots menu **Take Snapshot**
  - When the snapshot has been created you can now use this as a template to
    start new cloud instances

### Creating Instances

* To create a new instance click on **Add Server** as normal and select the
  appropriate snapshot from the  **Images / Snapshots** tab (you can also
  view the the snapshot page and create a new server from there).

* Select the options as normal on the **Add Server** page. These will be picked up by
the `rc/hcloud` script on firstboot and the server configured. 

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
    files and cloud-config (`#cloud-config`) data are not supported (GZ
    compressed files _are_ supported).

* Note that additional volumes are not auto-configured but will be
  automatically detected by the kernel (`/dev/da[123...]`) so could be
  configured/mounted using the user-data script. 

* If needed it is possible to grow the FS for larger instances automatically
  via the **userdata** script. It should also be possible to use `rc.d/growfs`
  (needs `growfs_enable=YES` in `rc.conf` and the root partition to be the last
  partition) although I haven't tested this. 

* Alternatively it is posisble to use the additional space to add an additional
  FS (eg. for ZFS) from the userdata script.  You can check if the image has
  been installed onto a larger sized instance by running `gpart show da0 | grep
  -qs CORRUPT` and then `gpart recover` / `gpart add` etc.

* A copy of the cloud configuration parameters (split by section), the 
  user-data script, and an installation log are saved in the /var/hcloud
  directory.

* The rc(8) system will automatically delete the /firstboot flag after
  the first-boot so the script will only run once.

* It is also possible to configure new instances via the API or hcloud 
  utility - eg:

  - `hcloud server create --image <imageid> --name <name> --user-data-from-file <userdata>  --ssh-key <keyname> --type <type> --location <location>`

### Maintaining Images

* To maintain images (run freebsd-update/update pkgs etc) a couple of 
  example scripts are provides in the **/util** directory. 

  - [update.sh](https://github.com/paulc/hcloud-freebsd/blob/master/util/update.sh) 
    will automatically run basic OS/pkg updates on the image and then resave 
    (deleting original)

  - [patch.sh](https://github.com/paulc/hcloud-freebsd/blob/master/util/patch.sh) 
    will do the same but first launch a single use sshd instance on port 9022
    to allow interactive configuration

  - (Note that in both cases the **imageid** will change)
