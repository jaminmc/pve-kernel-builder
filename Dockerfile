#
# This Dockerfile builds the newest kernel with the Patches for Proxmox VE
#
ARG DEBIAN_RELEASE=bookworm
FROM debian:${DEBIAN_RELEASE}-slim

ARG DEBIAN_RELEASE
ARG REPO_URL=git://git.proxmox.com/git/pve-kernel.git
ARG REPO_BRANCH=master

ENV DEBIAN_FRONTEND=noninteractive

# Set up Proxmox repository, upgrade system, and install dependencies
RUN set -x \
  && apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates wget \
  && wget -qO /etc/apt/trusted.gpg.d/proxmox-release-${DEBIAN_RELEASE}.gpg \
       http://download.proxmox.com/debian/proxmox-release-${DEBIAN_RELEASE}.gpg \
       https://enterprise.proxmox.com/debian/proxmox-release-${DEBIAN_RELEASE}.gpg || true \
  && chmod +r /etc/apt/trusted.gpg.d/proxmox-release-${DEBIAN_RELEASE}.gpg \
  && echo "deb http://download.proxmox.com/debian/pve ${DEBIAN_RELEASE} pve-no-subscription" \
       > /etc/apt/sources.list.d/pve-no-subscription.list \
  && apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y --no-install-recommends \
       apt-utils \
       asciidoc \
       asciidoc-base \
       automake \
       bc \
       bison \
       build-essential \
       cpio \
       debhelper \
       devscripts \
       dh-python \
       dwarves \
       fakeroot \
       file \
       flex \
       gcc \
       git \
       gawk \
       gnupg \
       gnupg2 \
       idn \
       kmod \
       libaudit-dev \
       libbabeltrace-dev \
       libcap-dev \
       libdw-dev \
       libelf-dev \
       libgtk2.0-dev \
       libiberty-dev \
       libnuma-dev \
       libperl-dev \
       libpve-common-perl \
       libslang2-dev \
       libssl-dev \
       libtraceevent-dev \
       libtool \
       libunwind-dev \
       libzstd-dev \
       lintian \
       nano \
       patch \
       perl-modules \
       pve-doc-generator \
       python3-dev \
       python3-minimal \
       rsync \
       screen \
       sed \
       sphinx-common \
       systemtap-sdt-dev \
       tar \
       xmlto \
       zlib1g-dev \
       zstd \
       $(if [ "$DEBIAN_RELEASE" = "bookworm" ] || [ "$DEBIAN_RELEASE" = "trixie" ]; then \
           echo "libncurses-dev lz4"; \
         else \
           echo "liblz4-tool libncurses5 libncurses5-dev"; \
         fi) \
  && apt-get autoremove --purge \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Create build user and set up working directory
RUN useradd -m -d /build builder
USER builder
WORKDIR /build
COPY patches patches
COPY scripts scripts

# Clone pve kernel repo and apply patches
RUN set -x \
  && git clone ${REPO_URL} -b ${REPO_BRANCH} pve-kernel \
  && cd pve-kernel \
  && ../scripts/copy-patches.sh ../patches/kernel/*.patch patches/kernel \
  && ../scripts/copy-patches.sh ../patches/kernel/${REPO_BRANCH}/*.patch patches/kernel \
  && mkdir -p build-patches \
  && ../scripts/copy-patches.sh ../patches/build/*.patch build-patches \
  && ../scripts/copy-patches.sh ../patches/build/${REPO_BRANCH}/*.patch build-patches \
  && for patch in build-patches/*.patch; do \
       [ -f "$patch" ] && { echo "Applying build patch '$patch'"; patch -p1 < "$patch"; }; \
     done