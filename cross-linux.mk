ROOT_DIR := $(shell pwd)
BINUTILS_SRC_DIR=$(ROOT_DIR)/binutils
GCC_SRC_DIR=$(ROOT_DIR)/gcc
GLIBC_SRC_DIR=$(ROOT_DIR)/glibc

ifndef DATE
	DATE := $(shell date +%Y_%m_%d_%H_%M_%S)
endif

ifeq ($(ARCH), aarch64)
	TARGET=aarch64-unknown-linux-gnu
	WIDTH_ARCH=armv8.2-a+sve
	LINUX_HEADERS_SRC_DIR := $(ROOT_DIR)/linux-headers-aarch64/include
else
	ifeq ($(XLEN), 32)
		TARGET=riscv32-unknown-linux-gnu
		WIDTH_ARCH=rv32imafdc
		WIDTH_ABI=ilp32d
	else
		TARGET=riscv64-unknown-linux-gnu
		WIDTH_ARCH=rv64imafdc
		WIDTH_ABI=lp64d
	endif
	LINUX_HEADERS_SRC_DIR := $(ROOT_DIR)/linux-headers-riscv/include
endif

BUILD_DIR := $(ROOT_DIR)/build/build-$(TARGET)-$(DATE)
PREFIX := $(BUILD_DIR)/output
SYSROOT := $(PREFIX)/sysroot

export PATH := $(PREFIX)/bin:$(PATH)

ifndef ENABLE_MULTILIB
	MULTILIB=--disable-multilib
else
	MULTILIB=--enable-multilib
endif

all: $(BUILD_DIR)/build-gcc-stage2

prefix:
	mkdir -p $(PREFIX)
	mkdir -p $(SYSROOT)/usr/
	cp -a $(LINUX_HEADERS_SRC_DIR) $(SYSROOT)/usr/

$(BUILD_DIR)/build-binutils: prefix
	mkdir $@
	cd $@ && $(BINUTILS_SRC_DIR)/configure \
		--target=$(TARGET) \
		--prefix=$(PREFIX) \
		--with-sysroot=$(SYSROOT) \
		$(MULTILIB) \
		--disable-werror \
		--disable-nls \
		--with-expat=yes  \
		--disable-gdb \
		--disable-sim \
		--disable-libdecnumber \
		--disable-readline \
		--disable-gprofng
	$(MAKE) -C $@
	$(MAKE) -C $@ install

# gcc-stage1
$(BUILD_DIR)/build-gcc-stage1: $(BUILD_DIR)/build-binutils
	mkdir $@
	cd $@ && $(GCC_SRC_DIR)/configure \
		--target=$(TARGET) \
		--prefix=$(PREFIX) \
		--with-sysroot=$(SYSROOT) \
		--with-newlib \
		--without-headers \
		--disable-shared \
		--disable-threads \
		--with-system-zlib \
		--enable-tls \
		--enable-languages=c \
		--disable-libatomic \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		--disable-libgomp \
		--disable-nls \
		--disable-bootstrap \
		--src=$(GCC_SRC_DIR) \
		$(MULTILIB) \
		--with-abi=$(WIDTH_ABI) \
		--with-arch=$(WIDTH_ARCH) \
		CFLAGS="-O2" \
		CXXFLAGS="-O2" \
		CFLAGS_FOR_TARGET="-O2" \
		CXXFLAGS_FOR_TARGET="-O2"
	$(MAKE) -C $@ inhibit-libc=true all-gcc
	$(MAKE) -C $@ inhibit-libc=true install-gcc
	$(MAKE) -C $@ inhibit-libc=true all-target-libgcc
	$(MAKE) -C $@ inhibit-libc=true install-target-libgcc

$(BUILD_DIR)/build-glibc-headers: $(BUILD_DIR)/build-gcc-stage1
	mkdir $@
	cd $@ && $(GLIBC_SRC_DIR)/configure \
		CC=$(TARGET)-gcc \
		CXX=$(TARGET)-g++ \
		--host=$(TARGET) \
		--prefix=$(SYSROOT)/usr \
		--enable-shared \
		--with-headers=$(LINUX_HEADERS_SRC_DIR) \
		--enable-kernel=3.0.0 \
		$(MULTILIB)
	$(MAKE) -C $@ install-headers

$(BUILD_DIR)/build-glibc: $(BUILD_DIR)/build-gcc-stage1
	mkdir $@
	cd $@ && $(GLIBC_SRC_DIR)/configure \
		CC=$(TARGET)-gcc \
		CXX=$(TARGET)-g++ \
		CFLAGS="-O2" \
		CXXFLAGS="-O2" \
		--host=$(TARGET) \
		--prefix=/usr \
		--disable-werror \
		--enable-shared \
		--enable-obsolete-rpc \
		--with-headers=$(LINUX_HEADERS_SRC_DIR) \
		--enable-kernel=3.0.0 \
		$(MULTILIB) \
		--libdir=/usr/lib libc_cv_slibdir=/lib libc_cv_rtlddir=/lib
	$(MAKE) -C $@
	+flock $(SYSROOT)/.lock $(MAKE) -C $@ install install_root=$(SYSROOT)

# gcc-stage2
$(BUILD_DIR)/build-gcc-stage2: $(BUILD_DIR)/build-glibc $(BUILD_DIR)/build-glibc-headers
	mkdir $@
	cd $@ && $(GCC_SRC_DIR)/configure \
		--target=$(TARGET) \
		--prefix=$(PREFIX) \
		--with-sysroot=$(SYSROOT) \
		--with-system-zlib \
		--enable-shared \
		--enable-tls \
		--enable-languages=c,c++ \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		--disable-libsanitizer \
		--disable-nls \
		--disable-bootstrap \
		--src=$(GCC_SRC_DIR) \
		$(MULTILIB) \
		--with-abi=$(WIDTH_ABI) \
		--with-arch=$(WIDTH_ARCH) \
		CFLAGS="-O0 -g3" \
		CXXFLAGS="-O0 -g3" \
		CFLAGS_FOR_TARGET="-O2" \
		CXXFLAGS_FOR_TARGET="-O2"
	$(MAKE) -C $@
	$(MAKE) -C $@ install
	cp -a $(PREFIX)/$(TARGET)/lib* $(SYSROOT)
	echo "Build Success."
