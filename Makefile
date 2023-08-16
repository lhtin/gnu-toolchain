ROOT_DIR := $(shell pwd)
PREFIX ?= $(ROOT_DIR)/output

all: build-gcc build-gdb build-binutils

build-gdb: clean
	mkdir -p build/$@
	cd build/$@ && ../../binutils/configure \
		--prefix=$(PREFIX) \
		--enable-gdbserver \
		--disable-gas \
		--disable-binutils \
		--disable-ld \
		--disable-gold \
		--disable-gprof
	$(MAKE) -C build/$@
	$(MAKE) -C build/$@ install

build-binutils: build-gdb clean
	mkdir -p build/$@
	cd build/$@ && ../../binutils/configure \
		--prefix=$(PREFIX) \
		--disable-werror \
		--with-expat=yes  \
		--disable-gdb \
		--disable-sim \
		--disable-libdecnumber \
		--disable-readline
	$(MAKE) -C build/$@
	$(MAKE) -C build/$@ install

build-gcc: build-binutils clean
	mkdir -p build/$@
	cd build/$@ && ../../gcc/configure \
		--prefix=$(PREFIX) \
		--disable-bootstrap \
		--disable-multilib
	$(MAKE) -C build/$@
	$(MAKE) -C build/$@ install

clean:
	rm -rf build/build-binutils build/build-gdb build/build-gcc
	rm -rf output

update-gcc:
	cd gcc && git pull origin trunk

update-golden-gcc: update-gcc
	cd golden-gcc && git pull origin trunk

update-to-trunk: update-golden-gcc

build-test-gcc-x86:
	$(MAKE) -f native.mk DATE=gcc-x86 build-test

build-test-golden-gcc-x86: build-test-gcc-x86
	$(MAKE) -f native.mk DATE=golden-gcc-x86 GCC_SRC_DIR=$(ROOT_DIR)/golden-gcc build-test

test-x86: build-test-gcc-x86 build-test-golden-gcc-x86
	python3 ./check.py --golden_dir build/build-native-golden-gcc-x86/build-test-gcc/gcc/testsuite --test_dir build/build-native-gcc-x86/build-test-gcc/gcc/testsuite

build-test-gcc-aarch64:
	$(MAKE) -f cross-elf.mk DATE=gcc-aarch64 build-test

build-test-golden-gcc-aarch64: build-test-gcc-aarch64
	$(MAKE) -f cross-elf.mk DATE=golden-gcc-aarch64 GCC_SRC_DIR=$(ROOT_DIR)/golden-gcc build-test

test-aarch64: build-test-gcc-aarch64 build-test-golden-gcc-aarch64
	python3 ./check.py --golden_dir build/build-aarch64-unknown-elf-golden-gcc-aarch64/build-gcc-stage2/gcc/testsuite --test_dir build/build-aarch64-unknown-elf-gcc-aarch64/build-gcc-stage2/gcc/testsuite
