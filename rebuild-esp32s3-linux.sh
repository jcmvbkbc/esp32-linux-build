#! /bin/bash -x

# REBUILD_TOOLCHAIN=y
# REBUILD_KERNEL_ROOTFS=y
# REBUILD_BOOTLOADER=y

CTNG_CONFIG=xtensa-esp32s3-linux-uclibcfdpic
BUILDROOT_CONFIG=esp32s3_defconfig
ESP_HOSTED_CONFIG=sdkconfig.defaults.esp32s3

#
# dynconfig
#
if [ ! -f xtensa-dynconfig/esp32s3.so ] ; then
	make -C xtensa-dynconfig ORIG=1 CONF_DIR=`pwd` esp32s3.so
fi
export XTENSA_GNU_CONFIG=`pwd`/xtensa-dynconfig/esp32s3.so

#
# Build toolchain
#
if [ ! -z $REBUILD_TOOLCHAIN ] || [ ! -x crosstool-NG/builds/xtensa-esp32s3-linux-uclibcfdpic/bin/xtensa-esp32s3-linux-uclibcfdpic-gcc ] ; then
	pushd crosstool-NG
	./bootstrap && ./configure --enable-local && make
	./ct-ng $CTNG_CONFIG
	sed -i -e '/CT_LOG_PROGRESS_BAR/s/y$/n/' .config
	CT_PREFIX=`pwd`/builds ./ct-ng build
	popd
	[ -x crosstool-NG/builds/xtensa-esp32s3-linux-uclibcfdpic/bin/xtensa-esp32s3-linux-uclibcfdpic-gcc ] || exit 1
fi

#
# kernel and rootfs (buildroot)
#
if [ ! -z $REBUILD_KERNEL_ROOTFS ] || [ ! -f build-buildroot-esp32s3/images/xipImage ] || [ ! -f build-buildroot-esp32s3/images/rootfs.cramfs ] || [ ! -f build-buildroot-esp32s3/images/etc.jffs2 ] ; then 
	if [ ! -d build-buildroot-esp32s3 ] ; then
		make -C buildroot O=`pwd`/build-buildroot-esp32s3 $BUILDROOT_CONFIG
		buildroot/utils/config --file build-buildroot-esp32s3/.config --set-str TOOLCHAIN_EXTERNAL_PATH `pwd`/crosstool-NG/builds/xtensa-esp32s3-linux-uclibcfdpic
		buildroot/utils/config --file build-buildroot-esp32s3/.config --set-str TOOLCHAIN_EXTERNAL_PREFIX '$(ARCH)-esp32s3-linux-uclibcfdpic'
		buildroot/utils/config --file build-buildroot-esp32s3/.config --set-str TOOLCHAIN_EXTERNAL_CUSTOM_PREFIX '$(ARCH)-esp32s3-linux-uclibcfdpic'
	fi
	make -C buildroot O=`pwd`/build-buildroot-esp32s3
	[ -f build-buildroot-esp32s3/images/xipImage -a -f build-buildroot-esp32s3/images/rootfs.cramfs -a -f build-buildroot-esp32s3/images/etc.jffs2 ] || exit 1
fi

#
# bootloader
#
pushd esp-idf
if [ ! -z $REBUILD_BOOTLOADER ] || [ ! -f ./examples/get-started/linux_boot/build/linux_boot.bin ] || [ ! -f ./examples/get-started/linux_boot/build/partition_table/partition-table.bin ] || [ ! -f ./examples/get-started/linux_boot/build/bootloader/bootloader.bin ] ; then
	alias python='python3'
	. export.sh
	cd examples/get-started/linux_boot
	idf.py set-target esp32s3
	cp $ESP_HOSTED_CONFIG sdkconfig
	idf.py build
fi
popd

#
# publish artifacts
#
cp -v esp-idf/examples/get-started/linux_boot/build/bootloader/bootloader.bin ./output 
cp -v esp-idf/examples/get-started/linux_boot/build/partition_table/partition-table.bin ./output
cp -v esp-idf/examples/get-started/linux_boot/build/linux_boot.bin ./output

cp -rv build-buildroot-esp32s3/images/* ./output