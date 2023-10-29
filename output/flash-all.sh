#! /bin/bash -x

# KEEP_ETC=y

SET_BAUDRATE='-b 460800'

pushd esp-hosted/esp_hosted_ng/esp/esp_driver/esp-idf
alias python='python3'
. export.sh

popd
cd output

#
# flash wifi-driver
#
esptool.py $SET_BAUDRATE --before=default_reset --after=hard_reset write_flash --flash_mode dio --flash_freq 80m --flash_size 8MB 0x0 bootloader.bin 0x10000 network_adapter.bin 0x8000 partition-table.bin

#
# flash partitions
#
parttool.py $SET_BAUDRATE write_partition --partition-name linux  --input xipImage
parttool.py $SET_BAUDRATE write_partition --partition-name rootfs --input rootfs.cramfs
if [ -z $KEEP_ETC ] ; then
	# read -p 'ready to flash /etc... press enter'
	parttool.py $SET_BAUDRATE write_partition --partition-name etc --input etc.jffs2
fi

#
# monitor
#
# idf.py monitor