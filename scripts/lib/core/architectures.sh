#!/bin/bash
if [ -z "${ALL_ARCHITECTURES+x}" ]; then
    readonly ALL_ARCHITECTURES=(
    x86_64 x86_64_x32 i486 ix86le
    
    aarch64 aarch64_be
    arm32v5le arm32v5lehf arm32v7le arm32v7lehf arm32v7neon
    armeb armebv7hf armebhf armel armelhf armv5l armv5lhf armv6 armv6sf armv7m armv7r
    
    mips32be mips32le mips32besf mips32lesf
    mips64 mips64le mips64n32 mips64n32el
    
    ppc32be ppc32besf ppc32le ppc32lesf
    ppc64be ppc64le
    
    riscv32 riscv64
    
    m68k m68k_coldfire microblaze microblazeel or1k s390x
    sh2 sh2eb sh4 sh4eb loongarch64
    
    sparc64 nios2 arcle_hs38
)
fi

if [ -z "${ARCH_CONFIG+x}" ]; then
    declare -gA ARCH_CONFIG
fi

ARCH_CONFIG[x86_64]="
musl_name=x86_64-linux-musl
musl_cross=x86_64
glibc_name=x86_64-buildroot-linux-gnu
bootlin_arch=x86-64-core-i7
bootlin_url=x86-64--glibc--stable-2024.02-1.tar.bz2
cflags=-march=x86-64
config_arch=x86_64
"

ARCH_CONFIG[x86_64_x32]="
musl_name=x86_64-linux-muslx32
musl_cross=x86_64-linux-muslx32
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=x86-64 -mx32 -Wno-error=type-limits
config_arch=x86_64
"

ARCH_CONFIG[i486]="
musl_name=i486-linux-musl
musl_cross=i486
glibc_name=i686-buildroot-linux-gnu
bootlin_arch=x86-i686
bootlin_url=x86-i686--glibc--stable-2024.02-1.tar.bz2
cflags=-march=i486
config_arch=i386
"

ARCH_CONFIG[ix86le]="
musl_name=i686-linux-musl
musl_cross=i686
glibc_name=i686-buildroot-linux-gnu
bootlin_arch=x86-i686
bootlin_url=x86-i686--glibc--stable-2024.02-1.tar.bz2
cflags=-march=i486 -mno-sse -mno-sse2
config_arch=i386
"

ARCH_CONFIG[aarch64]="
musl_name=aarch64-linux-musl
musl_cross=aarch64
glibc_name=aarch64-buildroot-linux-gnu
bootlin_arch=aarch64
bootlin_url=aarch64--glibc--stable-2024.02-1.tar.bz2
cflags=-march=armv8-a
config_arch=aarch64
"

ARCH_CONFIG[aarch64_be]="
musl_name=aarch64_be-linux-musl
musl_cross=aarch64_be
glibc_name=aarch64_be-buildroot-linux-gnu
bootlin_arch=aarch64be
bootlin_url=aarch64be--glibc--stable-2024.02-1.tar.bz2
cflags=-march=armv8-a -mbig-endian
config_arch=aarch64
"

ARCH_CONFIG[arm32v5le]="
musl_name=arm-linux-musleabi
musl_cross=arm-linux-musleabi
glibc_name=arm-buildroot-linux-gnueabi
bootlin_arch=armv5-eabi
bootlin_url=armv5-eabi--glibc--stable-2024.02-1.tar.bz2
cflags=-march=armv5te -marm -mno-unaligned-access
config_arch=arm
"

ARCH_CONFIG[arm32v5lehf]="
musl_name=arm-linux-musleabihf
musl_cross=arm-linux-musleabihf
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=armv5te+fp -mfpu=vfp -mfloat-abi=hard -marm
config_arch=arm
"

ARCH_CONFIG[arm32v7le]="
musl_name=armv7l-linux-musleabihf
musl_cross=armv7l-linux-musleabihf
glibc_name=arm-buildroot-linux-gnueabihf
bootlin_arch=armv7-eabihf
bootlin_url=armv7-eabihf--glibc--stable-2024.02-1.tar.bz2
cflags=-march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard -mthumb -mthumb-interwork
config_arch=arm
"

