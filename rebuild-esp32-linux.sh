#! /bin/bash -x

#
# environment variables affecting the build:
#
# keep_toolchain=y	-- don't rebuild the toolchain, but rebuild everything else
# keep_rootfs=y		-- don't reconfigure or rebuild rootfs from scratch. Would still apply overlay changes
# keep_buildroot=y	-- don't redownload the buildroot, only git pull any updates into it
# keep_bootloader=y	-- don't redownload the bootloader, only rebuild it
# keep_etc=y		-- don't overwrite the /etc partition
#

SET_BAUDRATE='-b 1000000'

CTNG_VER=xtensa-fdpic
CTNG_CONFIG=xtensa-esp32-linux-uclibcfdpic
BUILDROOT_VER=xtensa-2024.05-fdpic
BUILDROOT_CONFIG=esp32_defconfig
ESP_BOOTLOADER_VER=linux-5.1.2
ESP_BOOTLOADER_CONFIG=sdkconfig.defaults.esp32

if [ ! -d autoconf-2.71/root/bin ] ; then
	wget https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.xz
	tar -xf autoconf-2.71.tar.xz
	pushd autoconf-2.71
	./configure --prefix=`pwd`/root
	make && make install
	popd
fi
export PATH=`pwd`/autoconf-2.71/root/bin:$PATH

if [ -z "$keep_toolchain$keep_buildroot$keep_rootfs$keep_bootloader" ] ; then
	rm -rf build
else
	[ -n "$keep_toolchain" ] || rm -rf build/crosstool-NG/builds/xtensa-esp32-linux-uclibcfdpic
	[ -n "$keep_rootfs" ] || rm -rf build/build-buildroot-esp32
	[ -n "$keep_buildroot" ] || rm -rf build/buildroot
	[ -n "$keep_bootloader" ] || rm -rf build/esp-idf
fi
mkdir -p build
cd build

#
# dynconfig
#
if [ ! -f xtensa-dynconfig/esp32.so ] ; then
	git clone https://github.com/jcmvbkbc/xtensa-dynconfig -b original
	wget https://github.com/jcmvbkbc/xtensa-toolchain-build/raw/e46089b8418f27ecd895881f071aa192dd7f42b5/overlays/original/esp32.tar.gz
	mkdir esp32
	tar -xf esp32.tar.gz -C esp32
	sed -i 's/\(XSHAL_ABI\s\+\)XTHAL_ABI_WINDOWED/\1XTHAL_ABI_CALL0/' esp32/{binutils,gcc}/xtensa-config.h
	make -C xtensa-dynconfig ORIG=1 CONF_DIR=`pwd` esp32.so
fi
export XTENSA_GNU_CONFIG=`pwd`/xtensa-dynconfig/esp32.so

#
# toolchain
#
if [ ! -x crosstool-NG/builds/xtensa-esp32-linux-uclibcfdpic/bin/xtensa-esp32-linux-uclibcfdpic-gcc ] ; then
	git clone https://github.com/jcmvbkbc/crosstool-NG.git -b $CTNG_VER
	pushd crosstool-NG
	./bootstrap && ./configure --enable-local && make
	./ct-ng $CTNG_CONFIG
	CT_PREFIX=`pwd`/builds nice ./ct-ng build
	popd
	[ -x crosstool-NG/builds/xtensa-esp32-linux-uclibcfdpic/bin/xtensa-esp32-linux-uclibcfdpic-gcc ] || exit 1
fi

#
# kernel and rootfs
#
if [ ! -d buildroot ] ; then
	git clone https://github.com/jcmvbkbc/buildroot -b $BUILDROOT_VER
else
	pushd buildroot
	git pull
	popd
fi
if [ ! -d build-buildroot-esp32 ] ; then
	nice make -C buildroot O=`pwd`/build-buildroot-esp32 $BUILDROOT_CONFIG
	buildroot/utils/config --file build-buildroot-esp32/.config --set-str TOOLCHAIN_EXTERNAL_PATH `pwd`/crosstool-NG/builds/xtensa-esp32-linux-uclibcfdpic
	buildroot/utils/config --file build-buildroot-esp32/.config --set-str TOOLCHAIN_EXTERNAL_PREFIX '$(ARCH)-esp32-linux-uclibcfdpic'
	buildroot/utils/config --file build-buildroot-esp32/.config --set-str TOOLCHAIN_EXTERNAL_CUSTOM_PREFIX '$(ARCH)-esp32-linux-uclibcfdpic'
fi
nice make -C buildroot O=`pwd`/build-buildroot-esp32
[ -f build-buildroot-esp32/images/xipImage -a -f build-buildroot-esp32/images/rootfs.cramfs -a -f build-buildroot-esp32/images/etc.jffs2 ] || exit 1

#
# bootloader
#
[ -d esp-idf ] || git clone https://github.com/jcmvbkbc/esp-idf -b $ESP_BOOTLOADER_VER
pushd esp-idf
. export.sh
cd examples/get-started/linux_boot
idf.py set-target esp32
cp $ESP_BOOTLOADER_CONFIG sdkconfig
idf.py build
read -p 'ready to flash... press enter'
while ! idf.py $SET_BAUDRATE flash ; do
	read -p 'failure... press enter to try again'
done
popd

#
# flash
#
parttool.py $SET_BAUDRATE write_partition --partition-name linux  --input build-buildroot-esp32/images/xipImage
parttool.py $SET_BAUDRATE write_partition --partition-name rootfs --input build-buildroot-esp32/images/rootfs.cramfs
