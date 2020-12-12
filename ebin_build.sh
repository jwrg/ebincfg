#!/bin/bash

# The following comprises a script for automating the lion's
# share of the setup and configuration process for making a
# Gentoo-based router system on an EspressoBin board.  It
# is provided with no warranty and use of the script 
# constitutes the user's assent to all apposite risk.
# Please do not use if you are a n00b.

# This is NOT an unattended setup script and the full setup
# process will be interrupted at least once.  Specifically,
# the user will be prompted to the following actions:
# - menuconfig for the kernel steps
# Before destructive disk operations, there will be a pause
# so that the user can attest as to the correctness of the
# device being altered.  This is a pause, not a prompt.

# Switches (no switches gives help):  
# -v for verbose
# -c for the crossdev step
# -f for fixing symlinks for crossdev
# -k for kernel build step (needs crossdev)
# -D positional arg for disk device (req'd for disk, etc.)
# -d for disk (NB. destructive) steps
# -p for Gentoo system preparation steps (needs kernel)
# -s for config (e.g., network) steps (needs prep step)
# -C to clean up byproducts (doesn't uninstall crossdev)
# Switches that may or may not be forthcoming:
# -g to specify git repo for build scripts
# -k to specify kernel repo

# Example usage:
# ./ebin_build.sh -v -D /dev/sdb -c -k -d -p -s -C

# Assumptions made (these can change as functionality is added):
# - script is run as root (sudo is good enough)
# - /etc/portage files have been correctly made into directories already
# - git is installed and configured
# - parted is installed and works as expected
# - the user does not maintain a kernel tree using git

# Constants
COMPILER_PATH=/usr/x86_64-pc-linux-gnu/aarch64-unknown-linux-gnu/gcc-bin/10.2.0
BINUTILS_PATH=/usr/x86_64-pc-linux-gnu/aarch64-unknown-linux-gnu/binutils-bin/2.35.1
DISK_PATH=0
MOUNT_PATH=/mnt/gentoo
KERNEL_REPO=https://github.com/sarnold/arm64-multiplatform
LOCAL_REPO=arm64-multiplatform
TARGET_ARCH=aarch64-unknown-linux-gnu

# Argument default values
verbose=0
crossdev=0
fix=0
kernel=0
disk=0
prepare=0
setup=0
clean=0

# Flags used by cleanup
script_repo_cloned=0
mountpoint_created=0

log () {
  if [[ $verbose -eq 1 ]]; then
    echo "$@"
  fi
}

build_crossdev () {
  log "Building crossdev for $TARGET_ARCH"
  log ""

  log 'USE="hardened" crossdev -P -v -t $TARGET_ARCH'
  sudo USE="hardened" crossdev -P -v -t $TARGET_ARCH
}

fix_crossdev () {
  log "Creating missing symlinks for $TARGET_ARCH"
  for p in objdump objcopy strip ar as ld
  do
    log 'ln -s "'$BINUTILS_PATH/$p'" "'$COMPILER_PATH/$TARGET_ARCH-$p
    sudo ln -s "$BINUTILS_PATH/$p" "$COMPILER_PATH/$TARGET_ARCH-$p"
  done
  log 'ln -s "'$COMPILER_PATH/$TARGET_ARCH-gcc-nm'" "'$COMPILER_PATH/$TARGET_ARCH-nm
  sudo ln -s "$COMPILER_PATH/$TARGET_ARCH-gcc-nm" "$COMPILER_PATH/$TARGET_ARCH-nm"
}

build_kernel () {
  log "Building kernel from scripts at $KERNEL_REPO"
  log ""

  log "Pulling kernel build scripts"
  git clone "$KERNEL_REPO" "$LOCAL_REPO" 2> /dev/null || git -C "$LOCAL_REPO" pull
  scripts_repo_cloned=1
  cd $LOCAL_REPO

  if [[ ! -f system.sh ]]; then
    log "Moving system.sh.sample to system.sh"
    mv system.sh.sample system.sh

    log "Adding compiler path to system.sh"
    echo "CC=$COMPILER_PATH/$TARGET_ARCH-" >> system.sh
  fi

  log "Tweaking default kernel configuration"
  log "Setting CONFIG_GCC_PLUGINS=n"
  sed -i '/CONFIG_GCC_PLUGINS/ s/y/n/' patches/defconfig
  
  log "Building the kernel with build_kernel.sh"
  ./build_kernel.sh
  cd -
}

