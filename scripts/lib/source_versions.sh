#!/bin/bash
# Shared source version, URL, and SHA512 definitions.
# Sourced by individual tool build scripts to avoid duplicating constants
# across scripts that build from the same upstream tarball.

# --- Nmap (used by build-nmap.sh, build-ncat.sh, build-ncat-ssl.sh) ---
NMAP_VERSION="${NMAP_VERSION:-7.98}"
NMAP_URL="https://nmap.org/dist/nmap-${NMAP_VERSION}.tar.bz2"
NMAP_SHA512="14e13689d1276f70efc8c905e8eb0a15970f4312c2ef86d8d97e9df11319735e7f7cd73f728f69cf43d27a078ef5ac1e0f39cd119d8cb9262060c42606c6cab3"

# --- Curl (used by build-curl.sh, build-curl-full.sh) ---
CURL_VERSION="${CURL_VERSION:-8.16.0}"
CURL_URL="https://curl.se/download/curl-${CURL_VERSION}.tar.xz"
CURL_SHA512="8262c3dc113cfd5744ef1b82dbccaa69448a9395ad5c094c22df5cf537a047a927d3332db2cb3be12a31a68a60d8d0fa8485b916e975eda36a4ebd860da4f621"

# --- oida-fuzzing-agent (used by build-oida-fuzzing-agent.sh) ---
OIDA_FUZZING_AGENT_VERSION="${OIDA_FUZZING_AGENT_VERSION:-0.1.0}"
OIDA_FUZZING_AGENT_URL="https://github.com/f0rw4rd/oida-fuzzing-agent/releases/download/v${OIDA_FUZZING_AGENT_VERSION}/oida-fuzzing-agent-${OIDA_FUZZING_AGENT_VERSION}-src.tar.gz"
OIDA_FUZZING_AGENT_SHA512="bf28f1ed29088728785e8b1296f2017868010a0cf52a73353db996caae726ac665626c85faac1d3d1fe4c2c8097709de073ae7f8c57cde9f4ca132309814bc91"
