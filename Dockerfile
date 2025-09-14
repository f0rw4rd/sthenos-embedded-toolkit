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