ARCH_CONFIG[arm32v7lehf]="
musl_name=armv7l-linux-musleabihf
musl_cross=armv7l-linux-musleabihf
glibc_name=arm-buildroot-linux-gnueabihf
bootlin_arch=armv7-eabihf
bootlin_url=armv7-eabihf--glibc--stable-2024.02-1.tar.bz2
cflags=-march=armv7-a -mfpu=neon-vfpv3 -mfloat-abi=hard -mthumb -mthumb-interwork
config_arch=arm
"

ARCH_CONFIG[arm32v7neon]="
musl_name=armv7l-linux-musleabihf
musl_cross=armv7l-linux-musleabihf
glibc_name=arm-buildroot-linux-gnueabihf
bootlin_arch=armv7-eabihf
bootlin_url=armv7-eabihf--glibc--stable-2024.02-1.tar.bz2
cflags=-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard -mthumb -mthumb-interwork
config_arch=arm
"

ARCH_CONFIG[armeb]="
musl_name=armeb-linux-musleabi
musl_cross=armeb-linux-musleabi
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=armv5te -mbig-endian
config_arch=arm
"

ARCH_CONFIG[armebv7hf]="
musl_name=armeb-linux-musleabihf
musl_cross=armeb-linux-musleabihf
glibc_name=armeb-buildroot-linux-gnueabihf
bootlin_arch=armebv7-eabihf
bootlin_url=armebv7-eabihf--glibc--stable-2024.02-1.tar.bz2
cflags=-march=armv7-a -mbig-endian -mfpu=vfpv3 -mfloat-abi=hard
config_arch=arm
"

ARCH_CONFIG[armv6]="
musl_name=armv6-linux-musleabihf
musl_cross=armv6-linux-musleabihf
glibc_name=arm-buildroot-linux-gnueabihf
bootlin_arch=armv6-eabihf
bootlin_url=armv6-eabihf--glibc--stable-2024.02-1.tar.bz2
cflags=-march=armv6 -mfpu=vfp -mfloat-abi=hard -mno-unaligned-access
config_arch=arm
"

ARCH_CONFIG[armv7m]="
musl_name=armv7m-linux-musleabi
musl_cross=armv7m-linux-musleabi
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=armv7-m -mthumb
config_arch=arm
"

ARCH_CONFIG[armv7r]="
musl_name=armv7r-linux-musleabihf
musl_cross=armv7r-linux-musleabihf
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=armv7-r -mfpu=vfpv3-d16 -mfloat-abi=hard -mthumb
config_arch=arm
"

ARCH_CONFIG[armebhf]="
musl_name=armeb-linux-musleabihf
musl_cross=armeb-linux-musleabihf
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=armv5te -mfpu=vfp -mfloat-abi=hard -mbig-endian
config_arch=arm
"

ARCH_CONFIG[armel]="
musl_name=armel-linux-musleabi
musl_cross=armel-linux-musleabi
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=armv4t -marm
config_arch=arm
"

ARCH_CONFIG[armelhf]="
musl_name=armel-linux-musleabihf
musl_cross=armel-linux-musleabihf
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=armv4t -mfpu=vfp -mfloat-abi=hard -marm
config_arch=arm
"

ARCH_CONFIG[armv5l]="
musl_name=armv5l-linux-musleabi
musl_cross=armv5l-linux-musleabi
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=armv5te -marm -mno-unaligned-access
config_arch=arm
"

ARCH_CONFIG[armv5lhf]="
musl_name=armv5l-linux-musleabihf
musl_cross=armv5l-linux-musleabihf
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=armv5te -mfpu=vfp -mfloat-abi=hard -marm -mno-unaligned-access
config_arch=arm
"

ARCH_CONFIG[armv6sf]="
musl_name=armv6-linux-musleabi
musl_cross=armv6-linux-musleabi
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=armv6 -marm -mno-unaligned-access
config_arch=arm
"

ARCH_CONFIG[mips32be]="
musl_name=mips-linux-musl
musl_cross=mips
glibc_name=mips-buildroot-linux-gnu
bootlin_arch=mips32
bootlin_url=mips32--glibc--stable-2024.02-1.tar.bz2
cflags=-march=mips32 -mabi=32 -EB
config_arch=mips
"

ARCH_CONFIG[mips32le]="
musl_name=mipsel-linux-musl
musl_cross=mipsel
glibc_name=mipsel-buildroot-linux-gnu
bootlin_arch=mips32el
bootlin_url=mips32el--glibc--stable-2024.02-1.tar.bz2
cflags=-march=mips32 -mabi=32
config_arch=mips
"

