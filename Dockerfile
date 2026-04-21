FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    gcc g++ make cmake automake autoconf libtool \
    pkg-config \
    git wget curl \
    tar gzip bzip2 xz-utils \
    patch \
    python3 python3-pip \
    bison flex \
    texinfo \
    gawk \
    bc \
    libncurses5-dev \
    libssl-dev \
    zlib1g-dev \
    libexpat1-dev \
    libffi-dev \
    libgmp-dev libmpc-dev libmpfr-dev \
    bash \
    coreutils \
    linux-libc-dev \
    libreadline-dev \
    libpcap-dev \
    parallel \
    file \
    rsync \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install Zig 0.16.0
RUN cd /tmp && \
    wget https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz && \
    echo "7883953b20974c487318a134d826bf87e76e9c80f9be1aebf63a0cf362c7e03291842ed3acff61b1892efa85dc72ef37bd60da301f266675c47623e4808a4895  zig-x86_64-linux-0.16.0.tar.xz" | sha512sum -c - && \
    tar xf zig-x86_64-linux-0.16.0.tar.xz && \
    mv zig-x86_64-linux-0.16.0 /opt/zig && \
    ln -s /opt/zig/zig /usr/local/bin/zig && \
    rm zig-x86_64-linux-0.16.0.tar.xz

RUN mkdir -p /build/sources /build/toolchains-musl /build/toolchains-glibc /build/toolchains-uclibc /build/deps-cache && \
    mkdir -p /build/output /build/logs && \
    mkdir -p /build/scripts

RUN useradd -m -s /bin/bash builder && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

RUN chown -R builder:builder /build

USER builder
WORKDIR /build

COPY --chown=builder:builder scripts/ /build/scripts/

CMD ["/bin/bash"]