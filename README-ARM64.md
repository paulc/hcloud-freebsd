
# Installing on ARM64 servers

Hetzner Cloud now suports ARM64 (AARCH64) servers (currently only in
Falkenstein DC) however it isn't currently possible to install FreeBSD directly
from CDROM (the system boots but there is no video output in the EFI console),
and (afaik) it also doesn't currently appear to be possibe to boot MfsBSD on
Arm64/EFI.

There are however a couple of other options we can use (both use the Linux
rescue system).

# FreeBSD VM image

We can use the officiel FreeBSD VM image to install the system - however we do
need to patch the image before writing to the VM disc (see
https://gist.github.com/pandrewhk/2d62664bfb74a504b7f4a894fc85eb97) 

To patch the image you will need an existing FreeBSD host (any architecture).

a.  On the existing FreeBSD host download the appropriate FreeBSD raw VM image 

    curl https://download.freebsd.org/releases/VM-IMAGES/13.2-RELEASE/aarch64/Latest/FreeBSD-13.2-RELEASE-arm64-aarch64.raw.xz)

b.  Mount the image as a loopback device 

    unxz FreeBSD-13.2-RELEASE-arm64-aarch64.raw.xz
    mdconfig -u1 FreeBSD-13.2-RELEASE-amd64.raw 
    mount /dev/md1p4 /mnt
    printf 'sshd_enable="YES"\nsshd_flags="-o PermitRootLogin=yes"\ndevmatch_blacklist="virtio_random.ko"\n' | tee -a /mnt/etc/rc.conf
    umask 077
    mkdir /mnt/root/.ssh
    echo "${SSH_PUB_KEY?}" > /mnt/root/.ssh/authorized_keys

(Note: you need to set the SSH_PUB_KEY env var to your ssh public key - eg. contents of .ssh/id_ed25519.pub)

c.  Make any other necessary changes to the base image (eg. growfs_enable="NO" if you want to add a ZFS partition instead of expanding the UFS partition))

d.  Unmount the image and recompress

    umount /mnt
    mdconfig -d -u 0
    xz FreeBSD-13.2-RELEASE-amd64.raw 

e.  Make sure that the image available (http/ftp) - (eg. python3 -m http.server)

f.  Boot the Hetzner ARM64 server into rescue mode and connect via SSH

g.  Download and write the image directly to the VM disc 

    curl http://.... | unxz > /dev/sda

h.  Reboot and connect to the server using SSH 

i.  Remove buggy virtio_random driver

    sysrc devmatch_blacklist="virtio_random.ko" # Avoid virtio_random.ko bug

j.  Follow normal installation instructions in config.sh

    fetch -o /tmp/config.sh https://raw.githubusercontent.com/paulc/hcloud-freebsd/master/config.sh
    sh -v /tmp/config.sh

#### Note: another option is to just install the distribution image directly onto the disc and then use the QEMU option below (dont attach ISO drive) to configure the system (this avoids having to patch the image first)

# QEMU install

#### _Note: This method doesnt boot with UFS install (looks like generated FS is corrupt but difficult to diagnose as console doesnt work) - for a UFS install you currently need to use the FreeBSD VM image option (see above). (ZFS install appears to work fine)_

The QEMU install option is a bit more complex however does allow you to customise the install (in particular if you want to install on ZFS root)

a.  Boot the VM into rescue mode and connect using SSH

b.  Install qemu-system-arm

    apt install -y qemu-system-arm qemu-efi-aarch64

c.  Download ARM installer 

    curl -Lo freebsd.iso https://download.freebsd.org/releases/arm64/aarch64/ISO-IMAGES/13.2/FreeBSD-13.2-RELEASE-arm64-aarch64-bootonly.iso

or

    curl -Lo freebsd.iso https://download.freebsd.org/releases/arm64/aarch64/ISO-IMAGES/13.2/FreeBSD-13.2-RELEASE-arm64-aarch64-disc1.iso

d.  Create EFI flash images

    dd if=/dev/zero of=efi.img bs=1M count=64
    dd if=/dev/zero of=efi-varstore.img bs=1M count=64
    dd if=/usr/share/qemu-efi-aarch64/QEMU_EFI.fd of=efi.img conv=notrunc

e.  Boot installer from QEMU

    qemu-system-aarch64 \
      -machine virt,gic-version=max \
      -nographic \
      -m 1024M \
      -cpu max \
      -device virtio-net-pci,netdev=nic \ 
      -netdev user,id=nic,hostfwd=tcp:127.0.0.1:2022-:22 \ # Only really needed for booting live image
      -drive file=efi.img,format=raw,if=pflash \
      -drive file=efi-varstore.img,format=raw,if=pflash \
      -drive file=/dev/sda,format=raw,if=none,id=drive0,cache=writeback \
      -device virtio-blk,drive=drive0 \
      -drive file=freebsd.iso,if=none,id=drive1,cache=writeback \
      -device virtio-blk,drive=drive1,bootindex=0

f.  Follow installer prompts as normal - when done drop into shell 

    sysrc devmatch_blacklist="virtio_random.ko" # Avoid virtio_random.ko bug

g.  Follow normal installation instructions in config.sh

    fetch -o /tmp/config.sh https://raw.githubusercontent.com/paulc/hcloud-freebsd/master/config.sh
    sh -v /tmp/config.sh

h.  Shutdown and exit QEMU (C-a x)

i.  Smapshot the instance

# Rescue system 

You can also use QEMU as a rescue system (use the Live CD rather than Installer
option when the ISO boots) or to boot the VM directly (remove the ISO
device/drive).
