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
musl_sha512=52abd1a56e670952116e35d1a62e048a9b6160471d988e16fa0e1611923dd108a581d2e00874af5eb04e4968b1ba32e0eb449a1f15c3e4d5240ebe09caf5a9f3
cflags=-march=x86-64
config_arch=x86_64
bootlin_sha512=02b62c26b3cab277623198dc48d9f1c1f6d12018911acf2d66aafde370c6c40d92ccc58b63255d0726636e39fd659f6430473241508e37ad59fc0bbd74ac4760
"

ARCH_CONFIG[x86_64_x32]="
musl_name=x86_64-linux-muslx32
musl_cross=x86_64-linux-muslx32
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=x86-64 -mx32 -Wno-error=type-limits
config_arch=x86_64
musl_sha512=3b4cb87e94ad822934793139653fce216016f5d96309094f46ec152d369d4ad67c5e21b7276f43ff055433c42e7c38a5c0fe6ee0c56e1069729d447e45a2f122
"

ARCH_CONFIG[i486]="
musl_name=i486-linux-musl
musl_cross=i486
glibc_name=i686-buildroot-linux-gnu
bootlin_arch=x86-i686
bootlin_url=x86-i686--glibc--stable-2024.02-1.tar.bz2
cflags=-march=i486
config_arch=i386
musl_sha512=0a6e508d919d2b5404e53c5bad7ea10924967c4b528012495ecc41ca3f4b371a0da4d814a2a5a18e079b1c330fa808ab0eaa924a3571f3792bcf9004feee856c
bootlin_sha512=e57a0c0f49917c8dfbc12bb949d3bbc33fd9b824f0cd776c65b10f410c5da128e98f2065ab6053926e32387b252dfee3c9283e32847199c2f68fab804ba9e0c2
"

ARCH_CONFIG[ix86le]="
musl_name=i686-linux-musl
musl_cross=i686
glibc_name=i686-buildroot-linux-gnu
bootlin_arch=x86-i686
bootlin_url=x86-i686--glibc--stable-2024.02-1.tar.bz2
cflags=-march=i486 -mno-sse -mno-sse2
config_arch=i386
musl_sha512=5047afc68170a2910895db2dfa448227e71a984bfa2130a1bc946fd1015d722b80b15e4abf90c64300815aa84fe781cc8b8a72f10174f9dce96169e035911880
bootlin_sha512=e57a0c0f49917c8dfbc12bb949d3bbc33fd9b824f0cd776c65b10f410c5da128e98f2065ab6053926e32387b252dfee3c9283e32847199c2f68fab804ba9e0c2
"

ARCH_CONFIG[aarch64]="
musl_name=aarch64-linux-musl
musl_cross=aarch64
glibc_name=aarch64-buildroot-linux-gnu
bootlin_arch=aarch64
bootlin_url=aarch64--glibc--stable-2024.02-1.tar.bz2
musl_sha512=8695ff86979cdf30fbbcd33061711f5b1ebc3c48a87822b9ca56cde6d3a22abd4dab30fdcd1789ac27c6febbaeb9e5bde59d79d66552fae53d54cc1377a19272
cflags=-march=armv8-a
config_arch=aarch64
bootlin_sha512=1122cf6a0d6d8438181942011432c68d63807566117dde2e24171dbac5413dc752f687cd41af6e0557aab66bb89c004f5b246ec7f390fa730f1c0d4726bf4e9a
"

ARCH_CONFIG[aarch64_be]="
musl_name=aarch64_be-linux-musl
musl_cross=aarch64_be
glibc_name=aarch64_be-buildroot-linux-gnu
bootlin_arch=aarch64be
bootlin_url=aarch64be--glibc--stable-2024.02-1.tar.bz2
cflags=-march=armv8-a -mbig-endian
config_arch=aarch64
musl_sha512=1196cefffca4ab1add29c0d80bfebeb6a9f0eb2f1dd89f2ba5119af23b7177e2ad7fff21594f7dbfb3c5b0624e0a5f78c1678d12e1604f51c7cecb27ce4bf8b5
bootlin_sha512=16425c406519b24865b4077ab050805120d9b8fb7ef19d884fb5633af6e2d169a131dfbdde02f5a218e8e13a933b7c6b04e0d109f077790178f475a4f7d65cab
"

