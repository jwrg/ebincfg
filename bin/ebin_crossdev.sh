#!/bin/bash

# Switches (no switches does naught):  

# -c for the crossdev step
# -f for fixing symlinks for crossdev


# Constants
COMPILER_PATH=0
BINUTILS_PATH=0
TARGET_ARCH=0

# Argument default values
verbose=0
crossdev=0
fix=0

log () {
  if [[ $verbose -eq 1 ]]; then
    echo "$@"
  fi
}

build_crossdev () {
  log "Building crossdev for $TARGET_ARCH"
  log ""

  log 'sudo USE="hardened" crossdev -P -v -t' $TARGET_ARCH
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

while [[ $# -gt 0 ]]; do
  opt="$1"
  case "$opt" in
    "-v"|"--verbose"	      ) verbose=1; shift;;
    "-c"|"--crossdev"       ) crossdev=1; shift;;
    "-f"|"--fix"            ) fix=1; shift;;
    "-G"|"--gcc-path"       ) COMPILER_PATH=$2; shift;shift;;
    "-B"|"--binutils-path"  ) BINUTILS_PATH=$2; shift;shift;;
    "-A"|"--arch"           ) TARGET_ARCH=$2; shift;shift;;
    *			) echo "ERROR: Invalid option: \"$opt"\" >&2
      exit 3;;
  esac
done

if [ $crossdev -eq 1 ]; then
  if [ "$TARGET_ARCH" -eq 0 ]; then
    echo "ERROR: target architecture required" >&2
    exit 4
  fi
  build_crossdev
fi

if [ $fix -eq 1 ]; then
  if [ "$COMPILER_PATH" -eq 0 ] || [ "$BINUTILS_PATH" -eq 0 ]; then
    echo "ERROR: one or more required arguments missing" >&2
    exit 4
  fi
  fix_crossdev
fi
