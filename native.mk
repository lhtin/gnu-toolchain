ROOT_DIR := $(shell pwd)

ifndef DATE
	DATE := $(shell date +%Y_%m_%d_%H_%M_%S)
endif

BUILD_DIR := $(ROOT_DIR)/build/build-native-$(DATE)
PREFIX := $(BUILD_DIR)/output
GCC_SRC_DIR ?= $(ROOT_DIR)/gcc

all: $(BUILD_DIR)/build-gcc

build-test: $(BUILD_DIR)/build-test-gcc

prefix:
	mkdir -p $(PREFIX)

$(BUILD_DIR)/build-gcc: prefix
	rm -rf $@
	mkdir $@
	cd $@ && $(GCC_SRC_DIR)/configure \
		--prefix=$(PREFIX) \
		--disable-multilib \
		CFLAGS="-O0 -g3" \
		CXXFLAGS="-O0 -g3" \
		CFLAGS_FOR_TARGET="-O0 -g3" \
		CXXFLAGS_FOR_TARGET="-O0 -g3"
	$(MAKE) -C $@
	$(MAKE) -C $@ install
	echo "Build Success."

$(BUILD_DIR)/build-test-gcc: prefix
	rm -rf $@
	mkdir $@
	cd $@ && $(GCC_SRC_DIR)/configure \
		--prefix=$(PREFIX) \
		--disable-multilib \
		CFLAGS="-O0 -g3" \
		CXXFLAGS="-O0 -g3" \
		CFLAGS_FOR_TARGET="-O0 -g3" \
		CXXFLAGS_FOR_TARGET="-O0 -g3"
	$(MAKE) -C $@
	$(MAKE) -C $@ install
	echo "Build Success."
	-$(MAKE) -C $@/build-gcc check