ARCH_CONFIG[arm32v5le]="
musl_name=arm-linux-musleabi
musl_cross=arm-linux-musleabi
glibc_name=arm-buildroot-linux-gnueabi
bootlin_arch=armv5-eabi
bootlin_url=armv5-eabi--glibc--stable-2024.02-1.tar.bz2
musl_sha512=000e9e49a24ad581c2096c52dc28942688c422b8beed8c6b7c46f82029bbebae8e513118a44da36827907e215c6eca543b5d87da762ed6e37ead0a739ef403b7
cflags=-march=armv5te -marm -mno-unaligned-access
config_arch=arm
bootlin_sha512=d3b8f0c84ee589a255ec59a6eb51bc02de502c411fa0bac6a1a784e46f01efdc322d32a6a67c7185fb6062ae4b5bd296d265868f86effb8c8d6f9158ff66ed5d
"

ARCH_CONFIG[arm32v5lehf]="
musl_name=arm-linux-musleabihf
musl_cross=arm-linux-musleabihf
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=armv5te+fp -mfpu=vfp -mfloat-abi=hard -marm
config_arch=arm
musl_sha512=fe006d9176cedb453fd817f892f61f6bac273c15879f9c537e22c75b8da4995991211f6d23b0c0c97a87121fe55cf9f9f29cc3d1cf9376804535f07b6c017729
"

ARCH_CONFIG[arm32v7le]="
musl_name=armv7l-linux-musleabihf
musl_cross=armv7l-linux-musleabihf
glibc_name=arm-buildroot-linux-gnueabihf
bootlin_arch=armv7-eabihf
bootlin_url=armv7-eabihf--glibc--stable-2024.02-1.tar.bz2
cflags=-march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard -mthumb -mthumb-interwork
config_arch=arm
musl_sha512=1bb399a61da425faac521df9b8d303e60ad101f6c7827469e0b4bc685ce1f3dedc606ac7b1e8e34d79f762a3bfe3e8ab479a97e97d9f36fbd9fc5dc9d7ed6fd1
bootlin_sha512=96d35eac687bebea5c6c79cd26280b3fab5f2a5bf105b86d70728a0895b12118e839fcceb9ec2b1e6b3ea2ade9cbd069635709a45ccad4a4ed42f647857e0d18
"

ARCH_CONFIG[arm32v7lehf]="
musl_name=armv7l-linux-musleabihf
musl_cross=armv7l-linux-musleabihf
glibc_name=arm-buildroot-linux-gnueabihf
bootlin_arch=armv7-eabihf
bootlin_url=armv7-eabihf--glibc--stable-2024.02-1.tar.bz2
cflags=-march=armv7-a -mfpu=neon-vfpv3 -mfloat-abi=hard -mthumb -mthumb-interwork
config_arch=arm
musl_sha512=1bb399a61da425faac521df9b8d303e60ad101f6c7827469e0b4bc685ce1f3dedc606ac7b1e8e34d79f762a3bfe3e8ab479a97e97d9f36fbd9fc5dc9d7ed6fd1
bootlin_sha512=96d35eac687bebea5c6c79cd26280b3fab5f2a5bf105b86d70728a0895b12118e839fcceb9ec2b1e6b3ea2ade9cbd069635709a45ccad4a4ed42f647857e0d18
"

ARCH_CONFIG[arm32v7neon]="
musl_name=armv7l-linux-musleabihf
musl_cross=armv7l-linux-musleabihf
glibc_name=arm-buildroot-linux-gnueabihf
bootlin_arch=armv7-eabihf
bootlin_url=armv7-eabihf--glibc--stable-2024.02-1.tar.bz2
cflags=-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard -mthumb -mthumb-interwork
config_arch=arm
musl_sha512=1bb399a61da425faac521df9b8d303e60ad101f6c7827469e0b4bc685ce1f3dedc606ac7b1e8e34d79f762a3bfe3e8ab479a97e97d9f36fbd9fc5dc9d7ed6fd1
bootlin_sha512=96d35eac687bebea5c6c79cd26280b3fab5f2a5bf105b86d70728a0895b12118e839fcceb9ec2b1e6b3ea2ade9cbd069635709a45ccad4a4ed42f647857e0d18
"

ARCH_CONFIG[armeb]="
musl_name=armeb-linux-musleabi
musl_cross=armeb-linux-musleabi
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=armv5te -mbig-endian
config_arch=arm
musl_sha512=6ad112d169cf7a91e3fb119822598d37c071a21323c34de021daca02f36b5c4cd38fae6ecbdc6768d6dcb97f3ccd871403b154bccf0b62d68d3e802980351797
"

