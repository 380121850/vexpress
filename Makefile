##########################################################################################
#	prepare param
##########################################################################################
export OSDRV_DIR=$(shell pwd)
export OSDRV_CROSS=arm-hisiv600-linux-gnueabi
export CHIP?=vexpress
export ARCH=arm
export CROSS_COMPILE=$(OSDRV_CROSS)-
CROSS_COMPILE_STRIP:=$(OSDRV_CROSS)-strip
export OSDRV_CROSS_CFLAGS
MP_TYPE=sigle
BOOT_MEDIA?=spi
PUB_BOARD:=board

ifneq ($(BOOT_MEDIA),spi)
$(error you must set valid BOOT_MEDIA:spi!)
endif

ifeq ($(OSDRV_CROSS), )
$(error you must set OSDRV_CROSS first!)
endif


LIB_TYPE:=glibc
RUNTIME_LIB:=runtime_glibc
CROSS_SPECIFIED:=y

PUB_OUT_DIR=$(OSDRV_DIR)/out/
PUB_BIN_BOARD_DIR=$(PUB_OUT_DIR)/$(PUB_BOARD)
PUB_BIN_PC_DIR=$(PUB_OUT_DIR)/pc
PUB_IMAGE_DIR=$(PUB_OUT_DIR)/$(CHIP)_$(BOOT_MEDIA)_image_$(LIB_TYPE)

BUSYBOX_CFG:=busybox_vexpress.config
BUSYBOX_VER:=busybox-1.32.1
BUSYBOX_DIR=$(OSDRV_DIR)/$(BUSYBOX_VER)

#TOOLCHAIN_RUNTIME_LIB:=a7_softfp_neon-vfpv4
#OSDRV_CROSS_CFLAGS:=-mcpu=arm920t -mfloat-abi=softfp -w
#  -mfpu=neon-vfpv4

UBOOT_VER:=u-boot-2015.10
UBOOT:=u-boot.bin
UBOOT_CONFIG:=vexpress_ca9x4_defconfig
UBOOT_DIR=$(OSDRV_DIR)/$(UBOOT_VER)

KERNEL_VER:=linux-4.19.41
UIMAGE:=uImage
KERNEL_CFG:=vexpress_defconfig
KERNEL_DIR=$(OSDRV_DIR)/$(KERNEL_VER)
KO_TARGET_DIR=$(PUB_BIN_BOARD_DIR)/ko/
PUB_KERNEL_TARGET_DIR=$(PUB_BIN_BOARD_DIR)/build_$(CHIP)_$(KERNEL_VER)

ROOT_FS:=rootfs
ROOTFS_DIR:=$(OSDRV_DIR)/$(ROOT_FS)

ROOT_BIN:=a9rootfs.ext3
ROOT_BIN_SIZE_MB:=128
ROOT_BIN_TOOL:=mkfs.ext3
ROOT_BIN_SH:=mkrootfs.sh

TOOLCHAIN_FILE:= $(shell which $(OSDRV_CROSS)-gcc )
TOOLCHAIN_DIR:=$(shell dirname $(shell dirname $(TOOLCHAIN_FILE)))
RUNTIMELIB_DIR=$(shell dirname $(TOOLCHAIN_DIR))/$(OSDRV_CROSS)/$(RUNTIME_LIB)



##########################################################################################
#	set task
##########################################################################################
all: prepare boot kernel

clean: u-boot_clean busybox_clean kernel_clean  pub_clean

a:=$(shell $(OSDRV_CROSS)-gcc --version)
b:=$(findstring $(TOOLCHAINI_VERSION),$(a))
c:= $(word 2, $(a))
##########################################################################################
#task [0]	prepare
##########################################################################################
prepare:
	mkdir $(PUB_BIN_BOARD_DIR) -p
	mkdir $(PUB_BIN_PC_DIR) -p
	mkdir $(PUB_IMAGE_DIR) -p
	mkdir $(PUB_KERNEL_TARGET_DIR)  -p

##########################################################################################
#task [1]	build uboot
##########################################################################################
u-boot: prepare 
	@echo "---------task [1]	build boot"
	make -C $(UBOOT_DIR) ARCH=arm CROSS_COMPILE=$(OSDRV_CROSS)- $(UBOOT_CONFIG)
	#find $(OSDRV_DIR)/$(UBOOT_VER) | xargs touch
	pushd $(UBOOT_DIR);make ARCH=arm CROSS_COMPILE=$(OSDRV_CROSS)- -j 16 >/dev/null;popd
	cp $(UBOOT_DIR)/u-boot.bin $(PUB_IMAGE_DIR)/

u-boot_clean:
	make -C $(UBOOT_DIR) ARCH=arm CROSS_COMPILE=$(OSDRV_CROSS)- distclean
	#rm -rf $(PUB_IMAGE_DIR)/$(UBOOT)


