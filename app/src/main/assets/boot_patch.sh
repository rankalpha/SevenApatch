#!/system/bin/sh
#######################################################################################
# APatch Boot Image Patcher
#######################################################################################
#
# Usage: boot_patch.sh <superkey> <bootimage> [ARGS_PASS_TO_bptools]
#
# This script should be placed in a directory with the following files:
#
# File name          Type          Description
#
# boot_patch.sh      script        A script to patch boot image for APatch.
#                  (this file)      The script will use files in its same
#                                  directory to complete the patching process.
# bootimg            binary        The target boot image
# kpimg              binary        KernelPatch core Image
# bptools            executable    The KernelPatch tools binary to inject kpimg to kernel Image
# magiskbboot         executable    Magisk tool to unpack boot.img.
#
#######################################################################################

ARCH=$(getprop ro.product.cpu.abi)

# Load utility functions
. ./util_functions.sh

echo "****************************"
echo " APatch Boot Image Patcher"
echo "****************************"

SUPERKEY="$1"
BOOTIMAGE=$2
FLASH_TO_DEVICE=$3
shift 2

[ -z "$SUPERKEY" ] && { >&2 echo "- SuperKey empty!"; exit 1; }
[ -e "$BOOTIMAGE" ] || { >&2 echo "- $BOOTIMAGE does not exist!"; exit 1; }

# Check for dependencies
command -v ./magiskbboot >/dev/null 2>&1 || { >&2 echo "- Command magiskbboot not found!"; exit 1; }
command -v ./bptools >/dev/null 2>&1 || { >&2 echo "- Command bptools not found!"; exit 1; }

if [ ! -f kernel ]; then
echo "- Unpacking boot image"
./magiskbboot unpack "$BOOTIMAGE" >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    >&2 echo "- Unpack error: $?"
    exit $?
  fi
fi

if [ ! $(./bptools -i kernel -f | grep CONFIG_KALLSYMS=y) ]; then
	echo "- Patcher has Aborted!"
	echo "- APatch requires CONFIG_KALLSYMS to be Enabled."
	echo "- But your kernel seems NOT enabled it."
	exit 0
fi

if [  $(./bptools -i kernel -l | grep patched=false) ]; then
	echo "- Backing boot.img "
  cp "$BOOTIMAGE" "ori.img" >/dev/null 2>&1
fi

mv kernel kernel.ori

echo "- Patching kernel"

set -x
./bptools -p -i kernel.ori -S "$SUPERKEY" -k kpimg -o kernel "$@"
patch_rc=$?
set +x

if [ $patch_rc -ne 0 ]; then
  >&2 echo "- Patch kernel error: $patch_rc"
  exit $?
fi

echo "- Repacking boot image"
./magiskbboot repack "$BOOTIMAGE" >/dev/null 2>&1

if [ ! $(./bptools -i kernel.ori -f | grep CONFIG_KALLSYMS_ALL=y) ]; then
	echo "- Detected CONFIG_KALLSYMS_ALL is not set!"
	echo "- APatch has patched but maybe your device won't boot."
	echo "- Make sure you have original boot image backup."
fi

if [ $? -ne 0 ]; then
  >&2 echo "- Repack error: $?"
  exit $?
fi

if [ "$FLASH_TO_DEVICE" = "true" ]; then
  # flash
  if [ -b "$BOOTIMAGE" ] || [ -c "$BOOTIMAGE" ] && [ -f "new-boot.img" ]; then
    echo "- Flashing new boot image"
    flash_image new-boot.img "$BOOTIMAGE"
    if [ $? -ne 0 ]; then
      >&2 echo "- Flash error: $?"
      exit $?
    fi
  fi

  echo "- Successfully Flashed!"
else
  echo "- Successfully Patched!"
fi