ARCH_CONFIG[armebv7hf]="
musl_name=armeb-linux-musleabihf
musl_cross=armeb-linux-musleabihf
glibc_name=armeb-buildroot-linux-gnueabihf
bootlin_arch=armebv7-eabihf
bootlin_url=armebv7-eabihf--glibc--stable-2024.02-1.tar.bz2
cflags=-march=armv7-a -mbig-endian -mfpu=vfpv3 -mfloat-abi=hard
config_arch=arm
musl_sha512=19dd99084f930cce2d3a1b5aa7a411a45c69ecabbcaa282f688b53ffafd5a962900fad80d74846bcc9c2755b0242920da4b689406f4a5ba21359e79d97b12c17
bootlin_sha512=ce95b0befb77403506184e4df1efb4aa3f2ce27b6e4719faa34df472a02400595336f182d8f1b695c017a49d004d839570978047ea02f0f992dbf55312a219d3
"

ARCH_CONFIG[armv6]="
musl_name=armv6-linux-musleabihf
musl_cross=armv6-linux-musleabihf
glibc_name=arm-buildroot-linux-gnueabihf
bootlin_arch=armv6-eabihf
bootlin_url=armv6-eabihf--glibc--stable-2024.02-1.tar.bz2
cflags=-march=armv6 -mfpu=vfp -mfloat-abi=hard -mno-unaligned-access
config_arch=arm
bootlin_sha512=55b8a738aa202efae3906afef870873a678063b3fb77552a331eed6e38147299a720b95f1d7e328e160ebec139a2175c35543c8dc5d68407bea5981fecb1a771
musl_sha512=bcf47e82ec0c0c620c7b47aeb03355fe3f22d9dd9f719a77e2b21322291e04f7a35d1592275f487db4f754f3aede7f51bb0c2f07c1a3b3ce880b3341ec947bea
"

ARCH_CONFIG[armv7m]="
musl_name=armv7m-linux-musleabi
musl_cross=armv7m-linux-musleabi
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=armv7-m -mthumb
config_arch=arm
musl_sha512=2e304ca9c1a5b614c153aebe371de9367540c43b0000b45ec01e4d9a8664b6c5587cc6b3d63545a02e44543372139aef94cc70db236fe00353fdad59d240b023
"

ARCH_CONFIG[armv7r]="
musl_name=armv7r-linux-musleabihf
musl_cross=armv7r-linux-musleabihf
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=armv7-r -mfpu=vfpv3-d16 -mfloat-abi=hard -mthumb
config_arch=arm
musl_sha512=43ed208d9869a81b65eef9b306cb7101957191986e5b60b092d9fd7519f69aa20003c6d1467ee6d80c9860a8d68a7fdbe74fb92d50fb628ce700cf58e2fb672b
"

ARCH_CONFIG[armebhf]="
musl_name=armeb-linux-musleabihf
musl_cross=armeb-linux-musleabihf
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=armv5te -mfpu=vfp -mfloat-abi=hard -mbig-endian
config_arch=arm
musl_sha512=19dd99084f930cce2d3a1b5aa7a411a45c69ecabbcaa282f688b53ffafd5a962900fad80d74846bcc9c2755b0242920da4b689406f4a5ba21359e79d97b12c17
"

ARCH_CONFIG[armel]="
musl_name=armel-linux-musleabi
musl_cross=armel-linux-musleabi
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=armv4t -marm
config_arch=arm
musl_sha512=72d9ca8bca8cb7fb9c7a4ba05b5abd69cd074f76d56bdbf87f0fdab075c62a2babf099db0ad160fa81015778a1f9d9f94a1dfff3b159b7404495e5ee361ec581
"

ARCH_CONFIG[armelhf]="
musl_name=armel-linux-musleabihf
musl_cross=armel-linux-musleabihf
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=armv4t -mfpu=vfp -mfloat-abi=hard -marm
config_arch=arm
musl_sha512=daaba4737e2e584d373c5c5059afc8be3c047d4665af166b5ff49f8260efe5b4c29d4fca27c83d60cd06f7749e1545547f2a993153d689c5ea3852673b27d122
"

ARCH_CONFIG[armv5l]="
musl_name=armv5l-linux-musleabi
musl_cross=armv5l-linux-musleabi
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=armv5te -marm -mno-unaligned-access
config_arch=arm
musl_sha512=2104a0edb08e2e9696ef8cb8c284705e987031904ede6ed49e8303f942b35886aa656c7dbd52f8a3a67abd0a2ce2eb3fa82eb8414f09dda2ae1df300edfb62db
"