##########################################################################################
#task [2]	build kernel
##########################################################################################
kernel: prepare 
	@echo "---------task [2] build kernel"
	#cp $(KERNEL_DIR)/$(KERNEL_CFG) $(OSDRV_DIR)/$(KERNEL_VER)/arch/arm/configs/$(KERNEL_CFG)_defconfig 
	#cp $(KERNEL_DIR)/rootfs-initramfs.cfg $(PUB_KERNEL_TARGET_DIR)/
	make -C $(KERNEL_DIR) ARCH=arm CROSS_COMPILE=$(OSDRV_CROSS)- O=$(PUB_KERNEL_TARGET_DIR)  $(KERNEL_CFG)
	make -C $(KERNEL_DIR) ARCH=arm CROSS_COMPILE=$(OSDRV_CROSS)- O=$(PUB_KERNEL_TARGET_DIR)  zImage -j 16 
	cp $(PUB_KERNEL_TARGET_DIR)/arch/arm/boot/zImage $(PUB_IMAGE_DIR)/

kernel_menuconfig:
	cp $(OSDRV_DIR)/$(KERNEL_VER)/$(KERNEL_CFG) $(OSDRV_DIR)/$(KERNEL_VER)/arch/arm/configs/$(KERNEL_CFG)_defconfig
	make -C $(OSDRV_DIR)/$(KERNEL_VER) ARCH=arm CROSS_COMPILE=$(OSDRV_CROSS)- O=$(PUB_KERNEL_TARGET_DIR) $(KERNEL_CFG)_defconfig
	make -C $(OSDRV_DIR)/$(KERNEL_VER) ARCH=arm CROSS_COMPILE=$(OSDRV_CROSS)- O=$(PUB_KERNEL_TARGET_DIR)  menuconfig

kernel_savecfg:
	cp $(PUB_KERNEL_TARGET_DIR)/.config $(OSDRV_DIR)/$(KERNEL_VER)/$(KERNEL_CFG);

kernel_clean:
	rm $(PUB_IMAGE_DIR)/$(UIMAGE) -rf
	make -C $(OSDRV_DIR)/$(KERNEL_VER) ARCH=arm CROSS_COMPILE=$(OSDRV_CROSS)- O=$(PUB_KERNEL_TARGET_DIR) distclean
	rm $(OSDRV_DIR)/$(KERNEL_VER)/arch/arm/configs/$(KERNEL_CFG)_defconfig -rf
	rm $(PUB_KERNEL_TARGET_DIR) -rf
	
##########################################################################################
#task [3]	prepare rootfs
##########################################################################################
rootfs_prepare: prepare busybox
	@echo "---------task [3] prepare rootfs "
	#tar xzf $(OSDRV_DIR)/rootfs/$(ROOT_FS_TAR) -C $(OSDRV_DIR)/pub
	cp -af $(ROOTFS_DIR) $(PUB_IMAGE_DIR)/
	cp -af $(OSDRV_DIR)/$(ROOT_BIN_SH) $(PUB_IMAGE_DIR)/
	cp -af $(PUB_IMAGE_DIR)/_install/* $(PUB_IMAGE_DIR)/$(ROOT_FS)/

rootfs_dev: prepare
	@echo "---------task [4] prepare rootfs "
	mknod $(PUB_IMAGE_DIR)/$(ROOT_FS)/dev/tty1 c 4 1
	mknod $(PUB_IMAGE_DIR)/$(ROOT_FS)/dev/tty2 c 4 2
	mknod $(PUB_IMAGE_DIR)/$(ROOT_FS)/dev/tty3 c 4 3
	mknod $(PUB_IMAGE_DIR)/$(ROOT_FS)/dev/tty4 c 4 4
	mknod $(PUB_IMAGE_DIR)/$(ROOT_FS)/dev/console c 5 1
	mknod $(PUB_IMAGE_DIR)/$(ROOT_FS)/dev/null c 1 3

rootfs: rootfs_prepare rootfs_dev
	@echo "---------task [5] rootfs "
	pushd $(PUB_IMAGE_DIR);dd if=/dev/zero of=$(ROOT_BIN) bs=1M count=$(ROOT_BIN_SIZE_MB)>/dev/null;popd
	pushd $(PUB_IMAGE_DIR);$(ROOT_BIN_TOOL) $(ROOT_BIN);popd
	pushd $(PUB_IMAGE_DIR);mkdir -p tmpfs;popd
	pushd $(PUB_IMAGE_DIR);mount -t ext3 $(ROOT_BIN) tmpfs/ -o loop;popd
	pushd $(PUB_IMAGE_DIR);cp -r $(PUB_IMAGE_DIR)/$(ROOT_FS)/*  tmpfs/;popd
	pushd $(PUB_IMAGE_DIR);umount tmpfs;popd
	
##########################################################################################
#task [4]	build busybox
##########################################################################################
busybox: 
	@echo "---------task [4] build busybox "
	cp $(BUSYBOX_DIR)/$(BUSYBOX_CFG) $(BUSYBOX_DIR)/.config
	pushd $(BUSYBOX_DIR);make -j 16 >/dev/null;popd
	make -C $(BUSYBOX_DIR) install
	cp -raf $(BUSYBOX_DIR)/_install  $(PUB_IMAGE_DIR)/

busybox_clean:
	make -C $(BUSYBOX_DIR) distclean
	rm $(BUSYBOX_DIR)/_install/ -rf

##########################################################################################
#task [10]	clean pub
##########################################################################################
pub_clean:
	rm $(PUB_OUT_DIR) -rf