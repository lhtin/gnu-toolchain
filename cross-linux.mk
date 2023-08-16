ROOT_DIR := $(shell pwd)
BINUTILS_SRC_DIR=$(ROOT_DIR)/binutils
GCC_SRC_DIR=$(ROOT_DIR)/gcc
GLIBC_SRC_DIR=$(ROOT_DIR)/glibc
DEJAGNU_SRC_DIR=$(ROOT_DIR)/dejagnu
QEMU_SRC_DIR=$(ROOT_DIR)/qemu
LINUX_HEADERS_SRC_DIR := $(ROOT_DIR)/linux-headers-aarch64/include
TARGET=aarch64-unknown-linux-gnu
WIDTH_ARCH=armv8.2-a+sve

ifndef DATE
	DATE := $(shell date +%Y_%m_%d_%H_%M_%S)
endif

BUILD_DIR := $(ROOT_DIR)/build/build-$(TARGET)-$(DATE)
PREFIX := $(BUILD_DIR)/output
SYSROOT := $(PREFIX)/sysroot

export PATH := $(PREFIX)/bin:$(PATH)

build-test: test

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

$(BUILD_DIR)/build-dejagnu: prefix
	mkdir $@
	cd $@ && $(DEJAGNU_SRC_DIR)/configure \
	prefix=$(PREFIX)
	$(MAKE) -C $@
	$(MAKE) -C $@ install

$(BUILD_DIR)/build-qemu: prefix
	mkdir $@
	cd $@ && $(QEMU_SRC_DIR)/configure \
		--prefix=$(PREFIX) \
		--target-list=aarch64-linux-user \
		--interp-prefix=$(PREFIX)/sysroot \
		--python=python3
	$(MAKE) -C $@
	$(MAKE) -C $@ install

test: 
	$(SIM_PREPARE) $(MAKE) -C $(BUILD_DIR)/build-gcc-stage2 check-gcc RUNTESTFLAGS="--target_board=aarch64-sim aarch64.exp=abd_run_1.c"