ARCH_CONFIG[armv5lhf]="
musl_name=armv5l-linux-musleabihf
musl_cross=armv5l-linux-musleabihf
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=armv5te -mfpu=vfp -mfloat-abi=hard -marm -mno-unaligned-access
config_arch=arm
musl_sha512=a7884e7d1c77bd49676e7f2f05ea0627a67eaec60769b27a387aec952dad105a19d0e15e03c38cd299253e5df87ffebb0ae559817756323b115660ba1e97a985
"

ARCH_CONFIG[armv6sf]="
musl_name=armv6-linux-musleabi
musl_cross=armv6-linux-musleabi
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=armv6 -marm -mno-unaligned-access
config_arch=arm
musl_sha512=db983f159f79cff134ed3050ab170eb35df79623b63dee974b237acf5bb1f8bb7f1a475126e073922c8a2141eb87593a684b3e364c46505489487f670115d99d
"

ARCH_CONFIG[mips32be]="
musl_name=mips-linux-musl
musl_cross=mips
glibc_name=mips-buildroot-linux-gnu
bootlin_arch=mips32
bootlin_url=mips32--glibc--stable-2024.02-1.tar.bz2
cflags=-march=mips32 -mabi=32 -EB
config_arch=mips
bootlin_sha512=baa68ede5046607f0c4a29853332ca64b867fcbbf426a72af2ac5adcf75a001c4de6ceda9c971dac385a9f65b11590f851c880aab7f92c78a63200580e13fc9e
musl_sha512=c1b04aaad4b0d24826d087acf93b5ac28b9f87633fd8554b52625f5b9916073d10b16be3fa2eaa9782e35ad9e850921269cb3b78f49cfbe4d2deed3d1a3291c6
"

ARCH_CONFIG[mips32le]="
musl_name=mipsel-linux-musl
musl_cross=mipsel
glibc_name=mipsel-buildroot-linux-gnu
bootlin_arch=mips32el
musl_sha512=d0275cade2a6162659a610a41e0be4450b893a8f75a4f67a00cfe358c1e9657b86c4e08d002bffe3aca7404a01b42755ebb1ea29b916208c99f5b1fafebaeb60
bootlin_url=mips32el--glibc--stable-2024.02-1.tar.bz2
cflags=-march=mips32 -mabi=32
config_arch=mips
bootlin_sha512=1a73e95735cb80c28291e35aa010f8ba44ec9d3a39585352d249ee9f15467cf70193366c7e283e9614ab1b1aa7e3cab9071708c68268a3423858451ad4eedcc8
"

ARCH_CONFIG[mips32besf]="
musl_name=mips-linux-muslsf
musl_cross=mips-linux-muslsf
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=mips32 -mabi=32 -EB -msoft-float
config_arch=mips
musl_sha512=4b598ca2a9ad157d989eceaff05fbf5bc149474e02a12641b41ff1736c18882b5ddfc7be36d225b16235e60908730db38445920874873b426611c4d5506e957a
"

ARCH_CONFIG[mips32lesf]="
musl_name=mipsel-linux-muslsf
musl_cross=mipsel-linux-muslsf
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=mips32 -mabi=32 -msoft-float
config_arch=mips
musl_sha512=0d42ee6f9d9fe844875d9031bdfe05cf4cb6e80c7d669452295d1b2d5e14e98a0b59aa4b06be4ac0567dfebdf4bf007fbd62ec29d4b7bf677461e132e54345a8
"

ARCH_CONFIG[mips64]="
musl_name=mips64-linux-musl
musl_cross=mips64
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=mips64 -mabi=64
config_arch=mips64
musl_sha512=8ceead53f611b3672c98b4431fd78ec8e25b6e9841f103274d7b2305026e392c61f924ed24afe7a569727099da49cb77e2d1d68353cc0dd165e5d1547b3565d2
"

ARCH_CONFIG[mips64le]="
musl_name=mips64el-linux-musl
musl_cross=mips64el
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-march=mips64 -mabi=64
config_arch=mips64
musl_sha512=c19f23d947aaf304953a5fa3f677c8ab596e7d3c6fcd212f42e731211bfe757b28b055b2b761c84d932c54eeaba7000ab3c37be23682fb1b291291e30a99b9f8
"

