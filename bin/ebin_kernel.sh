#!/bin/bash

# This script comprises the kernel build and installation
# component of ebincfg.  It is not really intended for
# standalone use, but rather to be called by ebincfg.sh
# which correctly handles user implications (i.e., the
# build step requires a normal user, whereas the install
# step requires root).

# Switches (no switches does naught):
# -v for verbose
# -A for target arch (req'd)
# -L for local repo path (req'd for build)
# -R for remote repo URI (req'd for build)
# -M positional arg for disk mount path (req'd for install)
# -G for compiler path
# -b for build step
# -i for install step (req's root)
# -C for local repo deletion 

# Constants
COMPILER_PATH=0
MOUNT_PATH=0
KERNEL_REPO=0
LOCAL_REPO=0
TARGET_ARCH=0

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
  cp ${LOCAL_REPO}/deploy/*.Image ${MOUNT_PATH}/boot/
  
  log "Installing device tree"
  tar xvf --strip-components=2 \
    ${LOCAL_REPO}/deploy/*-dtbs.tar.gz \
    ./marvell/armada-3720-espressobin.dtb \
    -C ${MOUNT_PATH}/boot/
  
  log "Creating kernel symlinks"
  ln -s ${MOUNT_PATH}/boot/*.Image \
    ${MOUNT_PATH}/boot/Image
  ln -s ${MOUNT_PATH}/boot/armada-3720-espressobin.dtb \
    ${MOUNT_PATH}/boot/armada-3720-community.dtb

  log "Copying kernel config"
  cp ${LOCAL_REPO}/deploy/config-* ${MOUNT_PATH}/boot/
  
  log "Installing kernel modules"
  tar xvf ${LOCAL_REPO}/deploy/*-modules.tar.gz \
    -C ${MOUNT_PATH}/
}

clean_byproducts () {
  log "Deleting scripts directory"
  [ -f $LOCAL_REPO ] && rm -fr $LOCAL_REPO
}

while [[ $# -gt 0 ]]; do
  opt="$1"
  case "$opt" in
    "-v"|"--verbose"	    ) verbose=1; shift;;
    "-b"|"--build"        ) build=1; shift;;
    "-i"|"--install"      ) install=1; shift;;
    "-C"|"--clean"        ) clean=1; shift;;
    "-M"|"--mount-path"   ) MOUNT_PATH=$2; shift;shift;;
    "-G"|"--gcc-path"     ) COMPILER_PATH=$2; shift;shift;;
    "-A"|"--target-arch"  ) TARGET_ARCH=$2; shift;shift;;
    "-L"|"--local-repo"   ) LOCAL_REPO=$2; shift;shift;;
    "-R"|"--remote-repo"  ) KERNEL_REPO=$2; shift;shift;;
    *			) echo "ERROR: Invalid option: \"$opt"\" >&2
      exit 3;;
  esac
done

if [ $build -eq 1 ]; then
  if [ "$COMPILER_PATH" -eq 0 ] || [ "$TARGET_ARCH" -eq 0 ] ||\
    [ "$KERNEL_REPO" -eq 0 ] || [ "$LOCAL_REPO" -eq 0 ]; then
    echo "ERROR: one or more required arguments missing" >&2
    exit 4
  fi
  build_kernel
fi

if [ $install -eq 1 ]; then
  if [ "$LOCAL_REPO" -eq 0 ] || [ "$MOUNT_PATH" -eq 0 ]; then
    echo "ERROR: one or more required arguments missing" >&2
    exit 4
  fi
  install_kernel
fi

if [ $clean -eq 1 ]; then
  if [ "$LOCAL_REPO" -eq 0 ]; then
    echo "ERROR: local repo path required" >&2
    exit 4
  fi
  clean_byproducts
fi

# EOF
