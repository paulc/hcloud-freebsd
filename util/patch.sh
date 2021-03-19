#!/bin/sh
#
# Manually patch and update FreeBSD image (starts single use ssh server
# on port 9022 to allow interactive update of image and then runs
# freebsd-update/pkg update and cleans up runtime artefacts)
# 
# Requires hcloud cli (https://github.com/hetznercloud/cli) to be 
# installed
#
# Usage:
#
# IMAGE=<imageid> SSHKEY=<sshkeyid> ./patch.sh
# (In a separate session ssh to instance port 9022)
#
# By deefault this will create a cx11 image in fsn1 - to change set
# LOCATION/TYPE environment variables
# 
# (Note that the original image will be deleted)
#

set -o pipefail 
set -o errexit 
set -o nounset

: ${LOCATION:=fsn1}
: ${TYPE:=cx11}
: ${IMAGE?ERROR: Must specify IMAGE}
: ${SSHKEY?ERROR: Must specify SSHKEY}

TS=$(date +%Y%m%d-%H%M%S)
NAME="update-${TS}"
DESCRIPTION=$(hcloud image describe -o format='{{.Description}}' ${IMAGE})
BASE_DESCRIPTION=$(echo $DESCRIPTION | sed -Ee 's/-[0-9]{8}-[0-9]{6}$//')

echo "+++ When server starts SSH to port 9022 and update system:"
echo "+++ (Make sure you're not keeping a persistent session open (-o ControlPersist=no)"


hcloud server create --location ${LOCATION} --type ${TYPE} --image ${IMAGE} --name ${NAME} --ssh-key ${SSHKEY} --user-data-from-file - <<'EOM'
#!/bin/sh
( service sshd onekeygen
  /usr/sbin/sshd -d -o Port=9022 -o PermitRootLogin=prohibit-password
  freebsd-update fetch --not-running-from-cron | head
  freebsd-update install --not-running-from-cron || echo No updates available
  pkg update 
  pkg upgrade -y
  rm -f /var/hcloud/*
  rm -f /etc/ssh/*key*
  rm -f /root/.ssh/authorized_keys
  truncate -s0 /var/log/*
  sysrc -x ifconfig_vtnet0_ipv6 ipv6_defaultrouter
  touch /firstboot
  shutdown -p now ) 2>&1 | tee /var/log/update-$(date +%Y%m%d-%H%M%S).log
EOM

printf "Waiting for server shutdown"

while [ "$(hcloud server describe -o format='{{.Status}}' $NAME)" != "off" ]; do
    printf "."
    sleep 1
done

printf "\n"

hcloud server create-image --description "${BASE_DESCRIPTION}-${TS}" --type snapshot ${NAME}

hcloud server delete ${NAME}

hcloud image delete ${IMAGE}
