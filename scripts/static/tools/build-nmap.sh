#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" 2>/dev/null && pwd)" || LIB_DIR="/build/scripts/lib"
source "$LIB_DIR/common.sh"
source "$LIB_DIR/dependency_builder.sh"
source "$LIB_DIR/core/compile_flags.sh"
source "$LIB_DIR/build_helpers.sh"
source "$LIB_DIR/source_versions.sh"

SUPPORTED_OS="linux,android"  # nmap pulls Linux-only sources (ndisc-linux.c, asm/types.h); BSD needs source patches + -ldl removal

# Embed nmap's flat data files (nmap-services, nmap-service-probes, nmap-os-db,
# etc.) into the binary and serve them from memory via fmemopen, so a standalone
# static nmap does -sV/-O/UDP-payloads/service-lookups with no data files on
# disk. Set NMAP_EMBED_DATA=0 to build a plain (dataless) nmap. NSE scripts are
# NOT embedded — they need a real filesystem.
NMAP_EMBED_DATA="${NMAP_EMBED_DATA:-1}"

# Compile nmap's data files into the source tree. Run from the nmap-<ver> dir
# after ./configure (needs the generated Makefile). Idempotent per build dir.
embed_nmap_data() {
    # Note: common.sh exports its own SCRIPT_DIR (the lib dir), so use the
    # exported STATIC_SCRIPT_DIR to locate this tool's assets reliably.
    local asset_dir="$STATIC_SCRIPT_DIR/tools/nmap-embed"

    if ! command -v python3 >/dev/null 2>&1; then
        log_tool_error "nmap" "python3 required for NMAP_EMBED_DATA but not found"
        return 1
    fi

    cp "$asset_dir/nmap_embedded.h" "$asset_dir/nmap_embedded.cc" . || return 1
    python3 "$asset_dir/gen_embedded_data.py" . nmap_embedded_data.h || {
        log_tool_error "nmap" "failed to generate embedded data header"
        return 1
    }

    # Pull in the helper declaration wherever we call it. Anchor on NmapOps.h:
    # it is included unconditionally in all six files, unlike the first #include
    # (which is winfix.h inside #ifdef WIN32 in nmap.cc — inserting there gets
    # compiled out on Linux).
    local f
    for f in nmap.cc services.cc protocols.cc MACLookup.cc osscan.cc service_scan.cc; do
        grep -q '"nmap_embedded.h"' "$f" && continue
        perl -0pi -e 's/(\n#include "NmapOps.h"\n)/$1#include "nmap_embedded.h"\n/' "$f" || return 1
        grep -q '#include "nmap_embedded.h"' "$f" || {
            log_tool_error "nmap" "could not insert embedded header into $f"
            return 1
        }
    done

    # Route the five data-file opens through the in-memory-aware helper.
    perl -pi -e 's/\bfopen\(filename, "r"\)/nmap_data_fopen(filename)/' services.cc protocols.cc MACLookup.cc service_scan.cc || return 1
    perl -pi -e 's/\bfopen\(fname, "r"\)/nmap_data_fopen(fname)/' osscan.cc || return 1

    # Make nmap_fetchfile fall back to a sentinel path for embedded files when
    # the on-disk lookup fails (disk/--datadir/$NMAPDIR still win, checked first).
    perl -0pi -e 's/(\n  res = nmap_fetchfile_sub\(filename_returned, bufferlen, file\);\n)\n(  return res;\n)/$1\n  if (res != 1 \&\& nmap_embedded_available(file)) {\n    Snprintf(filename_returned, bufferlen, "%s%s", NMAP_EMBEDDED_PREFIX, file);\n    return 1;\n  }\n\n$2/' nmap.cc || return 1

    # -sV normally also forces NSE "version" scripts (needs nse_main.lua). Since
    # NSE is not embedded, only enable that when nse_main.lua actually exists on
    # disk; otherwise -sV runs on the embedded service-probe engine alone instead
    # of QUITTING with "could not locate nse_main.lua".
    perl -0pi -e 's/  if \(o\.servicescan\)\n    o\.scriptversion = true;\n/  if (o.servicescan) {\n    char nse_main_path[256];\n    if (nmap_fetchfile(nse_main_path, sizeof(nse_main_path), "nse_main.lua") == 1)\n      o.scriptversion = true;\n  }\n/' nmap.cc || return 1

    # Verify each edit actually landed (perl -pi is silent on a missed pattern).
    grep -q "nmap_data_fopen(filename)" services.cc && \
    grep -q "nmap_data_fopen(fname)" osscan.cc && \
    grep -q "nmap_embedded_available(file)" nmap.cc && \
    grep -q 'nmap_fetchfile(nse_main_path' nmap.cc || {
        log_tool_error "nmap" "embed patch failed to apply cleanly (nmap $NMAP_VERSION layout changed?)"
        return 1
    }

    # Add our object to the link (OBJS assignment line only).
    sed -i '/^OBJS = /s/\$(NSE_OBJS)/$(NSE_OBJS) nmap_embedded.o/' Makefile || return 1

    log_tool "nmap" "Embedded flat data files (in-memory, no NSE)"
    return 0
}