ARCH_CONFIG[mips32besf]="
musl_name=mips-linux-muslsf
musl_cross=mips-linux-muslsf
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=mips32 -mabi=32 -EB -msoft-float
config_arch=mips
"

ARCH_CONFIG[mips32lesf]="
musl_name=mipsel-linux-muslsf
musl_cross=mipsel-linux-muslsf
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=mips32 -mabi=32 -msoft-float
config_arch=mips
"

ARCH_CONFIG[mips64]="
musl_name=mips64-linux-musl
musl_cross=mips64
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=mips64 -mabi=64
config_arch=mips64
"

ARCH_CONFIG[mips64le]="
musl_name=mips64el-linux-musl
musl_cross=mips64el
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=mips64 -mabi=64
config_arch=mips64
"

ARCH_CONFIG[mips64n32]="
musl_name=mips64-linux-musln32
musl_cross=mips64-linux-musln32
glibc_name=mips64-buildroot-linux-gnu
bootlin_arch=mips64-n32
bootlin_url=mips64-n32--glibc--stable-2024.02-1.tar.bz2
cflags=-march=mips64 -mabi=n32
config_arch=mips64
"

ARCH_CONFIG[mips64n32el]="
musl_name=mips64el-linux-musln32
musl_cross=mips64el-linux-musln32
glibc_name=mips64el-buildroot-linux-gnu
bootlin_arch=mips64el-n32
bootlin_url=mips64el-n32--glibc--stable-2024.02-1.tar.bz2
cflags=-march=mips64 -mabi=n32
config_arch=mips64
"


ARCH_CONFIG[ppc32be]="
musl_name=powerpc-linux-musl
musl_cross=powerpc
glibc_name=powerpc-buildroot-linux-gnu
bootlin_arch=powerpc-e500mc
bootlin_url=powerpc-e500mc--glibc--stable-2024.02-1.tar.bz2
cflags=-mcpu=powerpc -m32 -mno-altivec -mno-vsx
config_arch=powerpc
"

ARCH_CONFIG[ppc32besf]="
musl_name=powerpc-linux-muslsf
musl_cross=powerpc-linux-muslsf
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-mcpu=powerpc -m32 -msoft-float
config_arch=powerpc
"

ARCH_CONFIG[ppc32le]="
musl_name=powerpcle-linux-musl
musl_cross=powerpcle
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-mcpu=powerpc -m32 -mlittle-endian
config_arch=powerpc
"

ARCH_CONFIG[ppc32lesf]="
musl_name=powerpcle-linux-muslsf
musl_cross=powerpcle-linux-muslsf
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-mcpu=powerpc -m32 -mlittle-endian -msoft-float
config_arch=powerpc
"

ARCH_CONFIG[ppc64be]="
musl_name=powerpc64-linux-musl
musl_cross=powerpc64
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-mcpu=power4 -m64
config_arch=powerpc64
"

ARCH_CONFIG[ppc64le]="
musl_name=powerpc64le-linux-musl
musl_cross=powerpc64le
glibc_name=powerpc64le-buildroot-linux-gnu
bootlin_arch=powerpc64le-power8
bootlin_url=powerpc64le-power8--glibc--stable-2024.02-1.tar.bz2
cflags=-mcpu=powerpc64le -m64 -mlittle-endian
config_arch=powerpc64
"

ARCH_CONFIG[riscv32]="
musl_name=riscv32-linux-musl
musl_cross=riscv32
glibc_name=riscv32-buildroot-linux-gnu
bootlin_arch=riscv32-ilp32d
bootlin_url=riscv32-ilp32d--glibc--stable-2024.05-1.tar.xz
cflags=-march=rv32gc -mabi=ilp32d
config_arch=riscv
"

ARCH_CONFIG[riscv64]="
musl_name=riscv64-linux-musl
musl_cross=riscv64
glibc_name=riscv64-buildroot-linux-gnu
bootlin_arch=riscv64-lp64d
bootlin_url=riscv64-lp64d--glibc--stable-2024.02-1.tar.bz2
cflags=-march=rv64gc -mabi=lp64d
config_arch=riscv64
"


ARCH_CONFIG[m68k]="
musl_name=m68k-linux-musl
musl_cross=m68k
glibc_name=m68k-buildroot-linux-gnu
bootlin_arch=m68k
bootlin_url=m68k-68xxx--glibc--stable-2024.02-1.tar.bz2
cflags=-mcpu=68020
config_arch=m68k
"

