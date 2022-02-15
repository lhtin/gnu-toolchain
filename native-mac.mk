ROOT_DIR := $(shell pwd)

ifndef DATE
	DATE := $(shell date +%Y_%m_%d_%H_%M_%S)
endif

BUILD_DIR := $(ROOT_DIR)/build/build-native-$(DATE)
PREFIX := $(BUILD_DIR)/output
GCC_SRC_DIR=$(ROOT_DIR)/gcc

all: $(BUILD_DIR)/build-gcc

prefix:
	mkdir -p $(PREFIX)

$(BUILD_DIR)/build-gcc: prefix
	mkdir $@
	cd $@ && $(GCC_SRC_DIR)/configure \
		--prefix=$(PREFIX) \
		--disable-multilib \
		--with-gmp=/usr/local/Cellar/gmp/6.2.1_1 \
		--with-mpfr=/usr/local/Cellar/mpfr/4.2.0-p9 \
		--with-mpc=/usr/local/Cellar/libmpc/1.3.1 \
		--enable-language=c,c++ \
		CFLAGS="-O2" \
		CXXFLAGS="-O2" \
		CFLAGS_FOR_TARGET="-O2" \
		CXXFLAGS_FOR_TARGET="-O2"
	$(MAKE) -C $@
	$(MAKE) -C $@ install
	echo "Build Success."
