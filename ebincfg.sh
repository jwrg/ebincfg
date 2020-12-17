#!/bin/bash

# ebincfg - Gentoo EspressoBin provisioning script

# This project comprises scripts for automating the lion's
# share of the setup and configuration process for making a
# Gentoo-based router system on an EspressoBin board.  It
# is provided with no warranty and use of the scripts
# constitutes the user's assent to all apposite risk.

# Please do not use if you are a n00b.  You can totally
# brick your build system with this if you are not paying
# attention.

# This is NOT an unattended setup script and the full setup
# process will be interrupted at least once.  Specifically,
# the user will be prompted to the following actions:
# - menuconfig for the kernel steps (ESC ESC ENTER)
# Before destructive disk operations, there will be a prompt
# so that the user can attest as to the correctness of the
# device being altered. 

# Switches (no switches does naught):  
# -v for verbose
# -D positional arg for disk device
# -M positional arg for mount point (doesn't have to exist)

# Usage:
# ./ebincfg.sh -v -D /dev/sdb -M /mnt/gentoo

# Switches that may or may not be forthcoming:
# -g to specify git repo for build scripts
# -k to specify kernel repo

# Assumptions made (these can change as functionality is added):
# - /etc/portage files have been correctly made into directories already
# - the user does not maintain a kernel tree using git
# - the following software packages are installed and working:
# - git, parted, sudo, wget

# Constants
DISK_PATH=0
MOUNT_PATH=/mnt/gentoo
COMPILER_PATH=/usr/x86_64-pc-linux-gnu/aarch64-unknown-linux-gnu/gcc-bin/10.2.0
BINUTILS_PATH=/usr/x86_64-pc-linux-gnu/aarch64-unknown-linux-gnu/binutils-bin/2.35.1
TARGET_ARCH=aarch64-unknown-linux-gnu
REMOTE_REPO=https://github.com/sarnold/arm64-multiplatform
KERNEL_REPO=arm64-multiplatform

# Argument default values
verbose=0

# Flags used by cleanup
mountpoint_created=0

log () {
  if [[ $verbose -eq 1 ]]; then
    echo "$@"
  fi
}

mount_disk () {
  log "Mounting filesystem at $MOUNT_PATH"
  if [[ ! -d "$MOUNT_PATH" ]]; then
    log "Creating mountpoint at $MOUNT_PATH"
    sudo mkdir ${MOUNT_PATH}
    mountpoint_created=1
  fi
  sudo mount ${DISK_PATH}1 ${MOUNT_PATH} || exit 5
}

umount_disk () {
  sudo umount $MOUNT_PATH || exit 6
}

cleanup () {
  if [ $mountpoint_created -eq 1 ]; then
    [ -f $MOUNT_PATH ] && sudo rm $MOUNT_PATH
  fi
}

while [[ $# -gt 0 ]]; do
  opt="$1"
  case "$opt" in
    "-v"|"--verbose"	  ) verbose=1; shift;;
    "-D"|"--disk-path"  ) DISK_PATH=$2; shift;shift;;
    "-M"|"--mount-path" ) MOUNT_PATH=$2; shift;shift;;
    *			) echo "ERROR: Invalid option: \"$opt"\" >&2
      exit 3;;
  esac
done

# Set up EXIT code trap for cleanup function
trap cleanup EXIT

# Call subscripts in correct order for correct users
if [ "$DISK_PATH" -eq 0 ]; then
  echo "ERROR: disk path required" >&2
  exit 4
fi

# Build and fix crossdev (root)
sudo \
./bin/ebin_crossdev.sh -v -c -f \
  -A "$TARGET_ARCH" \
  -G "$COMPILER_PATH" \
  -B "$BINUTILS_PATH"

# Build the kernel
./bin/ebin_kernel.sh -v -b \
  -A "$TARGET_ARCH" \
  -L "$KERNEL_REPO" \
  -R "$REMOTE_REPO" \
  -G "$COMPILER_PATH"

# Provision the disk and system
sudo \
./bin/ebin_provision.sh -v -d \
  -D "$MOUNT_PATH"
mount_disk
sudo \
./bin/ebin_provision.sh -v -p \
  -D "$DISK_PATH" \
  -M "$MOUNT_PATH"

# Install the kernel and delete the build repo
sudo \
./bin/ebin_kernel.sh -i -C \
  -M "$MOUNT_PATH"

# Configure the system
sudo \
./bin/ebin_provision.sh -v -s \
  -M "$MOUNT_PATH"
umount_disk

# EOF