ARCH_CONFIG[microblaze]="
musl_name=microblaze-linux-musl
musl_cross=microblaze
glibc_name=microblaze-buildroot-linux-gnu
bootlin_arch=microblazebe
bootlin_url=microblazebe--glibc--stable-2024.02-1.tar.bz2
cflags=-mcpu=v9.0
config_arch=microblaze
"

ARCH_CONFIG[microblazeel]="
musl_name=microblazeel-linux-musl
musl_cross=microblazeel
glibc_name=microblazeel-buildroot-linux-gnu
bootlin_arch=microblazeel
bootlin_url=microblazeel--glibc--stable-2024.02-1.tar.bz2
cflags=-mcpu=v9.0 -mlittle-endian
config_arch=microblaze
"

ARCH_CONFIG[or1k]="
musl_name=or1k-linux-musl
musl_cross=or1k
glibc_name=or1k-buildroot-linux-gnu
bootlin_arch=openrisc
bootlin_url=openrisc--glibc--stable-2024.02-1.tar.bz2
cflags=
config_arch=openrisc
"

ARCH_CONFIG[s390x]="
musl_name=s390x-linux-musl
musl_cross=s390x
glibc_name=s390x-buildroot-linux-gnu
bootlin_arch=s390x-z13
bootlin_url=s390x-z13--glibc--stable-2024.02-1.tar.bz2
cflags=
config_arch=s390x
"

ARCH_CONFIG[sh2]="
musl_name=sh2-linux-musl
musl_cross=sh2
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-m2
config_arch=sh
"

ARCH_CONFIG[sh2eb]="
musl_name=sh2eb-linux-musl
musl_cross=sh2eb
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-m2 -mb
config_arch=sh
"

ARCH_CONFIG[sh4]="
musl_name=sh4-linux-musl
musl_cross=sh4
glibc_name=sh4-buildroot-linux-gnu
bootlin_arch=sh-sh4
bootlin_url=sh-sh4--glibc--stable-2024.02-1.tar.bz2
cflags=-m4
config_arch=sh
"

ARCH_CONFIG[sh4eb]="
musl_name=sh4eb-linux-musl
musl_cross=sh4eb
glibc_name=sh4aeb-buildroot-linux-gnu
bootlin_arch=sh-sh4aeb
bootlin_url=sh-sh4aeb--glibc--stable-2024.02-1.tar.bz2
cflags=-mb
config_arch=sh
"

ARCH_CONFIG[sparc64]="
musl_name=
musl_cross=
glibc_name=sparc64-buildroot-linux-gnu
bootlin_arch=sparc64
bootlin_url=sparc64--glibc--stable-2024.02-1.tar.bz2
cflags=-mcpu=v9 -m64
config_arch=sparc64
"

ARCH_CONFIG[nios2]="
musl_name=
musl_cross=
glibc_name=nios2-buildroot-linux-gnu
bootlin_arch=nios2
bootlin_url=nios2--glibc--stable-2024.02-1.tar.bz2
cflags=-march=r1
config_arch=nios2
"

ARCH_CONFIG[m68k_coldfire]="
musl_name=
musl_cross=
glibc_name=m68k-buildroot-linux-gnu
bootlin_arch=m68k-coldfire
bootlin_url=m68k-coldfire--glibc--stable-2024.02-1.tar.bz2
cflags=-mcpu=5208 -fPIC
config_arch=m68k
"

ARCH_CONFIG[arcle_hs38]="
musl_name=
musl_cross=
glibc_name=arc-buildroot-linux-gnu
bootlin_arch=arcle-hs38
bootlin_url=arcle-hs38--glibc--stable-2024.02-1.tar.bz2
cflags=-mcpu=hs38 -matomic
config_arch=arc
"

ARCH_CONFIG[loongarch64]="
musl_name=loongarch64-unknown-linux-musl
musl_cross=loongarch64-unknown-linux-musl
glibc_name=loongarch64-unknown-linux-gnu
bootlin_arch=
bootlin_url=
cflags=-march=loongarch64 -mabi=lp64d
config_arch=loongarch64
custom_musl_url=https://github.com/loong64/cross-tools/releases/download/20250911/x86_64-cross-tools-loongarch64-unknown-linux-musl-stable.tar.xz
custom_glibc_url=https://github.com/loong64/cross-tools/releases/download/20250911/x86_64-cross-tools-loongarch64-unknown-linux-gnu-stable.tar.xz
"

export ALL_ARCHITECTURES
export ARCH_CONFIG