FROM debian:stable-slim

# Default ENV
ENV \
    LANG="C.UTF-8" \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
    S6_CMD_WAIT_FOR_SERVICES=1 \
    S6_SERVICES_READYTIME=50

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Build Args
ARG VCONTROLD_VERSION \
    S6_OVERLAY_VERSION

# Base system
WORKDIR /usr/src
ARG BUILD_ARCH

RUN apt-get update && \
    apt-get upgrade -y
RUN apt-get install -y build-essential bash tzdata curl ca-certificates xz-utils joe vim subversion automake autoconf telnet libxml2-dev mosquitto-clients git cmake jq iputils-ping 

RUN set -x && \
    mkdir -p /usr/share/man/man1 && \
    \
    if [ "${BUILD_ARCH}" = "armv7" ]; then \
        export S6_ARCH="arm"; \
    elif [ "${BUILD_ARCH}" = "i386" ]; then \
        export S6_ARCH="i686"; \
    elif [ "${BUILD_ARCH}" = "amd64" ]; then \
        export S6_ARCH="x86_64"; \
    else \
        export S6_ARCH="${BUILD_ARCH}"; \
    fi &&\
    \
    curl -L -f -s "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz" \
     | tar Jxvf - -C / && \
    curl -L -f -s "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
     | tar Jxvf - -C / && \
    curl -L -f -s "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz" \
     | tar Jxvf - -C / && \
    curl -L -f -s "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz" \
     | tar Jxvf - -C / && \
    mkdir -p /etc/fix-attrs.d && \
    mkdir -p /etc/services.d

# S6-Overlay
WORKDIR /
ENTRYPOINT ["/init"]

# vcontrold
RUN mkdir openv && cd openv && git clone --branch $VCONTROLD_VERSION https://github.com/openv/vcontrold.git vcontrold-code
RUN cd /openv && cmake ./vcontrold-code -DVSIM=ON -DMANPAGES=OFF && \
    make && \
    make install

# Cleanup
RUN apt-get purge -y --auto-remove build-essential git cmake && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/src/* /openv

# Setup config dir
RUN mkdir /config

# Copy root filesystem
COPY rootfs /

EXPOSE 3002/tcp
