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
		--disable-multilib \
		--with-sysroot=$(PREFIX)/$(TARGET) \
	$(MAKE) -C build/$@
	$(MAKE) -C build/$@ install

clean:
	rm -rf build
	rm -rf output


build-test-gcc:
	$(MAKE) -f native.mk DATE=gcc build-test

build-test-golden-gcc:
	$(MAKE) -f native.mk DATE=golden-gcc GCC_SRC_DIR=$(ROOT_DIR)/golden-gcc build-test

golden-gcc:
	cp -rf gcc golden-gcc

update-gcc: golden-gcc
	cd gcc && git pull origin trunk

update-golden-gcc: golden-gcc update-gcc
	cd golden-gcc && git pull origin trunk

update-to-trunk: update-golden-gcc

test: build-test-gcc build-test-golden-gcc
	./check.py --golden_dir build/build-native-golden-gcc/build-test-gcc/gcc/testsuite --test_dir build/build-native-gcc/build-test-gcc/gcc/testsuite