ARCH_CONFIG[mips64n32]="
musl_name=mips64-linux-musln32
musl_cross=mips64-linux-musln32
glibc_name=mips64-buildroot-linux-gnu
bootlin_arch=mips64-n32
bootlin_url=mips64-n32--glibc--stable-2024.02-1.tar.bz2
cflags=-march=mips64 -mabi=n32
config_arch=mips64
bootlin_sha512=a79b83c6741d12e199733d37a79b0de042bbf9725a31316222f4591bd558e5b1714b89dfda707bae6a43ba9053f844e7425b697485c1527d420856c22a3eea38
musl_sha512=22383a40902b6830e4202316faa2d18ed07c0b59b95e5cf703477e9535f2f9b703dc9e13624968740b11268160f23d59b82020cb49031be42a9e7667ae9c5064
"

ARCH_CONFIG[mips64n32el]="
musl_name=mips64el-linux-musln32
musl_cross=mips64el-linux-musln32
glibc_name=mips64el-buildroot-linux-gnu
bootlin_arch=mips64el-n32
bootlin_url=mips64el-n32--glibc--stable-2024.02-1.tar.bz2
cflags=-march=mips64 -mabi=n32
config_arch=mips64
bootlin_sha512=f0fab26a5e672470501150311d66a5a8b8f0f9e350f03a18ad857e08183bd578c71bd245405ddf927be6bf4c3293e2679f8326adc4ca2caa8c1a4018de82b4e6
musl_sha512=8a3fcd26e41dd9701ded101bbdbd2fd5a8656348d7025c14f778e2bcca3b44a83cb82bcadb1bbc33d9d8e4a788180df9bbd258945f50b58a353c67397d04bdbc
"


ARCH_CONFIG[ppc32be]="
musl_name=powerpc-linux-musl
musl_cross=powerpc
glibc_name=powerpc-buildroot-linux-gnu
bootlin_arch=powerpc-e500mc
bootlin_url=powerpc-e500mc--glibc--stable-2024.02-1.tar.bz2
cflags=-mcpu=powerpc -m32 -mno-altivec -mno-vsx
config_arch=powerpc
bootlin_sha512=ed79f841689af76cc35d9a041d8f5ed63573921b5b87e454f98d5375bf24a88157f690036c792e49a42b9617eceb38c4b57dc9d28964ec2dc6780c031a324954
musl_sha512=0653252f8406b1f4d6f6a189651855413b5be6112b54606a0f663296059e1d595310f1c25f767c8d44202b7dd04bb4736a60fbd4e533368177401cef0d01dcfe
"

ARCH_CONFIG[ppc32besf]="
musl_name=powerpc-linux-muslsf
musl_cross=powerpc-linux-muslsf
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-mcpu=powerpc -m32 -msoft-float
config_arch=powerpc
musl_sha512=f31630114c8933482f097b091fe0b5a346a45005db23581397b37c23c694bdea47dbc777daeebdfcee6f7dbeac0e400fa3583751fe3fd3d55bdb853aa9496abe
"

ARCH_CONFIG[ppc32le]="
musl_name=powerpcle-linux-musl
musl_cross=powerpcle
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-mcpu=powerpc -m32 -mlittle-endian
config_arch=powerpc
musl_sha512=4293b7e411be80e2ecea4f6faa8bdc79b717b989429f38270f351763c0829551ffa1b920b3a6ba88d3ab583afdec3c760f3716672c75aca66ad0d8b069f1643b
"

ARCH_CONFIG[ppc32lesf]="
musl_name=powerpcle-linux-muslsf
musl_cross=powerpcle-linux-muslsf
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-mcpu=powerpc -m32 -mlittle-endian -msoft-float
config_arch=powerpc
musl_sha512=20e12f2ce02ed65013f83f2cf4b213fa228c7273ab45a8d552bdc6dad416201bd8be02cd8fa6a39fe48d78ca1a63613e7e915d4595098bd84ed8c84b14309245
"

ARCH_CONFIG[ppc64be]="
musl_name=powerpc64-linux-musl
musl_cross=powerpc64
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-mcpu=power4 -m64
config_arch=powerpc64
musl_sha512=3975cc64530dab6738eb3aacc37f34f8a0d782bf0a1ef1e21da4710c90bb9478afc929b8092bf2df61e92f0994df3eaf15ffaab1c53d3ac296e39dcf6e9c31a8
"

