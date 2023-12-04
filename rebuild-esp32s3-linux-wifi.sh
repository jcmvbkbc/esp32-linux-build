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

SET_BAUDRATE='-b 2000000'

CTNG_VER=xtensa-fdpic
CTNG_CONFIG=xtensa-esp32s3-linux-uclibcfdpic
BUILDROOT_VER=xtensa-2023.11-fdpic
BUILDROOT_CONFIG=esp32s3_defconfig
ESP_HOSTED_VER=ipc
ESP_HOSTED_CONFIG=sdkconfig.defaults.esp32s3

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
	[ -n "$keep_rootfs" ] || rm -rf build/build-buildroot-esp32s3
	[ -n "$keep_buildroot" ] || rm -rf build/buildroot
	[ -n "$keep_bootloader" ] || rm -rf build/esp-hosted
fi
mkdir -p build
cd build

#
# dynconfig
#
if [ ! -f xtensa-dynconfig/esp32s3.so ] ; then
	git clone https://github.com/jcmvbkbc/xtensa-dynconfig -b original
	git clone https://github.com/jcmvbkbc/config-esp32s3 esp32s3
	make -C xtensa-dynconfig ORIG=1 CONF_DIR=`pwd` esp32s3.so
fi
export XTENSA_GNU_CONFIG=`pwd`/xtensa-dynconfig/esp32s3.so

#
# toolchain
#
if [ ! -x crosstool-NG/builds/xtensa-esp32s3-linux-uclibcfdpic/bin/xtensa-esp32s3-linux-uclibcfdpic-gcc ] ; then
	git clone https://github.com/jcmvbkbc/crosstool-NG.git -b $CTNG_VER
	pushd crosstool-NG
	./bootstrap && ./configure --enable-local && make
	./ct-ng $CTNG_CONFIG
	CT_PREFIX=`pwd`/builds nice ./ct-ng build
	popd
	[ -x crosstool-NG/builds/xtensa-esp32s3-linux-uclibcfdpic/bin/xtensa-esp32s3-linux-uclibcfdpic-gcc ] || exit 1
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
if [ ! -d build-buildroot-esp32s3 ] ; then
	nice make -C buildroot O=`pwd`/build-buildroot-esp32s3 $BUILDROOT_CONFIG
	buildroot/utils/config --file build-buildroot-esp32s3/.config --set-str TOOLCHAIN_EXTERNAL_PATH `pwd`/crosstool-NG/builds/xtensa-esp32s3-linux-uclibcfdpic
	buildroot/utils/config --file build-buildroot-esp32s3/.config --set-str TOOLCHAIN_EXTERNAL_PREFIX '$(ARCH)-esp32s3-linux-uclibcfdpic'
	buildroot/utils/config --file build-buildroot-esp32s3/.config --set-str TOOLCHAIN_EXTERNAL_CUSTOM_PREFIX '$(ARCH)-esp32s3-linux-uclibcfdpic'
fi
nice make -C buildroot O=`pwd`/build-buildroot-esp32s3
[ -f build-buildroot-esp32s3/images/xipImage -a -f build-buildroot-esp32s3/images/rootfs.cramfs -a -f build-buildroot-esp32s3/images/etc.jffs2 ] || exit 1

#
# bootloader
#
[ -d esp-hosted ] || git clone https://github.com/jcmvbkbc/esp-hosted -b $ESP_HOSTED_VER
pushd esp-hosted/esp_hosted_ng/esp/esp_driver
cmake .
cd esp-idf
. export.sh
cd ../network_adapter
idf.py set-target esp32s3
cp $ESP_HOSTED_CONFIG sdkconfig
idf.py build
read -p 'ready to flash... press enter'
while ! idf.py $SET_BAUDRATE flash ; do
	read -p 'failure... press enter to try again'
done
popd

#
# flash
#
parttool.py $SET_BAUDRATE write_partition --partition-name linux  --input build-buildroot-esp32s3/images/xipImage
parttool.py $SET_BAUDRATE write_partition --partition-name rootfs --input build-buildroot-esp32s3/images/rootfs.cramfs
if [ -z "$keep_etc" ] ; then
	read -p 'ready to flash /etc... press enter'
	parttool.py $SET_BAUDRATE write_partition --partition-name etc --input build-buildroot-esp32s3/images/etc.jffs2
fi
