#!/bin/bash

# Switches (no switches does naught):
# -v for verbose
# -d for (*destructive*) disk step
# -p for Gentoo system provisioning
# -s for device configurations

# Constants
DISK_PATH=0
MOUNT_PATH=/mnt/gentoo

# Argument default values
verbose=0
disk=0
prepare=0
setup=0

log () {
  if [[ $verbose -eq 1 ]]; then
    echo "$@"
  fi
}

setup_disk () {
  log "Setting up partition and filesystem on MicroSD card"
  log ""
  log "Device to be OVERWRITTEN is $DISK_PATH"
  echo "dd if=/dev/zero of=${DISK_PATH} bs=1M count=10"
  echo "This is your last chance to double check that this"
  echo "command is correct."
  while true; do
    read -rp "Do you wish to proceed? [y/n]" confirm
    case $confirm in
      [Yy]* ) break;;
      [Nn]* ) exit;;
      * ) echo "Please answer y/n.";;
    esac
  done
  log "sudo dd if=/dev/zero of=${DISK_PATH} bs=1M count=10"
  sudo dd if=/dev/zero of=${DISK_PATH} bs=1M count=10

  log "Creating one partition on the disk"
  sudo parted -s -a optimal ${DISK_PATH} -- \
    mklabel gpt \
    mkpart rootfs 0.0 -1s

  log "Creating a filesystem on the one partition"
  sudo mkfs.ext4 -L rootfs -O ^metadata_csum,^64bit -T news ${DISK_PATH}1
}

prepare_system () {
  log "Installing arm64 stage3"
  wget -r -np -nd -P ${MOUNT_PATH} -A bz2,DIGESTS --accept-regex "stage3-arm64-[0-9]{8}\.tar" http://distfiles.gentoo.org/experimental/arm64/
  if [ ! "$(sed -n -e 4p ${MOUNT_PATH}/stage3-arm64-*DIGESTS \
    | awk '{print $1}')" \
    = "$(openssl dgst -r -sha512 ${MOUNT_PATH}/stage3-arm64-*.tar.bz2 \
    | awk '{print $1}')" ]; then
    echo "stage3 checksum verification failed!" >&2
    exit 2
  fi
  tar xvjpf ${MOUNT_PATH}/stage3-*.tar.bz2 --xattrs-include='*.*' --numeric-owner -C ${MOUNT_PATH}
  rm -rf ${MOUNT_PATH}/tmp/*
  rm ${MOUNT_PATH}/stage3-*.tar.bz2*

  log "Installing portage snapshot"
  wget -P ${MOUNT_PATH} http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2
  tar xvjf ${MOUNT_PATH}/portage-latest.tar.bz2 -C ${MOUNT_PATH}/usr
  rm ${MOUNT_PATH}/portage-latest.tar.bz2
}

configure_system () {
  log "Configuring serial access"

  log "Configuring network"

  log "Configuring root password (copying hash from host)"

  log "Configuring filesystems table"
}

while [[ $# -gt 0 ]]; do
  opt="$1"
  case "$opt" in
    "-v"|"--verbose"	  ) verbose=1; shift;;
    "-D"|"--disk-path"  ) DISK_PATH=$2; shift;shift;;
    "-M"|"--mount-path" ) MOUNT_PATH=$2; shift;shift;;
    "-d"|"--disk"       ) disk=1; shift;;
    "-p"|"--prepare"    ) prepare=1; shift;;
    "-s"|"--setup"      ) setup=1; shift;;
    *			) echo "ERROR: Invalid option: \"$opt"\" >&2
      exit 3;;
  esac
done

if [ $disk -eq 1 ]; then
  if [ "$DISK_PATH" -eq 0 ]; then
    echo "ERROR: disk block device path required" >&2
    exit 4
  fi
  setup_disk
fi

if [ $prepare -eq 1 ]; then
  if [ "$MOUNT_PATH" -eq 0 ]; then
    echo "ERROR: disk mountpoint path required" >&2
    exit 4
  fi
  prepare_system
fi

if [ $setup -eq 1 ]; then
  if [ "$DISK_PATH" -eq 0 ] || [ "$MOUNT_PATH" -eq 0 ]; then
    echo "ERROR: one or more required arguments missing" >&2
    exit 4
  fi
  configure_system
fi

# EOF