ARCH_CONFIG[ppc64le]="
musl_name=powerpc64le-linux-musl
musl_cross=powerpc64le
glibc_name=powerpc64le-buildroot-linux-gnu
bootlin_arch=powerpc64le-power8
bootlin_url=powerpc64le-power8--glibc--stable-2024.02-1.tar.bz2
cflags=-mcpu=powerpc64le -m64 -mlittle-endian
config_arch=powerpc64
bootlin_sha512=346f04c665f85b5e4a1dec58e8385a6786682a320a3c031cb809dfba980259fda956a63134f98516e7b109df2ee8e9fd18925cfbaa0c389adf54e262150047c7
musl_sha512=68f72b4ff0d0f28094581a4dbd81090f28898c74f5a97cd39d725e2e332aa099eebe71ccab5d7db1646ec443ed6165997eeea42510b918ea7626720e4e78b19c
"

ARCH_CONFIG[riscv32]="
musl_name=riscv32-linux-musl
musl_cross=riscv32
glibc_name=riscv32-buildroot-linux-gnu
bootlin_arch=riscv32-ilp32d
bootlin_url=riscv32-ilp32d--glibc--stable-2024.05-1.tar.xz
cflags=-march=rv32gc -mabi=ilp32d
config_arch=riscv
bootlin_sha512=5ab3d3533bef4b715138c982e50732db27fea96a5dd28c1a8b2cb3b89462a863010c1d22376600d4144f96f67252237ae690426a40612b39b67a6f4ae17978f4
musl_sha512=28c85aa4f08419816b93f3775a0339e21f8e6c2c55efca416ed350df1a9f22469ee965c8f8a9ac186aa36411977c375afae39f7224d386b7c032b513833ff90d
"

ARCH_CONFIG[riscv64]="
musl_name=riscv64-linux-musl
musl_cross=riscv64
glibc_name=riscv64-buildroot-linux-gnu
bootlin_arch=riscv64-lp64d
musl_sha512=9fdb9f6077db2e7091fab5fccec875d7f73e901fa8be27a2eae6b40ac6ba35ca789fecec752363ab5aa8c3d93a5b855cd52813a54b0dc4e2644b9296e76c07a8
bootlin_url=riscv64-lp64d--glibc--stable-2024.02-1.tar.bz2
cflags=-march=rv64gc -mabi=lp64d
config_arch=riscv64
bootlin_sha512=a43986358d77aeddf8e51213b7a99edc651767f30e80eeb934502416074adb538189fa0342da6b2ea5f48875855ee9028d061005ceb5cdd464365070649cb88c
"


ARCH_CONFIG[m68k]="
musl_name=m68k-linux-musl
musl_cross=m68k
glibc_name=m68k-buildroot-linux-gnu
bootlin_arch=m68k
bootlin_url=m68k-68xxx--glibc--stable-2024.02-1.tar.bz2
cflags=-mcpu=68020
config_arch=m68k
bootlin_sha512=2bf9cf1e286b2c567d6524917386180eff81ea4de257492b1c2aa2fa3d500f71ca18df751fda3473db6c6a79819e6aacd593647feb42a6f0533a4a5dd7672e02
musl_sha512=efaa25090bee6832009c9e0e0bb9812fe2b976cb3ba4f0d59dd290695a95d53291068fac3df4b65e75c0a4e05bc084ba57b6edb8e4236d7a1a46cb9789fb5c2b
"

ARCH_CONFIG[microblaze]="
musl_name=microblaze-linux-musl
musl_cross=microblaze
glibc_name=microblaze-buildroot-linux-gnu
bootlin_arch=microblazebe
bootlin_url=microblazebe--glibc--stable-2024.02-1.tar.bz2
cflags=-mcpu=v9.0
config_arch=microblaze
bootlin_sha512=b9c9f11674e92865ce8d11dac034e1762cbd539172c5aebfe41df37a9da1b2aa2e0d2343b6f3ffc5a358c0f16a1e4420ef0d396a469570d7b5bcf676e7e2ea60
musl_sha512=675492aaf25821f68df73298ae93bc133f376b38a1ebba250b8679fb09dc9d2cd516e1741b4aebdd35aa3d5878ec1dc9636bcc86bb9bbffeda36dc5d654257ef
"

ARCH_CONFIG[microblazeel]="
musl_name=microblazeel-linux-musl
musl_cross=microblazeel
glibc_name=microblazeel-buildroot-linux-gnu
bootlin_arch=microblazeel
bootlin_url=microblazeel--glibc--stable-2024.02-1.tar.bz2
cflags=-mcpu=v9.0 -mlittle-endian
config_arch=microblaze
bootlin_sha512=32c484585a6478283fc22c5c5b6d2efe620ec4d28745750b6e2f0f444ee384ec69a7f1834b96f76db17fea7178bda2d501c62230a37724dfdf07475c18c8ef4a
musl_sha512=614ce3f83add0afed4a6516cf1dc4927f6933ad728471fade9c500493525914e717896c1ce08f6a17ccf5e37fe0fe66167b1c8d50fb10458387f561cef892dd7
"

