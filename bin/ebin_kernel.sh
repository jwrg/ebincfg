#!/bin/bash

# This script comprises the kernel build and installation
# component of ebincfg.  It is not really intended for
# standalone use, but rather to be called by ebincfg.sh
# which correctly handles user implications (i.e., the
# build step requires a normal user, whereas the install
# step requires root).

# Switches (no switches does naught):
# -v for verbose
# -M positional arg for disk mount path (req'd for install)
# -b for build step
# -i for install step (req's root)
# -C for local repo deletion

# Constants
COMPILER_PATH=/usr/x86_64-pc-linux-gnu/aarch64-unknown-linux-gnu/gcc-bin/10.2.0
KERNEL_PATH=./arm64_multiplatform/deploy
MOUNT_PATH=0
KERNEL_REPO=https://github.com/sarnold/arm64-multiplatform
LOCAL_REPO=arm64-multiplatform
TARGET_ARCH=aarch64-unknown-linux-gnu

# Argument default values
verbose=0
build=0
install=0
clean=0

log () {
  if [[ $verbose -eq 1 ]]; then
    echo "$@"
  fi
}

build_kernel () {
  log "Building kernel from scripts at $KERNEL_REPO"
  log ""

  log "Pulling kernel build scripts"
  git clone "$KERNEL_REPO" "$LOCAL_REPO" 2> /dev/null || git -C "$LOCAL_REPO" pull
  # scripts_repo_cloned=1
  cd $LOCAL_REPO || exit

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
  cd - || exit
}

install_kernel () {
  log "Installing kernel"
  cp ${KERNEL_PATH}/*.Image ${MOUNT_PATH}/boot/
  
  log "Installing kernel modules"
}

clean_byproducts () {
  log "Deleting scripts directory"
  rm -fr $KERNEL_REPO
}

while [[ $# -gt 0 ]]; do
  opt="$1"
  case "$opt" in
    "-v"|"--verbose"	    ) verbose=1; shift;;
    "-M"|"--mount-path"   ) MOUNT_PATH=$2; shift;shift;;
    "-b"|"--build"        ) build=1; shift;;
    "-i"|"--install"      ) install=1; shift;;
    "-C"|"--clean"        ) clean=1; shift;;
    *			) echo "ERROR: Invalid option: \"$opt"\" >&2
      exit 3;;
  esac
done

if [ $build -eq 1 ]; then
  build_kernel
fi

if [ $install -eq 1 ]; then
  install_kernel
fi

if [ $clean -eq 1 ]; then
  clean_byproducts
fi