setup_disk () {
  log "Setting up OS on MicroSD card"
  log ""
  log "Device to be OVERWRITTEN is $DISK_PATH"
  echo "dd if=/dev/zero of=${DISK_PATH} bs=1M count=10"
  echo "This is your last chance to double check that this"
  echo "command is correct"
  sleep 3
  echo ""
  echo "Seriously, last chance"
  sleep 3
  echo ""
  echo "Okay, here goes!"
  sleep 3
  log "dd if=/dev/zero of=${DISK_PATH} bs=1M count=10"
  dd if=/dev/zero of=${DISK_PATH} bs=1M count=10

  log "Creating one partition on the disk"
  parted -s -a optimal ${DISK_PATH} -- \
    mklabel gpt \
    mkpart rootfs 0.0 -1s

  log "Creating a filesystem on the one partition"
  mkfs.ext4 -L rootfs -O ^metadata_csum,^64bit -T news ${DISK_PATH}1
}

prepare_system () {
  log "Mounting new filesystem at $MOUNT_PATH"
  if [[ ! -d "$MOUNT_PATH" ]]; then
    log "Creating mountpoint at $MOUNT_PATH"
    mkdir ${MOUNT_PATH}
    mountpoint_created=1
  fi
  mount ${DISK_PATH}1 ${MOUNT_PATH}
  
  log "Installing arm64 stage3"
  wget -r -np -np -P ${MOUNT_PATH} -A bz2,DIGESTS --accept-regex "stage3-arm64-[0-9]{8}\.tar" http://distfiles.gentoo.org/experimental/arm64/
  if [ ! "`sed -n -e 4p ${MOUNT_PATH}/stage3-arm64-*DIGESTS \
    | awk '{print $1}'`" \
    = "`openssl dgst -r -sha512 ${MOUNT_PATH}/stage3-arm64-*.tar.bz2 \
    | awk '{print $1}'`" ]; then
    echo "stage3 checksum verification failed!"
    exit 2
  fi
  tar xvjpf ${MOUNT_PATH}/stage3-*.tar.bz2 --xattrs-include='*.*' --numeric-owner -C ${MOUNT_PATH}
  rm -rf ${MOUNT_PATH}/tmp/*
  rm ${MOUNT_PATH}/stage3-*.tar.bz2*

  log "Installing portage snapshot"
  wget -P ${MOUNT_PATH} http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2
  tar xvjf ${MOUNT_PATH}/portage-latest.tar.bz2 -C ${MOUNT_PATH}/usr
  rm ${MOUNT_PATH}/portage-latest.tar.bz2
  
  log "Installing kernel"
  
  log "Installing kernel modules"

  log "Unmounting disk at ${MOUNT_PATH}"
  umount ${MOUNT_PATH}
}

configure_system () {
  log "Mounting filesystem at $MOUNT_PATH"
  if [[ ! -d "$MOUNT_PATH" ]]; then
    log "Creating mountpoint at $MOUNT_PATH"
    mkdir ${MOUNT_PATH}
    mountpoint_created=1
  fi
  mount ${DISK_PATH}1 ${MOUNT_PATH}

  log "Configuring serial access"

  log "Configuring network"

  log "Configuring root password (copying hash from host)"

  log "Configuring filesystems table"
  
  log "Unmounting disk at ${MOUNT_PATH}"
  umount ${MOUNT_PATH}
}

#clean_byproducts () {}
#cleanup () {}

while [[ $# -gt 0 ]]; do
  opt="$1"
  case "$opt" in
    "-v"|"--verbose"	) verbose=1; shift;;
    "-D"|"--disk-path") DISK_PATH=$2; shift;;
    "-c"|"--crossdev" ) crossdev=1; shift;;
    "-f"|"--fix"      ) fix=1; shift;;
    "-k"|"--kernel"   ) kernel=1; shift;;
    "-d"|"--disk"     ) disk=1; shift;;
    "-p"|"--prepare"  ) prepare=1; shift;;
    "-s"|"--setup"    ) setup=1; shift;;
    "-C"|"--clean"    ) clean=1; shift;;
    *			) echo "ERROR: Invalid option: \""$opt"\"" >&2
      exit 3;;
  esac
done

# Set up EXIT code trap for cleanup function
if [ $clean -eq 1 ]; then
  trap cleanup EXIT
fi

# Do the requested steps in the correct order
if [ $crossdev -eq 1 ]; then
  build_crossdev
fi

if [ $fix -eq 1 ]; then
  fix_crossdev
fi

if [ $kernel -eq 1 ]; then
  build_kernel
fi

if [ $disk -eq 1 ]; then
  setup_disk
fi

if [ $prepare -eq 1 ]; then
  prepare_system
fi

if [ $setup -eq 1 ]; then
  configure_system
fi

# EOF