build_nmap() {
    local arch=$1
    local build_dir=$(create_build_dir "nmap" "$arch")
    local TOOL_NAME="nmap"

    if ! check_tool_support "$SUPPORTED_OS" "$TOOL_NAME"; then
        return 1
    fi

    if check_binary_exists "$arch" "nmap"; then
        return 0
    fi
    
    setup_toolchain_for_arch "$arch" || return 1
    
    local ssl_dir
    ssl_dir=$(build_openssl_cached "$arch") || {
        log_tool_error "nmap" "Failed to build/get OpenSSL for $arch"
        return 1
    }

    local pcap_dir
    pcap_dir=$(build_libpcap_cached "$arch") || {
        log_tool_error "nmap" "Failed to build/get libpcap for $arch"
        return 1
    }

    local zlib_dir
    zlib_dir=$(build_zlib_cached "$arch") || {
        log_tool_error "nmap" "Failed to build/get zlib for $arch"
        return 1
    }
    
    cd "$build_dir"
    
    if ! download_and_extract "$NMAP_URL" "$build_dir" 0 "$NMAP_SHA512"; then
        log_tool_error "nmap" "Failed to download and extract source"
        return 1
    fi
    
    cd "$build_dir/nmap-${NMAP_VERSION}"

    update_config_scripts

    local cflags=$(get_compile_flags "$arch" "static" "$TOOL_NAME")
    local cxxflags=$(get_cxx_flags "$arch" "static" "$TOOL_NAME")
    local ldflags=$(get_link_flags "$arch" "static")
    
    cflags="$cflags -I$pcap_dir/include -I$ssl_dir/include -I$zlib_dir/include"
    cxxflags="$cxxflags -I$pcap_dir/include -I$ssl_dir/include -I$zlib_dir/include"
    ldflags="$ldflags -L$pcap_dir/lib -L$ssl_dir/lib -L$zlib_dir/lib"
    
    export CC="$CC"
    export CXX="$CXX"
    export CFLAGS="$cflags"
    export CXXFLAGS="$cxxflags"
    export LDFLAGS="$ldflags"
    export LIBS="-lpcap -lssl -lcrypto -lz -lm -ldl"
    
    mkdir -p libpcre/sub
    
    export ac_cv_func_strerror=yes
    export ac_cv_prog_cc_g=yes
    
    touch libpcre/aclocal.m4 libpcre/Makefile.in libpcre/configure
    find libpcre -name "*.in" -exec touch {} \;
    
    ./configure \
        --host=$HOST \
        --without-ndiff \
        --without-zenmap \
        --without-nmap-update \
        --without-ncat \
        --without-nping \
        --with-libpcap="$pcap_dir" \
        --with-openssl="$ssl_dir" \
        --with-libz="$zlib_dir" || {
        log_tool_error "nmap" "Configure failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    if [ -f libpcre/Makefile ]; then
        sed -i 's/^Makefile:.*/Makefile:/' libpcre/Makefile
        sed -i 's/^config.status:.*/config.status:/' libpcre/Makefile
    fi

    if [ "$NMAP_EMBED_DATA" = "1" ]; then
        embed_nmap_data || {
            log_tool_error "nmap" "Failed to embed data files for $arch"
            cleanup_build_dir "$build_dir"
            return 1
        }
    fi

    make V=1 -j$(nproc) || {
        log_tool_error "nmap" "Build failed for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    }
    
    if [ -f "nmap" ]; then
        $STRIP nmap
        local output_path=$(get_output_path "$arch" "nmap")
    mkdir -p "$(dirname "$output_path")"
    cp nmap "$output_path"
        local size=$(get_binary_size "$output_path")
        log_tool "nmap" "Built successfully for $arch ($size)"
        cleanup_build_dir "$build_dir"
        return 0
    else
        log_tool_error "nmap" "Failed to build nmap for $arch"
        cleanup_build_dir "$build_dir"
        return 1
    fi
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <architecture>"
    exit 1
fi

arch=$1
build_nmap "$arch"
