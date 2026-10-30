# Cross-compilation environment: Swift 6.3.1 host toolchain (Linux) + community
# armv7 / Ubuntu 22.04 (glibc 2.35) SDK from swift-embedded-linux/armhf-debian.
#
# The SDK requires the *exact* same host toolchain version (6.3.1), installed at
# /usr/bin, and the SDK itself at /opt -- both are satisfied here.
FROM swift:6.3.1-jammy

ARG SDK_NAME=swift-6.3.1-RELEASE-ubuntu-jammy-armv7
ARG SDK_URL=https://github.com/swift-embedded-linux/armhf-debian/releases/download/6.3.1/${SDK_NAME}-sdk.tar.gz

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates file \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL "${SDK_URL}" | tar -xz -C /opt \
 && curl -fsSL "http://ports.ubuntu.com/ubuntu-ports/pool/main/libw/libwebp/libwebp-dev_1.2.2-2ubuntu0.22.04.2_armhf.deb" -o /tmp/libwebp-dev.deb \
 && dpkg-deb -x /tmp/libwebp-dev.deb "/opt/${SDK_NAME}/ubuntu-jammy" \
 && rm -f /tmp/libwebp-dev.deb

ENV SDK_DIR=/opt/${SDK_NAME}
WORKDIR /src
