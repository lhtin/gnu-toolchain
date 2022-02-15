ROOT_DIR := $(shell pwd)

ifndef DATE
	DATE := $(shell date +%Y_%m_%d_%H_%M_%S)
endif

BUILD_DIR := $(ROOT_DIR)/build-$(DATE)
PREFIX := $(BUILD_DIR)/output-crossed
SYSROOT := $(PREFIX)/sysroot
CC=$(TARGET)-gcc
CXX=$(TARGET)-g++
LINUX_HEADERS_SRCDIR := $(ROOT_DIR)/linux-headers/include

ifndef VENDOR
	VENDOR=unknown
endif
ifeq ($(XLEN), 32)
	TARGET=riscv32-$(VENDOR)-linux-gnu
else
	TARGET=riscv64-$(VENDOR)-linux-gnu
endif

export PATH := $(BUILD_DIR)/output/bin:$(PATH)

ifndef CFLAGS_FOR_HOST
	CFLAGS=-O3 -fschedule-insns -fschedule-insns2 -static
else
	CFLAGS=$(CFLAGS_FOR_HOST)
endif

ifndef CXXFLAGS_FOR_HOST
	CXXFLAGS=-O3 -fschedule-insns -fschedule-insns2 -static
else
	CXXFLAGS=$(CXXFLAGS_FOR_HOST)
endif

LDFLAGS=-static

all: $(BUILD_DIR)/build-binutils-crossed $(BUILD_DIR)/build-gcc-stage1-crossed

prefix:
	mkdir -p $(PREFIX)
	mkdir -p $(SYSROOT)/usr/
	cp -a $(LINUX_HEADERS_SRCDIR) $(SYSROOT)/usr/

$(BUILD_DIR)/build-binutils-crossed: prefix
	mkdir -p $@
	cd $@ && ../../binutils-gdb/configure \
		--host=$(TARGET) \
		--target=$(TARGET) \
		--prefix=$(PREFIX) \
		--with-sysroot=$(SYSROOT) \
		--disable-werror \
		--with-expat=yes  \
		--disable-gdb \
		--disable-sim \
		--disable-libdecnumber \
		--disable-readline \
		CC=$(CC) \
		CXX=$(CXX) \
		CFLAGS="$(CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS)" \
		LDFLAGS="$(LDFLAGS)"
	$(MAKE) -C $@ 2>&1 | tee -a $@/build.log
	$(MAKE) -C $@ install 2>&1 | tee -a $@/build.log

$(BUILD_DIR)/build-gmp: prefix
	mkdir $@
	cd $@ && ../../gmp-6.2.1/configure \
		--host=$(TARGET) \
		--prefix=$(PREFIX)/gmp \
		CFLAGS="$(CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS)"
	$(MAKE) -C $@ 2>&1 | tee -a $@/build.log
	$(MAKE) -C $@ install 2>&1 | tee -a $@/build.log

$(BUILD_DIR)/build-mpfr: $(BUILD_DIR)/build-gmp
	mkdir $@
	cd $@ && ../../mpfr-4.1.0/configure \
		--host=$(TARGET) \
		--prefix=$(PREFIX)/mpfr \
		--with-gmp=$(PREFIX)/gmp \
		CFLAGS="$(CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS)"
	$(MAKE) -C $@ 2>&1 | tee -a $@/build.log
	$(MAKE) -C $@ install 2>&1 | tee -a $@/build.log

$(BUILD_DIR)/build-mpc: $(BUILD_DIR)/build-mpfr
	mkdir $@
	cd $@ && ../../mpc-1.2.1/configure \
		--host=$(TARGET) \
		--prefix=$(PREFIX)/mpc \
		--with-gmp=$(PREFIX)/gmp \
		--with-mpfr=$(PREFIX)/mpfr \
		CFLAGS="$(CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS)"
	$(MAKE) -C $@ 2>&1 | tee -a $@/build.log
	$(MAKE) -C $@ install 2>&1 | tee -a $@/build.log

# for crossed native, cannot use CFLAGS and CXXFLAGS to CC and CXX compiler.
# Because CFLAGS and CXXFLAGS will pass to both native compiler and host compiler(i.e. CC and CXX)
$(BUILD_DIR)/build-gcc-stage1-crossed: $(BUILD_DIR)/build-mpc
	mkdir $@
	cd $@ && ../../gcc/configure \
		--host=$(TARGET) \
		--target=$(TARGET) \
		--prefix=$(PREFIX) \
		--with-sysroot=$(SYSROOT) \
		--with-gmp=$(PREFIX)/gmp \
		--with-mpfr=$(PREFIX)/mpfr \
		--with-mpc=$(PREFIX)/mpc \
		--without-headers \
		--disable-shared \
		--disable-threads \
		--enable-tls \
		--enable-languages=c \
		--disable-libatomic \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		--disable-libgomp \
		--disable-nls \
		--disable-bootstrap \
		--src=../../gcc \
		--disable-multilib \
		--with-abi=$(WIDTH_ABI) \
		--with-arch=$(WIDTH_ARCH) \
		CC="$(CC) $(CFLAGS)" \
		CXX="$(CXX) $(CFLAGS)" \
		CFLAGS="-O3" \
		CXXFLAGS="-O3" \
		CFLAGS_FOR_TARGET="$(CFLAGS)" \
		CXXFLAGS_FOR_TARGET="$(CFLAGS)" \
		LDFLAGS="$(LDFLAGS)"
	$(MAKE) -C $@ all-gcc 2>&1 | tee -a $@/build.log
	$(MAKE) -C $@ install-gcc 2>&1 | tee -a $@/build.log