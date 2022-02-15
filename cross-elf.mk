ROOT_DIR := $(shell pwd)
LINUX_HEADERS_SRC_DIR := $(ROOT_DIR)/linux-headers/include
BINUTILS_SRC_DIR=$(ROOT_DIR)/binutils
GCC_SRC_DIR=$(ROOT_DIR)/gcc
NEWLIB_SRC_DIR=$(ROOT_DIR)/newlib

ifeq ($(ARCH), arm)
	TARGET=arm-unknown-elf
	WIDTH_ARCH=armv8.6-a
else ifeq ($(ARCH), aarch64)
	TARGET=aarch64-unknown-elf
	WIDTH_ARCH=armv8.2-a+sve
else
  ifeq ($(XLEN), 32)
		TARGET=riscv32-unknown-elf
		WIDTH_ARCH=rv32gc_zicsr_zifencei
  else
		TARGET=riscv64-unknown-elf
		WIDTH_ARCH=rv64gc_zicsr_zifencei
  endif
endif

ifndef DATE
	DATE := $(shell date +%Y_%m_%d_%H_%M_%S)
endif

BUILD_DIR := $(shell pwd)/build/build-$(TARGET)-$(DATE)
PREFIX := $(BUILD_DIR)/output

export PATH := $(PREFIX)/bin:$(PATH)

all: $(BUILD_DIR)/build-gcc-stage2

prefix:
	mkdir -p $(PREFIX)

$(BUILD_DIR)/build-binutils: prefix
	mkdir $@
	cd $@ && $(BINUTILS_SRC_DIR)/configure \
		--target=$(TARGET) \
		--prefix=$(PREFIX) \
		--disable-werror \
		--with-expat=yes  \
		--disable-gdb \
		--disable-sim \
		--disable-libdecnumber \
		--disable-readline
	$(MAKE) -C $@
	$(MAKE) -C $@ install

# stage1
$(BUILD_DIR)/build-gcc-stage1: $(BUILD_DIR)/build-binutils
	mkdir $@
	cd $@ && $(GCC_SRC_DIR)/configure \
		--target=$(TARGET) \
		--prefix=$(PREFIX) \
		--disable-shared \
		--disable-threads \
		--disable-tls \
		--enable-languages=c,c++ \
		--with-system-zlib \
		--with-newlib \
		--with-sysroot=$(PREFIX)/$(TARGET) \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		--disable-libgomp \
		--disable-nls \
		--disable-tm-clone-registry \
		--src=$(GCC_SRC_DIR) \
		--disable-multilib \
		--with-arch=$(WIDTH_ARCH) \
		--with-pkgversion=GNU \
		CFLAGS="-O0 -g3" \
		CXXFLAGS="-O0 -g3" \
		CFLAGS_FOR_TARGET="-Os" \
		CXXFLAGS_FOR_TARGET="-Os"
	$(MAKE) -C $@ all-gcc
	$(MAKE) -C $@ install-gcc

# touch --date="`date`" aclocal.m4 Makefile.am configure Makefile.in
# newlib
$(BUILD_DIR)/build-newlib: $(BUILD_DIR)/build-gcc-stage1
	mkdir $@
	cd $@ && $(NEWLIB_SRC_DIR)/configure \
		--target=$(TARGET) \
		--prefix=$(PREFIX) \
		--enable-newlib-io-long-double \
		--enable-newlib-io-long-long \
		--enable-newlib-io-c99-formats \
		--enable-newlib-register-fini \
		CFLAGS_FOR_TARGET="-O2 -D_POSIX_MODE" \
		CXXFLAGS_FOR_TARGET="-O2 -D_POSIX_MODE"
	$(MAKE) -C $@ V=1 VERBOSE=1
	$(MAKE) -C $@ install

# stage2
$(BUILD_DIR)/build-gcc-stage2: $(BUILD_DIR)/build-newlib
	mkdir $@
	cd $@ && $(GCC_SRC_DIR)/configure \
		--target=$(TARGET) \
		--prefix=$(PREFIX) \
		--disable-shared \
		--disable-threads \
		--enable-languages=c,c++ \
		--with-system-zlib \
		--enable-tls \
		--with-newlib \
		--with-sysroot=$(PREFIX)/$(TARGET) \
		--with-native-system-header-dir=/include \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		--disable-libgomp \
		--disable-nls \
		--disable-tm-clone-registry \
		--src=$(GCC_SRC_DIR) \
		--disable-multilib \
		--with-arch=$(WIDTH_ARCH) \
		--with-pkgversion=GNU \
		CFLAGS="-O0 -g3" \
		CXXFLAGS="-O0 -g3" \
		CFLAGS_FOR_TARGET="-Os" \
		CXXFLAGS_FOR_TARGET="-Os"
	$(MAKE) -C $@
	$(MAKE) -C $@ install
	echo "Build Success."
