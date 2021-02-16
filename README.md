# ebincfg

**Gentoo on EspressoBin scripts**

This is a repo containing configuration
scripts for embedded routers, specifically
those running Gentoo on EspressoBin hardware.

The procedure contained in the script has been
lifted from the Gentoo wiki:
[Gentoo Wiki EspressoBin Page](https://wiki.gentoo.org/wiki/ESPRESSOBin#Fetch.2C_Configure_and_Build_the_Kernel)

## Scripts
Top-level scripts intended to be run (and read) by
the user.

### ebin_build.sh
Automates the build process.  This process has
been essentially lifted straight from the Gentoo
wiki with some minor changes and changes in
the order in which steps are performed.  See
comments in the script for usage information
et cetera.

## Sub-scripts
These are meant to be called by the top-level 
**ebincfg.sh** script.  Expect less documentation
herein.

### ebin_crossdev.sh
Fixes some crossdev foibles (may or may not be
required depending on your build system) and provides
an optional means for building crossdev for the arch
in question.

### ebin_kernel.sh
Fetches kernel build scripts and runs said scrips.
Leftovers are the user's responsibility.

### ebin_provision.sh
Does some Gentoo system provisioning steps; this step
essentially installs the operating system to the
board and includes potentially destructive disk
operations.

### ebin_iptables.sh
Installs an iptables configuration to the (mounted)
EspressoBin system disk drive.  The configuration
is a list of standard iptables commands and is 
therefore easily editable.

## Roadmap

In the future, the following may be added:

- Setup script for real time traffic analysis
- Setup script for blacklisting/whitelisting
- Setup script for routing traffic through darknet(s)