ARCH_CONFIG[or1k]="
musl_name=or1k-linux-musl
musl_cross=or1k
glibc_name=or1k-buildroot-linux-gnu
bootlin_arch=openrisc
bootlin_url=openrisc--glibc--stable-2024.02-1.tar.bz2
cflags=
config_arch=openrisc
bootlin_sha512=91592acd360d9e2a7c7fa751118497ca1a886d69ed9ff518a63b4968ad8cfb1435608087ea2db4ccb6c66bc317e095af65216865dac8bf123997a05802e219b6
musl_sha512=f5ac9a7f43c42d4860d3736ff612f1ffee9f647fcda07dfeabc5e9061866d7fa8c362aa9e6b292e5f2579cbb88a4530afca210455caece3455423c37a5c5d58b
"

ARCH_CONFIG[s390x]="
musl_name=s390x-linux-musl
musl_cross=s390x
glibc_name=s390x-buildroot-linux-gnu
bootlin_arch=s390x-z13
bootlin_url=s390x-z13--glibc--stable-2024.02-1.tar.bz2
cflags=
config_arch=s390x
bootlin_sha512=fa638b803147c6d1258e0d9b9d146a27457188764248a8f468a1c47c4fb0ee4324f5633b55949da39761f7a283999af1abba96617e59c9383d12e275b80d1cae
musl_sha512=8d74962f19faa05ffcbd2ba4717dd554ef782ea72f4f058d6e71b772e4c3adbd80111d86c2c3b4b694c88a177c18b46602a1d7b9b31fd7bf2a696275b15dd980
"

ARCH_CONFIG[sh2]="
musl_name=sh2-linux-musl
musl_cross=sh2
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-m2
config_arch=sh
musl_sha512=5a72ff2100aade9d9fcfaf2cb10d54927e0e957e26a672d39c4fc0f0689d21f381343e6858b8fc5ba885318b02e16db45eeb0074c60e1094ed21e6276c84b14c
"

ARCH_CONFIG[sh2eb]="
musl_name=sh2eb-linux-musl
musl_cross=sh2eb
glibc_name=
bootlin_arch=
bootlin_url=
cflags=-m2 -mb
config_arch=sh
musl_sha512=5b731ad87bb46dce9d6049e518533397d82174033b2bad62c6435cd3f15747a207d7b1ae2a40cb41761466d7caf33360f1aeaddccf6522064b6d2889d10d4763
"

ARCH_CONFIG[sh4]="
musl_name=sh4-linux-musl
musl_cross=sh4
glibc_name=sh4-buildroot-linux-gnu
bootlin_arch=sh-sh4
bootlin_url=sh-sh4--glibc--stable-2024.02-1.tar.bz2
cflags=-m4
config_arch=sh
bootlin_sha512=1a5216ac29c25989001fb03033fe9ade8c0eb0d749d49994f44c543225436a98f07a7a501320522cdb091d89fd6d79c72adfd8cafbaff36401c8611bbeadec1e
musl_sha512=34e660badc0609c0706b2dbf4e6c6398f4002958afdeae46dbd7665824f2eb7804ad8c1dd67b8fae382be6c7d3f5c75c0716b590658ea611bf0a4fa0935cbdbf
"

ARCH_CONFIG[sh4eb]="
musl_name=sh4eb-linux-musl
musl_cross=sh4eb
glibc_name=sh4aeb-buildroot-linux-gnu
bootlin_arch=sh-sh4aeb
bootlin_url=sh-sh4aeb--glibc--stable-2024.02-1.tar.bz2
cflags=-mb
config_arch=sh
bootlin_sha512=b03637bc4935d059916588dab7799017c5b7ef3a75d3cefe3571591cfcf90349a01d9a1670dc344905e18fd1bd57ae4eb4511ff381f27875e27cfa73e95071e2
musl_sha512=8182f3d48056d17e4120fc1d235e6a97ac0c3c51d6c7a811d12cf9298d48be8466b13150ada2655ee4fb0f3249ee6702d619050edaf0169a6977b407652cf60e
"

ARCH_CONFIG[sparc64]="
musl_name=
musl_cross=
glibc_name=sparc64-buildroot-linux-gnu
bootlin_arch=sparc64
bootlin_url=sparc64--glibc--stable-2024.02-1.tar.bz2
cflags=-mcpu=v9 -m64
config_arch=sparc64
bootlin_sha512=be4f9487e656f03dbf7e5daf9108878a13a1f2d5738df343cf3ecb3dbdbcc3bf63ed5f7aa31f26ccbad67415fb0b8ca7896ed5d84b64082d948613fc0ae15302
"

