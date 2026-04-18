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

# Install Zig 0.15.1
RUN cd /tmp && \
    wget https://ziglang.org/download/0.15.1/zig-x86_64-linux-0.15.1.tar.xz && \
    echo "b48538e3196638faee0756f03db195d5460ff2ea2c05c42c9cf836a90907e324083d3e4d1d4c25197c8f4fed11ebca10a7c56f19f2e108abfb411c7a0b5582ea  zig-x86_64-linux-0.15.1.tar.xz" | sha512sum -c - && \
    tar xf zig-x86_64-linux-0.15.1.tar.xz && \
    mv zig-x86_64-linux-0.15.1 /opt/zig && \
    ln -s /opt/zig/zig /usr/local/bin/zig && \
    rm zig-x86_64-linux-0.15.1.tar.xz

RUN mkdir -p /build/sources /build/toolchains-musl /build/toolchains-glibc /build/deps-cache && \
    mkdir -p /build/output /build/logs && \
    mkdir -p /build/scripts

RUN useradd -m -s /bin/bash builder && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

RUN chown -R builder:builder /build

USER builder
WORKDIR /build

COPY --chown=builder:builder scripts/ /build/scripts/

CMD ["/bin/bash"]