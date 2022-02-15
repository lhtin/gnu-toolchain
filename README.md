# bootstrap and test on x86

1. `make update-to-trunk` 将gcc和golden-gcc更新到最新的trunk
2. `cd gcc && git am /path/to/patch` 将需要测试的patch apply上去
3. `make test` 构建test版本gcc和golden版本的gcc并跑测试，然后对比测试结果

# build and test on AArch64

TODO

1. `make update-to-trunk` 将gcc和golden-gcc更新到最新的trunk
2. `cd gcc && git am /path/to/patch` 将需要测试的patch apply上去
3. `make test-aarch64` 构建test版本gcc和golden版本的gcc并跑测试，然后对比测试结果

## Others

# gnu-toolchain

- `./build.sh make -f native.mk -j` bootstrap
- `./build.sh make -f native-simple.mk -j` disable bootstrap
- `./build.sh make -f cross-linux.mk ARCH=aarch64 -j` aarch64-unknown-linux-gun
- `./build.sh make -f cross-elf.mk ARCH=aarch64 -j` aarch64-unknown-elf
- `./build.sh make -f cross-linux.mk -j` riscv64-unknown-linux-gnu
- `./build.sh make -f cross-elf.mk -j` riscv64-unknown-elf

## dependence

- `wget https://gmplib.org/download/gmp-6.2.1/gmp-6.2.1.tar.xz`
- `wget https://ftp.gnu.org/gnu/mpfr/mpfr-4.1.0.tar.gz --no-check-certificate`
- `wget https://ftp.gnu.org/gnu/mpc/mpc-1.2.1.tar.gz --no-check-certificate`
