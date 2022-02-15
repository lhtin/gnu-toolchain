#!bash

set -xe

DATE=`date +%Y_%m_%d_%H_%M_%S`

mkdir -p logs

time $* DATE=$DATE 2>&1 | tee logs/build-$DATE.log

# make -f native.mk -j
# make -f cross-elf.mk ARCH=arm -j
# make -f cross-elf.mk ARCH=aarch64 -j
