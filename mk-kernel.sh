#!/bin/bash -e

LOCALPATH=$(pwd)
OUT=${LOCALPATH}/out
EXTLINUXPATH=${LOCALPATH}/build/extlinux
BOARD=$1

version_gt() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"; }

finish() {
	echo -e "\e[31m MAKE KERNEL IMAGE FAILED.\e[0m"
	exit -1
}
trap finish ERR

if [ $# != 1 ]; then
	BOARD=rk3288-evb
fi

[ ! -d ${OUT} ] && mkdir ${OUT}
[ ! -d ${OUT}/kernel ] && mkdir ${OUT}/kernel

rm -rf ${OUT}/kernel/overlays

if [ "$BOARD" == "rockpi4a" ] || [ "$BOARD" == "rockpi4b" ] || [ "$BOARD" == "rockpis" ]; then
	mkdir ${OUT}/kernel/overlays
fi

source $LOCALPATH/build/board_configs.sh $BOARD

if [ $? -ne 0 ]; then
	exit
fi

echo -e "\e[36m Building kernel for ${BOARD} board! \e[0m"

KERNEL_VERSION=$(cd ${LOCALPATH}/kernel && make kernelversion)
echo $KERNEL_VERSION

if version_gt "${KERNEL_VERSION}" "4.5"; then
	if [ "${DTB_MAINLINE}" ]; then
		DTB=${DTB_MAINLINE}
	fi

	if [ "${DEFCONFIG_MAINLINE}" ]; then
		DEFCONFIG=${DEFCONFIG_MAINLINE}
	fi
fi

cd ${LOCALPATH}/kernel
[ ! -e .config ] && echo -e "\e[36m Using ${DEFCONFIG} \e[0m" && make ${DEFCONFIG}

make -j8
cd ${LOCALPATH}

if [ "${ARCH}" == "arm" ]; then
	cp ${LOCALPATH}/kernel/arch/arm/boot/zImage ${OUT}/kernel/
	cp ${LOCALPATH}/kernel/arch/arm/boot/dts/${DTB} ${OUT}/kernel/
else
	cp ${LOCALPATH}/kernel/arch/arm64/boot/Image ${OUT}/kernel/
	cp ${LOCALPATH}/kernel/arch/arm64/boot/dts/rockchip/${DTB} ${OUT}/kernel/

	[ -d "${OUT}/kernel/overlays" ] && echo "remove dtbo files" && rm -rf ${OUT}/kernel/overlays/*
	[ -e "${OUT}/kernel/hw_intfc.conf" ] && echo "remove hw_intfc.conf file" && rm -rf ${OUT}/kernel/hw_intfc.conf

	if [ "${BOARD}" == "rockpi4a" ] || [ "${BOARD}" == "rockpi4b" ] ; then
		cp ${LOCALPATH}/kernel/arch/arm64/boot/dts/rockchip/overlays-rockpi4/*.dtbo ${OUT}/kernel/overlays/
		cp ${LOCALPATH}/kernel/arch/arm64/boot/dts/rockchip/overlays-rockpi4/hw_intfc.conf ${OUT}/kernel/
	elif [ "${BOARD}" == "rockpis" ] ; then
		cp ${LOCALPATH}/kernel/arch/arm64/boot/dts/rockchip/overlays-rockpis/*.dtbo ${OUT}/kernel/overlays/
		cp ${LOCALPATH}/kernel/arch/arm64/boot/dts/rockchip/overlays-rockpis/hw_intfc.conf ${OUT}/kernel/
	fi
fi

# Change extlinux.conf according board
sed -e "s,fdt .*,fdt /$DTB,g" \
	-i ${EXTLINUXPATH}/${CHIP}.conf

./build/mk-image.sh -c ${CHIP} -t boot -b ${BOARD}

echo -e "\e[36m Kernel build success! \e[0m"