ARCH_CONFIG[nios2]="
musl_name=
musl_cross=
glibc_name=nios2-buildroot-linux-gnu
bootlin_arch=nios2
bootlin_url=nios2--glibc--stable-2024.02-1.tar.bz2
cflags=-march=r1
config_arch=nios2
bootlin_sha512=23f69ddc48a279ec63acd3647c5dfab614609ec76d11b6ff8058ade36d9c2b5e47781d69d4cf21e9fb114224f32e251c3aab57b2446b53c6a2203e2bce745c92
"

ARCH_CONFIG[m68k_coldfire]="
musl_name=
musl_cross=
glibc_name=m68k-buildroot-linux-gnu
bootlin_arch=m68k-coldfire
bootlin_url=m68k-coldfire--glibc--stable-2024.02-1.tar.bz2
cflags=-mcpu=5208 -fPIC -mxgot
config_arch=m68k
bootlin_sha512=b6fdec9e608f1459d3bc53250cc1570b76757c972df1a5526265cf232d4d12aa272dba1ceefb6dc723ca38108e4f6ae268df4def02f863a74579b24a1e86d945
"

ARCH_CONFIG[arcle_hs38]="
musl_name=
musl_cross=
glibc_name=arc-buildroot-linux-gnu
bootlin_arch=arcle-hs38
bootlin_url=arcle-hs38--glibc--stable-2024.02-1.tar.bz2
cflags=-mcpu=hs38 -matomic
config_arch=arc
bootlin_sha512=6cc9bf8d47355a4034a7a4d377b38cc12d8f023a46820490f116ace0babe7e9414576d85694988b869eb7622ab0fa302a3e82e3c1b7c45f71baab1757c115472
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
custom_musl_sha512=f62c0730cf0275bf99e75a228424586bde62dac93fbfb8012f8b6e49b5f93edd65cc1ee4a9ff1a460ce6f2470a32f605d28eb0b12f761a60a4ad4b8daff81065
custom_glibc_sha512=f8e26d6b5642926870f46ea610c930fa1e57e0b7064403bdd4bf2b726b89e0d575528642938d6e0073fe3a9a6422a7d01ca1e123a90850d75f8c127b10fd95fd
"

get_arch_field() {
    local arch="$1"
    local field="$2"
    local config="${ARCH_CONFIG[$arch]:-}"
    
    if [ -z "$config" ]; then
        return 1
    fi
    
    local value=$(echo "$config" | grep "^${field}=" | cut -d'=' -f2- | head -1)
    if [ -n "$value" ]; then
        echo "$value"
        return 0
    fi
    return 1
}

get_musl_toolchain() { get_arch_field "$1" "musl_name"; }
get_glibc_toolchain() { get_arch_field "$1" "glibc_name"; }
get_bootlin_url() { get_arch_field "$1" "bootlin_url"; }
get_musl_sha512() { get_arch_field "$1" "musl_sha512"; }
get_bootlin_sha512() { get_arch_field "$1" "bootlin_sha512"; }
get_custom_musl_url() { get_arch_field "$1" "custom_musl_url"; }
get_custom_musl_sha512() { get_arch_field "$1" "custom_musl_sha512"; }
get_custom_glibc_url() { get_arch_field "$1" "custom_glibc_url"; }
get_custom_glibc_sha512() { get_arch_field "$1" "custom_glibc_sha512"; }

arch_supports_glibc() {
    local arch="$1"
    local glibc_name=$(get_arch_field "$arch" "glibc_name" 2>/dev/null)
    local bootlin_url=$(get_arch_field "$arch" "bootlin_url" 2>/dev/null)
    local custom_glibc=$(get_arch_field "$arch" "custom_glibc_url" 2>/dev/null)
    
    [ -n "$glibc_name" ] || [ -n "$bootlin_url" ] || [ -n "$custom_glibc" ]
}

arch_supports_musl() {
    local arch="$1"
    local musl_name=$(get_arch_field "$arch" "musl_name" 2>/dev/null)
    local custom_musl=$(get_arch_field "$arch" "custom_musl_url" 2>/dev/null)
    
    [ -n "$musl_name" ] || [ -n "$custom_musl" ]
}

export ALL_ARCHITECTURES
export ARCH_CONFIG
