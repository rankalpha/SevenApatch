#!/system/bin/sh
#######################################################################################
# APatch Boot Image Unpatcher
#######################################################################################

ARCH=$(getprop ro.product.cpu.abi)

# Load utility functions
. ./util_functions.sh

echo "****************************"
echo " APatch Boot Image Unpatcher"
echo "****************************"

BOOTIMAGE=$1

[ -e "$BOOTIMAGE" ] || { echo "- $BOOTIMAGE does not exist!"; exit 1; }

echo "- Target image: $BOOTIMAGE"

  # Check for dependencies
command -v ./magiskbboot >/dev/null 2>&1 || { echo "- Command magiskbboot not found!"; exit 1; }
command -v ./bptools >/dev/null 2>&1 || { echo "- Command bptools not found!"; exit 1; }

if [ ! -f kernel ]; then
echo "- Unpacking boot image"
./magiskbboot unpack "$BOOTIMAGE" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    >&2 echo "- Unpack error: $?"
    exit $?
  fi
fi

if [ ! $(./bptools -i kernel -l | grep patched=false) ]; then
	echo "- kernel has been patched "
  if [ -f "new-boot.img" ]; then
    echo "- found backup boot.img ,use it for recovery"
  else
    mv kernel kernel.ori
    echo "- Unpatching kernel"
    ./bptools -u --image kernel.ori --out kernel
    if [ $? -ne 0 ]; then
      >&2 echo "- Unpatch error: $?"
      exit $?
    fi
    echo "- Repacking boot image"
    ./magiskbboot repack "$BOOTIMAGE" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      >&2 echo "- Repack error: $?"
      exit $?
    fi
  fi

else
  echo "- no need unpatch"
  exit 0
fi



if [ -f "new-boot.img" ]; then
  echo "- Flashing boot image"
  flash_image new-boot.img "$BOOTIMAGE"

  if [ $? -ne 0 ]; then
    >&2 echo "- Flash error: $?"
    exit $?
  fi
fi

echo "- Flash successful"

# Reset any error code
true
